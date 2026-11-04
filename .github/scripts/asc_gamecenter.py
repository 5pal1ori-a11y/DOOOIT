#!/usr/bin/env python3
"""App Store Connect에 Game Center 랭킹(리더보드) 준비 — 이미 있으면 건너뜀

  리더보드 (공부 시간, 초 단위, 많을수록 위):
    dooit.study.daily         일간 (한국 시간 0시마다 새로 — 반복 리더보드)
    dooit.study.w2026_45      주간 (ISO 주, 월~일 — 주마다 하나)
    dooit.study.m2026_11      월간 (달마다 하나)

필요 환경 변수: ASC_KEY_ID, ASC_ISSUER_ID, ASC_KEY_FILE, BUNDLE_ID
실패해도 빌드는 계속 (앱은 랭킹이 준비되지 않았다고 보여줌)
"""
import datetime, json, os, sys, urllib.error, urllib.request

sys.path.insert(0, os.path.dirname(__file__))
from asc_certs import API, token  # noqa: E402

BUNDLE_ID = os.environ.get("BUNDLE_ID", "com.donghyeon.moti")
KST = datetime.timezone(datetime.timedelta(hours=9))


def boards():
    """만들 리더보드: (ID, 관리용 이름, 화면 이름, 반복 설정 또는 None)
    - 일간: 반복 리더보드 (한국 시간 0시마다, 시작은 미래여야 해서 다음 0시부터)
    - 주간·월간: Game Center 반복 규칙은 분·시간·일 단위만 돼서 달력 주·달에 맞추려고 주·달마다 따로 (이번 것 + 다음 2개)
    """
    now = datetime.datetime.now(KST)
    tomorrow = (now + datetime.timedelta(days=1)).replace(hour=0, minute=0, second=0, microsecond=0)
    start = tomorrow.astimezone(datetime.timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")
    result = [("dooit.study.daily", "두잇 일간 공부 시간", "일간 공부 시간",
               {"recurrenceStartDate": start, "recurrenceDuration": "PT24H", "recurrenceRule": "FREQ=DAILY;INTERVAL=1"})]
    today = now.date()
    for i in range(3):
        year, week, _ = (today + datetime.timedelta(weeks=i)).isocalendar()
        result.append((f"dooit.study.w{year}_{week:02d}", f"두잇 주간 {year}-W{week:02d}", f"{year}년 {week}주 공부 시간", None))
    y, m = today.year, today.month
    for i in range(3):
        mm = (m - 1 + i) % 12 + 1
        yy = y + (m - 1 + i) // 12
        result.append((f"dooit.study.m{yy}_{mm:02d}", f"두잇 월간 {yy}-{mm:02d}", f"{yy}년 {mm}월 공부 시간", None))
    return result


def call(method, path, body=None):
    data = json.dumps(body).encode() if body is not None else None
    req = urllib.request.Request(API + path, data=data, method=method,
                                 headers={"Authorization": f"Bearer {token()}", "Content-Type": "application/json"})
    with urllib.request.urlopen(req, timeout=60) as res:
        raw = res.read()
        return json.loads(raw) if raw else None


def error_text(e):
    try:
        detail = json.loads(e.read())
        return "; ".join(f"{x.get('title')}: {x.get('detail')}" for x in detail.get("errors", []))[:500]
    except Exception:
        return str(e)


def main():
    apps = call("GET", f"/apps?filter[bundleId]={BUNDLE_ID}&fields[apps]=bundleId").get("data", [])
    if not apps:
        print(f"::warning title=Game Center::앱({BUNDLE_ID})을 찾지 못했어요")
        return
    app_id = apps[0]["id"]

    # 1) Game Center 켜기
    try:
        detail = call("GET", f"/apps/{app_id}/gameCenterDetail")["data"]
    except urllib.error.HTTPError:
        detail = None
    if not detail:
        detail = call("POST", "/gameCenterDetails", {"data": {"type": "gameCenterDetails",
                      "relationships": {"app": {"data": {"type": "apps", "id": app_id}}}}})["data"]
        print("Game Center를 켰어요")
    detail_id = detail["id"]

    # 2) 리더보드 (없는 것만 만듦)
    existing = call("GET", f"/gameCenterDetails/{detail_id}/gameCenterLeaderboards?limit=200").get("data", [])
    have = {b["attributes"].get("vendorIdentifier") for b in existing}
    for vendor, reference, name, recurrence in boards():
        if vendor in have:
            print(f"이미 있어요: {vendor}")
            continue
        attributes = {"referenceName": reference, "vendorIdentifier": vendor, "defaultFormatter": "ELAPSED_TIME_SECOND",
                      "submissionType": "BEST_SCORE", "scoreSortType": "DESC"}
        if recurrence:
            attributes.update(recurrence)
        board = None
        try:
            board = call("POST", "/gameCenterLeaderboards", {"data": {"type": "gameCenterLeaderboards", "attributes": attributes,
                         "relationships": {"gameCenterDetail": {"data": {"type": "gameCenterDetails", "id": detail_id}}}}})["data"]
        except urllib.error.HTTPError as e:
            print(f"::warning title=Game Center::{vendor} 만들기 실패 ({e.code}): {error_text(e)}")
        if not board:
            continue
        try:
            call("POST", "/gameCenterLeaderboardLocalizations", {"data": {"type": "gameCenterLeaderboardLocalizations",
                 "attributes": {"locale": "ko", "name": name},
                 "relationships": {"gameCenterLeaderboard": {"data": {"type": "gameCenterLeaderboards", "id": board["id"]}}}}})
        except urllib.error.HTTPError as e:
            print(f"::warning title=Game Center::{vendor} 이름 넣기 실패 ({e.code}): {error_text(e)}")
        print(f"만들었어요: {vendor}")


if __name__ == "__main__":
    try:
        main()
    except urllib.error.HTTPError as e:
        print(f"::warning title=Game Center::App Store Connect API 오류 {e.code}: {error_text(e)}")
    except Exception as e:  # 빌드는 멈추지 않음
        print(f"::warning title=Game Center::준비 중 오류: {e}")
