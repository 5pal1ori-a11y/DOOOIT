#!/usr/bin/env bash
# NEIS 3차: 고등학교 시간표에서 교시 필터가 되는지, 키 없이 5줄을 넘겨 받을 방법이 있는지
set -u
B="https://open.neis.go.kr/hub"
OUT="samples3"; mkdir -p "$OUT"
get() {
  local name="$1" ep="$2"; shift 2
  local args=(); for p in "$@"; do args+=(--data-urlencode "$p"); done
  curl -sS -G "$B/$ep" --data-urlencode "Type=json" "${args[@]}" -o "$OUT/$name.json" --max-time 40
  sleep 0.3
  echo "[$name] $ep $*"
}
sum() {
  echo "   -> total=$(jq -r ".${2}[0].head[0].list_total_count // \"-\"" "$OUT/$1.json" 2>/dev/null) rows=$(jq -r "[.${2}[1].row[]?]|length" "$OUT/$1.json" 2>/dev/null) periods=$(jq -r ".${2}[1].row[]? | \"\(.ALL_TI_YMD):\(.PERIO)\"" "$OUT/$1.json" 2>/dev/null | tr '\n' ' ') $(jq -c '.RESULT // empty' "$OUT/$1.json" 2>/dev/null)"
}
H="ATPT_OFCDC_SC_CODE=B10 SD_SCHUL_CODE=7010083 GRADE=2 CLASS_NM=3"
t() { # name, endpoint, extra...
  local name="$1" ep="$2"; shift 2
  get "$name" "$ep" "$@"; sum "$name" "$ep"
}
t his_a hisTimetable ATPT_OFCDC_SC_CODE=B10 SD_SCHUL_CODE=7010083 GRADE=2 CLASS_NM=3 ALL_TI_YMD=20261103 PERIO=6
t his_b hisTimetable ATPT_OFCDC_SC_CODE=B10 SD_SCHUL_CODE=7010083 GRADE=2 CLASS_NM=3 TI_FROM_YMD=20261103 TI_TO_YMD=20261103 PERIO=6
t his_c hisTimetable ATPT_OFCDC_SC_CODE=B10 SD_SCHUL_CODE=7010083 GRADE=2 CLASS_NM=3 TI_FROM_YMD=20261103 TI_TO_YMD=20261103 PERIO=7
t his_d hisTimetable ATPT_OFCDC_SC_CODE=B10 SD_SCHUL_CODE=7010083 GRADE=2 CLASS_NM=3 ALL_TI_YMD=20261103 PERIO=7 DGHT_CRSE_SC_NM=주간
t his_e hisTimetable ATPT_OFCDC_SC_CODE=B10 SD_SCHUL_CODE=7010083 GRADE=2 CLASS_NM=3 ALL_TI_YMD=20261103
t his_f hisTimetable ATPT_OFCDC_SC_CODE=B10 SD_SCHUL_CODE=7010083 GRADE=2 CLASS_NM=3 ALL_TI_YMD=20261103 DDDEP_NM=일반학과
t his_g hisTimetable ATPT_OFCDC_SC_CODE=B10 SD_SCHUL_CODE=7010083 GRADE=2 CLASS_NM=3 ALL_TI_YMD=20261103 DDDEP_NM=일반학과 PERIO=6
t his_h hisTimetable ATPT_OFCDC_SC_CODE=B10 SD_SCHUL_CODE=7010083 GRADE=2 CLRM_NM=3 ALL_TI_YMD=20261103 PERIO=6
t his_i hisTimetable ATPT_OFCDC_SC_CODE=B10 SD_SCHUL_CODE=7010083 GRADE=2 CLASS_NM=3 ALL_TI_YMD=20261103 ORD_SC_NM=일반계 PERIO=6
t his_j hisTimetable ATPT_OFCDC_SC_CODE=B10 SD_SCHUL_CODE=7010083 AY=2026 SEM=2 GRADE=2 CLASS_NM=3 ALL_TI_YMD=20261103 PERIO=6
t his_k hisTimetable ATPT_OFCDC_SC_CODE=B10 SD_SCHUL_CODE=7010083 AY=2026 SEM=2 GRADE=2 CLASS_NM=3 ALL_TI_YMD=20261103 PERIO=6 DGHT_CRSE_SC_NM=주간 ORD_SC_NM=일반계 DDDEP_NM=일반학과 CLRM_NM=3
t mis_a misTimetable ATPT_OFCDC_SC_CODE=B10 SD_SCHUL_CODE=7132131 GRADE=1 CLASS_NM=1 ALL_TI_YMD=20261103 PERIO=6
t mis_b misTimetable ATPT_OFCDC_SC_CODE=B10 SD_SCHUL_CODE=7132131 GRADE=1 CLASS_NM=1 TI_FROM_YMD=20261103 TI_TO_YMD=20261103 PERIO=6
t sun_a hisTimetable ATPT_OFCDC_SC_CODE=B10 SD_SCHUL_CODE=7010536 GRADE=2 CLASS_NM=3 TI_FROM_YMD=20261103 TI_TO_YMD=20261103
t sun_b hisTimetable ATPT_OFCDC_SC_CODE=B10 SD_SCHUL_CODE=7010536 GRADE=2 CLASS_NM=3 TI_FROM_YMD=20261103 TI_TO_YMD=20261103 PERIO=7
t gong_noclass hisTimetable ATPT_OFCDC_SC_CODE=B10 SD_SCHUL_CODE=7010278 GRADE=1 TI_FROM_YMD=20261103 TI_TO_YMD=20261103 PERIO=1
t gong_classes hisTimetable ATPT_OFCDC_SC_CODE=B10 SD_SCHUL_CODE=7010278 GRADE=1 CLASS_NM=2 TI_FROM_YMD=20261103 TI_TO_YMD=20261103 PERIO=1
t gong_dept2 hisTimetable ATPT_OFCDC_SC_CODE=B10 SD_SCHUL_CODE=7010278 GRADE=1 TI_FROM_YMD=20261103 TI_TO_YMD=20261103 DDDEP_NM=건축과 PERIO=1
jq -c '[.hisTimetable[1].row[]? | {DDDEP_NM,CLASS_NM,PERIO,DGHT_CRSE_SC_NM}]' "$OUT/gong_dept2.json"
t gong_dept3 hisTimetable ATPT_OFCDC_SC_CODE=B10 SD_SCHUL_CODE=7010278 GRADE=1 TI_FROM_YMD=20261103 TI_TO_YMD=20261103 DDDEP_NM=건축과 DGHT_CRSE_SC_NM=주간
echo "=== 전체 학과 (학교 정보) 분할"
t maj_day schoolMajorinfo ATPT_OFCDC_SC_CODE=B10 SD_SCHUL_CODE=7010278 DGHT_SC_NM=주간
jq -c '[.schoolMajorinfo[1].row[]? | {DGHT_SC_NM,ORD_SC_NM,DDDEP_NM}]' "$OUT/maj_day.json"
t maj_ord schoolMajorinfo ATPT_OFCDC_SC_CODE=B10 SD_SCHUL_CODE=7010278 DGHT_SC_NM=주간 ORD_SC_NM=공업계
echo done
