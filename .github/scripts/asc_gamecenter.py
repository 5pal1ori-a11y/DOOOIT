#!/usr/bin/env python3
"""App Store Connect에 Game Center 랭킹(리더보드) 준비 — 이미 있으면 건너뜀

  리더보드 (공부 시간, 초 단위, 많을수록 위):
    dooit.study.daily    일간 (한국 시간 0시마다 새로)
    dooit.study.weekly   주간 (월요일 0시마다 새로)
    dooit.study.monthly  월간 (매달 1일 0시마다 새로)

필요 환경 변수: ASC_KEY_ID, ASC_ISSUER_ID, ASC_KEY_FILE, BUNDLE_ID
실패해도 빌드는 계속 (앱은 랭킹이 준비되지 않았다고 보여줌)
"""
import json, os, sys, urllib.error, urllib.request

sys.path.insert(0, os.path.dirname(__file__))
from asc_certs import API, token  # noqa: E402

BUNDLE_ID = os.environ.get("BUNDLE_ID", "com.bravekoon.dooit")
# 한국 시간 2026-01-05(월) 0시 = UTC 2026-01-04 15:00
START = "2026-01-04T15:00:00Z"
# 기간은 "시간이 들어간" ISO 8601 형식이어야 함 (P1D는 거절됨) → 되는 것을 차례로 시도
BOARDS = [
    ("dooit.study.daily", "두잇 일간 공부 시간", "일간 공부 시간", ["P1DT0H0M0S", "PT24H"], "FREQ=DAILY;INTERVAL=1"),
    ("dooit.study.weekly", "두잇 주간 공부 시간", "주간 공부 시간", ["P7DT0H0M0S", "PT168H"], "FREQ=WEEKLY;INTERVAL=1"),
    ("dooit.study.monthly", "두잇 월간 공부 시간", "월간 공부 시간", ["P1MT0H0M0S", "P30DT0H0M0S", "PT720H"], "FREQ=MONTHLY;INTERVAL=1"),
]


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
    for vendor, reference, name, durations, rule in BOARDS:
        if vendor in have:
            print(f"이미 있어요: {vendor}")
            continue
        attempts = []
        for duration in durations:
            base = {"referenceName": reference, "vendorIdentifier": vendor, "defaultFormatter": "ELAPSED_TIME_SECOND",
                    "submissionType": "BEST_SCORE", "scoreSortType": "DESC",
                    "recurrenceStartDate": START, "recurrenceDuration": duration}
            attempts += [dict(base, recurrenceRule=rule), base]
        board = None
        for attempt in attempts:
            try:
                board = call("POST", "/gameCenterLeaderboards", {"data": {"type": "gameCenterLeaderboards", "attributes": attempt,
                             "relationships": {"gameCenterDetail": {"data": {"type": "gameCenterDetails", "id": detail_id}}}}})["data"]
                print(f"기간 {attempt['recurrenceDuration']}" + (" + 반복 규칙" if "recurrenceRule" in attempt else ""))
                break
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
