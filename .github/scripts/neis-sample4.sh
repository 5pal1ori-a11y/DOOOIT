#!/usr/bin/env bash
B="https://open.neis.go.kr/hub"
U="$B/schoolInfo?Type=json&pIndex=1&pSize=5&SCHUL_NM=%EC%84%9C%EC%9A%B8%EA%B3%A0"
t() { echo "[$1] $(curl -sS -m 30 -o /dev/null -w '%{http_code}' "${@:2}")"; }
t noheader "$U"
t accept_json -H "Accept: application/json" "$U"
t accept_any -H "Accept: */*" "$U"
t accept_json_utf8 -H "Accept: application/json; charset=utf-8" "$U"
t accept_ios -H "Accept: */*" -H "Accept-Language: ko-KR,ko;q=0.9" -H "Accept-Encoding: gzip, deflate, br" -A "DOOOIT/1 CFNetwork/1568.300.101 Darwin/24.2.0" "$U"
t ua_only -A "DOOOIT/1 CFNetwork/1568.300.101 Darwin/24.2.0" "$U"
mkdir -p samples4; echo ok > samples4/ok.txt
