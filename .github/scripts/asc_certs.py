#!/usr/bin/env python3
"""App Store Connect 인증서 관리 (빌드가 만든 인증서 정리용)

  list               인증서 목록 출력 (이름·종류·만료일만, 비밀값 없음)
  snapshot FILE      지금 있는 인증서 ID를 FILE에 저장
  cleanup FILE       FILE에 없던 (= 이번 빌드가 새로 만든) 인증서만 폐기

필요 환경 변수: ASC_KEY_ID, ASC_ISSUER_ID, ASC_KEY_FILE
외부 패키지 없이 openssl로 ES256 서명합니다.
"""
import base64, json, os, subprocess, sys, time, urllib.request, urllib.error

API = "https://api.appstoreconnect.apple.com/v1"
SIGNING_TYPES = {"DEVELOPMENT", "IOS_DEVELOPMENT", "DISTRIBUTION", "IOS_DISTRIBUTION"}


def b64url(data: bytes) -> str:
    return base64.urlsafe_b64encode(data).rstrip(b"=").decode()


def der_to_raw(der: bytes) -> bytes:
    # ECDSA DER (SEQUENCE { INTEGER r, INTEGER s }) → r||s (각 32바이트)
    def read_int(buf, i):
        assert buf[i] == 0x02
        length = buf[i + 1]
        value = buf[i + 2:i + 2 + length]
        return value.lstrip(b"\x00").rjust(32, b"\x00"), i + 2 + length
    i = 2 if der[1] < 0x80 else 3
    r, i = read_int(der, i)
    s, _ = read_int(der, i)
    return r + s


def token() -> str:
    header = {"alg": "ES256", "kid": os.environ["ASC_KEY_ID"], "typ": "JWT"}
    now = int(time.time())
    payload = {"iss": os.environ["ASC_ISSUER_ID"], "iat": now, "exp": now + 1000, "aud": "appstoreconnect-v1"}
    signing_input = f"{b64url(json.dumps(header).encode())}.{b64url(json.dumps(payload).encode())}"
    der = subprocess.run(
        ["openssl", "dgst", "-sha256", "-sign", os.environ["ASC_KEY_FILE"]],
        input=signing_input.encode(), capture_output=True, check=True,
    ).stdout
    return f"{signing_input}.{b64url(der_to_raw(der))}"


def request(method: str, path: str):
    req = urllib.request.Request(API + path, method=method, headers={"Authorization": f"Bearer {token()}"})
    with urllib.request.urlopen(req, timeout=60) as res:
        body = res.read()
        return json.loads(body) if body else None


def certificates():
    data = request("GET", "/certificates?limit=200&fields[certificates]=name,displayName,certificateType,expirationDate,platform")
    return data.get("data", [])


def main():
    if len(sys.argv) < 2:
        sys.exit(__doc__)
    cmd = sys.argv[1]
    certs = certificates()
    if cmd == "list":
        print(f"인증서 {len(certs)}개")
        for c in certs:
            a = c["attributes"]
            print(f"- {a.get('certificateType')} | {a.get('displayName') or a.get('name')} | 만료 {str(a.get('expirationDate'))[:10]}")
    elif cmd == "snapshot":
        with open(sys.argv[2], "w") as f:
            json.dump([c["id"] for c in certs], f)
        print(f"빌드 전 인증서 {len(certs)}개 기록")
    elif cmd == "cleanup":
        try:
            before = set(json.load(open(sys.argv[2])))
        except FileNotFoundError:
            print("빌드 전 기록이 없어 정리를 건너뜁니다")
            return
        new = [c for c in certs if c["id"] not in before and c["attributes"].get("certificateType") in SIGNING_TYPES]
        if not new:
            print("이번 빌드가 새로 만든 인증서가 없어요")
        for c in new:
            a = c["attributes"]
            try:
                request("DELETE", f"/certificates/{c['id']}")
                print(f"폐기: {a.get('certificateType')} | {a.get('displayName') or a.get('name')}")
            except urllib.error.HTTPError as e:
                print(f"::warning::인증서 폐기 실패 ({e.code}): {a.get('displayName') or a.get('name')}")
    else:
        sys.exit(__doc__)


if __name__ == "__main__":
    try:
        main()
    except urllib.error.HTTPError as e:
        print(f"::warning::App Store Connect API 오류 {e.code}: {e.read()[:300].decode(errors='replace')}")
