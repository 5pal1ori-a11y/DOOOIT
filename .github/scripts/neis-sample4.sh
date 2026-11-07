#!/usr/bin/env bash
# 앱이 보내는 요청을 그대로 재현 (학교 찾기, 키 없음)
set -u
B="https://open.neis.go.kr/hub"
OUT="samples4"; mkdir -p "$OUT"
UA_APP="DOOOIT/1 CFNetwork/1568.300.101 Darwin/24.2.0"
n=0
try() { # label ua url
  n=$((n+1))
  code=$(curl -sS -m 30 -A "$2" -H "Accept: application/json" -o "$OUT/r$n.json" -w "%{http_code} %{content_type}" "$3") || code="curl-fail"
  echo "[$1] $code $(head -c 300 "$OUT/r$n.json" | tr '\n' ' ')"
  echo "    url=$3"
  sleep 0.5
}
for q in "%EC%84%9C%EC%9A%B8" "%EB%AA%A8%ED%8B%B0" "%EC%84%9C%EC%9A%B8%EA%B3%A0" "%ED%95%9C%EA%B5%AD%EA%B3%A0%EB%93%B1%ED%95%99%EA%B5%90" "%EB%8C%80%EC%9B%90%EC%A4%91"; do
  try "app5" "$UA_APP" "$B/schoolInfo?Type=json&pIndex=1&pSize=5&SCHUL_NM=$q"
  try "curlUA" "curl/8" "$B/schoolInfo?Type=json&pIndex=1&pSize=5&SCHUL_NM=$q"
  for k in "%EC%B4%88%EB%93%B1%ED%95%99%EA%B5%90" "%EC%A4%91%ED%95%99%EA%B5%90" "%EA%B3%A0%EB%93%B1%ED%95%99%EA%B5%90"; do
    try "kind" "$UA_APP" "$B/schoolInfo?Type=json&pIndex=1&pSize=5&SCHUL_NM=$q&SCHUL_KND_SC_NM=$k"
  done
done
try "office" "$UA_APP" "$B/schoolInfo?Type=json&pIndex=1&pSize=5&SCHUL_NM=%EC%84%9C%EC%9A%B8&ATPT_OFCDC_SC_CODE=B10"
try "http" "$UA_APP" "http://open.neis.go.kr/hub/schoolInfo?Type=json&pIndex=1&pSize=5&SCHUL_NM=%EC%84%9C%EC%9A%B8"
