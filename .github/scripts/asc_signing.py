#!/usr/bin/env python3
"""배포용(App Store) 수동 서명 준비 — 기기를 등록하지 않은 팀에서도 TestFlight에 올릴 수 있게

자동 서명은 archive 때 개발용 프로필을 만들려 하고, 개발용 프로필은 등록된 기기가 있어야 만들어져요.
그래서 빌드마다 배포용 인증서와 App Store 프로필을 API로 직접 만들어 씀 (인증서는 빌드 끝에 asc_certs.py cleanup이 폐기).

  setup OUT_DIR BUNDLE_ID...   배포 인증서(.p12)·App Store 프로필을 만들고 설치, OUT_DIR/profiles.json 에 {번들: {name, uuid}}
  patch PBXPROJ OUT_DIR TEAM   Release 설정에서 위 번들 타깃만 수동 서명(Apple Distribution + 프로필)으로 바꿈
  cleanup OUT_DIR              이번 빌드가 만든 프로필 삭제

필요 환경 변수: ASC_KEY_ID, ASC_ISSUER_ID, ASC_KEY_FILE, P12_PASS(setup)
비밀값(키·인증서 내용)은 로그에 출력하지 않아요.
"""
import base64, json, os, re, subprocess, sys, time, urllib.error, urllib.parse, urllib.request

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from asc_certs import API, token  # noqa: E402

OPENSSL = "/usr/bin/openssl"  # macOS LibreSSL: 키체인이 읽는 형식의 .p12를 만듦
# 앱 본체에 필요한 기능 (Config/DOOOIT.entitlements와 같게)
APP_CAPABILITIES = ["SIGN_IN_WITH_APPLE", "GAME_CENTER", "INCREASED_MEMORY_LIMIT", "PUSH_NOTIFICATIONS", "ICLOUD", "FAMILY_CONTROLS"]
NAMES = {"": "MOTI", ".widgets": "MOTI Widgets", ".activitymonitor": "MOTI Lock", ".watchkitapp": "MOTI Watch", ".watchkitapp.widgets": "MOTI Watch Widgets"}


def call(method, path, body=None):
    data = json.dumps(body).encode() if body is not None else None
    req = urllib.request.Request(API + path, data=data, method=method,
                                 headers={"Authorization": f"Bearer {token()}", "Content-Type": "application/json"})
    try:
        with urllib.request.urlopen(req, timeout=60) as res:
            raw = res.read()
            return json.loads(raw) if raw else None
    except urllib.error.HTTPError as e:
        detail = e.read()[:600].decode(errors="replace")
        raise RuntimeError(f"{method} {path.split('?')[0]} → {e.code}: {detail}") from None


def run(*args, **kw):
    return subprocess.run(list(args), check=True, capture_output=True, **kw)


def make_certificate(out):
    key, csr = f"{out}/dist.key", f"{out}/dist.csr"
    run(OPENSSL, "req", "-new", "-newkey", "rsa:2048", "-nodes", "-keyout", key, "-out", csr, "-subj", "/CN=MOTI CI/C=KR")
    os.chmod(key, 0o600)
    res = call("POST", "/certificates", {"data": {"type": "certificates", "attributes": {
        "certificateType": "DISTRIBUTION", "csrContent": open(csr).read()}}})
    cert_id = res["data"]["id"]
    der = base64.b64decode(res["data"]["attributes"]["certificateContent"])
    open(f"{out}/dist.cer", "wb").write(der)
    run(OPENSSL, "x509", "-inform", "DER", "-in", f"{out}/dist.cer", "-out", f"{out}/dist.pem")
    run(OPENSSL, "pkcs12", "-export", "-inkey", key, "-in", f"{out}/dist.pem", "-out", f"{out}/dist.p12",
        "-passout", "pass:" + os.environ["P12_PASS"])
    os.remove(key)
    print(f"배포 인증서를 만들었어요 ({res['data']['attributes'].get('name', '')})")
    return cert_id


def bundle_id(identifier, suffix):
    q = urllib.parse.quote(identifier)
    found = [b for b in call("GET", f"/bundleIds?filter[identifier]={q}&limit=200")["data"]
             if b["attributes"]["identifier"] == identifier]
    if found:
        return found[0]["id"]
    res = call("POST", "/bundleIds", {"data": {"type": "bundleIds", "attributes": {
        "identifier": identifier, "name": NAMES.get(suffix, "MOTI Extension"), "platform": "IOS"}}})
    print(f"번들 ID를 등록했어요: {identifier}")
    return res["data"]["id"]


def ensure_capabilities(bid, wanted):
    have = {c["attributes"]["capabilityType"] for c in call("GET", f"/bundleIds/{bid}/bundleIdCapabilities")["data"]}
    for cap in wanted:
        if cap in have:
            continue
        attributes = {"capabilityType": cap}
        if cap == "ICLOUD":
            # 컨테이너 연결은 API로 못 해서, 개발자 사이트에서 켠 것을 그대로 씀 (꺼져 있으면 알려만 줌)
            print("::warning title=iCloud::App ID에 iCloud가 꺼져 있어요 — 개발자 사이트에서 iCloud(CloudKit)와 컨테이너를 켜 주세요")
            continue
        if cap == "SIGN_IN_WITH_APPLE":
            attributes["settings"] = [{"key": "APPLE_ID_AUTH_APP_CONSENT", "options": [{"key": "PRIMARY_APP_CONSENT"}]}]
        try:
            call("POST", "/bundleIdCapabilities", {"data": {"type": "bundleIdCapabilities", "attributes": attributes,
                                                            "relationships": {"bundleId": {"data": {"type": "bundleIds", "id": bid}}}}})
            print(f"기능을 켰어요: {cap}")
        except RuntimeError as e:
            print(f"::warning title=Capability::{cap} 켜기 실패 — {e}")


def setup(out, identifiers):
    os.makedirs(out, exist_ok=True)
    cert_id = make_certificate(out)
    base = min(identifiers, key=len)
    stamp = time.strftime("%Y%m%d%H%M%S")
    profiles, created = {}, []
    dirs = [os.path.expanduser("~/Library/MobileDevice/Provisioning Profiles"),
            os.path.expanduser("~/Library/Developer/Xcode/UserData/Provisioning Profiles")]
    for d in dirs:
        os.makedirs(d, exist_ok=True)
    for identifier in identifiers:
        suffix = identifier[len(base):]
        bid = bundle_id(identifier, suffix)
        if identifier == base:
            ensure_capabilities(bid, APP_CAPABILITIES)
        elif suffix == ".activitymonitor":
            ensure_capabilities(bid, ["FAMILY_CONTROLS"])
        elif suffix.startswith(".watchkitapp"):
            # 워치 앱 · 워치 위젯이 같은 권한 파일을 써서 둘 다 Game Center를 켬
            ensure_capabilities(bid, ["GAME_CENTER"])
        name = f"MOTI CI {identifier} {stamp}"
        res = call("POST", "/profiles", {"data": {"type": "profiles",
                                                  "attributes": {"name": name, "profileType": "IOS_APP_STORE"},
                                                  "relationships": {"bundleId": {"data": {"type": "bundleIds", "id": bid}},
                                                                    "certificates": {"data": [{"type": "certificates", "id": cert_id}]}}}})
        attrs = res["data"]["attributes"]
        content = base64.b64decode(attrs["profileContent"])
        for d in dirs:
            open(f"{d}/{attrs['uuid']}.mobileprovision", "wb").write(content)
        profiles[identifier] = {"name": name, "uuid": attrs["uuid"]}
        created.append(res["data"]["id"])
        print(f"App Store 프로필을 만들었어요: {identifier}")
    json.dump(profiles, open(f"{out}/profiles.json", "w"))
    json.dump(created, open(f"{out}/created.json", "w"))


def patch(pbxproj, out, team):
    profiles = json.load(open(f"{out}/profiles.json"))
    text = open(pbxproj).read()
    pattern = re.compile(r'(/\* Release \*/ = \{\n\t\t\tisa = XCBuildConfiguration;\n\t\t\tbuildSettings = \{\n)(.*?)(\n\t\t\t\};)', re.S)
    done = set()

    def fix(m):
        settings = m.group(2)
        ident = re.search(r'PRODUCT_BUNDLE_IDENTIFIER = ([^;]+);', settings)
        if not ident or ident.group(1).strip('"') not in profiles:
            return m.group(0)
        p = profiles[ident.group(1).strip('"')]
        lines = [l for l in settings.split("\n")
                 if not re.match(r'\s*"?(CODE_SIGN_STYLE|CODE_SIGN_IDENTITY|PROVISIONING_PROFILE_SPECIFIER|DEVELOPMENT_TEAM)\b', l)]
        indent = "\t\t\t\t"
        lines += [f'{indent}CODE_SIGN_STYLE = Manual;', f'{indent}CODE_SIGN_IDENTITY = "Apple Distribution";',
                  f'{indent}PROVISIONING_PROFILE_SPECIFIER = "{p["name"]}";', f'{indent}DEVELOPMENT_TEAM = {team};']
        done.add(ident.group(1).strip('"'))
        return m.group(1) + "\n".join(lines) + m.group(3)

    text = pattern.sub(fix, text)
    missing = set(profiles) - done
    if missing:
        sys.exit(f"::error title=Signing::Release 설정을 찾지 못한 번들: {', '.join(sorted(missing))}")
    open(pbxproj, "w").write(text)
    print(f"수동 서명으로 바꾼 타깃 {len(done)}개")


def cleanup(out):
    try:
        created = json.load(open(f"{out}/created.json"))
    except FileNotFoundError:
        return
    for pid in created:
        try:
            call("DELETE", f"/profiles/{pid}")
        except RuntimeError as e:
            print(f"::warning::프로필 삭제 실패 — {e}")
    print(f"이번 빌드가 만든 프로필 {len(created)}개 삭제")


if __name__ == "__main__":
    if len(sys.argv) < 3:
        sys.exit(__doc__)
    cmd, out = sys.argv[1], sys.argv[2]
    try:
        if cmd == "setup":
            setup(out, sys.argv[3:])
        elif cmd == "patch":
            patch(sys.argv[2], sys.argv[3], sys.argv[4])
        elif cmd == "cleanup":
            cleanup(out)
        else:
            sys.exit(__doc__)
    except RuntimeError as e:
        print(f"::error title=App Store Connect::{e}")
        sys.exit(1)
