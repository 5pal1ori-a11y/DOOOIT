#!/usr/bin/env bash
B="https://open.neis.go.kr/hub"
OUT="samples4"; mkdir -p "$OUT"
n=0
try() {
  n=$((n+1))
  code=$(curl -sS -m 30 -o "$OUT/r$n.json" -w "%{http_code}" "$2") || code="curl-fail"
  echo "[$1] $code $(head -c 160 "$OUT/r$n.json" | tr '\n' ' ')"
  sleep 0.5
}
S="SCHUL_NM=%EC%84%9C%EC%9A%B8%EA%B3%A0"
try A_typeonly "$B/schoolInfo?Type=json&$S"
try B_psize5 "$B/schoolInfo?Type=json&pSize=5&$S"
try C_pidx_psize "$B/schoolInfo?Type=json&pIndex=1&pSize=5&$S"
try D_psize20 "$B/schoolInfo?Type=json&pSize=20&$S"
try E_pidx1 "$B/schoolInfo?Type=json&pIndex=1&$S"
try F_noType "$B/schoolInfo?$S"
try G_xml "$B/schoolInfo?Type=xml&$S"
try H_psize10 "$B/schoolInfo?Type=json&pSize=10&$S"
try I_pidx_psize100 "$B/schoolInfo?Type=json&pIndex=1&pSize=100&$S"
try J_meal "$B/mealServiceDietInfo?Type=json&ATPT_OFCDC_SC_CODE=B10&SD_SCHUL_CODE=7010083&MLSV_YMD=20261103"
try K_meal_p "$B/mealServiceDietInfo?Type=json&pIndex=1&pSize=5&ATPT_OFCDC_SC_CODE=B10&SD_SCHUL_CODE=7010083&MLSV_YMD=20261103"
try L_key_sample "$B/schoolInfo?KEY=sample&Type=json&$S"
