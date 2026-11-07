#!/usr/bin/env bash
# NEIS 2차 샘플: 키 없을 때 쪽 나누기 대신 쓸 수 있는 필터(날짜·교시·식사·학과) 확인
set -u
B="https://open.neis.go.kr/hub"
OUT="samples2"; mkdir -p "$OUT"
get() {
  local name="$1" ep="$2"; shift 2
  local args=(); for p in "$@"; do args+=(--data-urlencode "$p"); done
  local code
  code=$(curl -sS -G "$B/$ep" --data-urlencode "Type=json" "${args[@]}" -o "$OUT/$name.json" -w "%{http_code}" --max-time 40) || code="curl-fail"
  sleep 0.3
  echo "[$code] $name <- $ep $*"
}
sum() { # file service
  echo "   -> $1 total=$(jq -r ".${2}[0].head[0].list_total_count // \"-\"" "$OUT/$1.json" 2>/dev/null) rows=$(jq -r "[.${2}[1].row[]?]|length" "$OUT/$1.json" 2>/dev/null) result=$(jq -c '.RESULT // empty' "$OUT/$1.json" 2>/dev/null)"
}
periods() { echo "      periods: $(jq -r ".${2}[1].row[]? | \"\(.ALL_TI_YMD):\(.PERIO)\"" "$OUT/$1.json" 2>/dev/null | tr '\n' ' ')"; }

M=B10; MC=7132131      # 남서울중학교
E=D10; EC=7271066      # 남대구초등학교
H=B10; HC=7010083      # 서울고 (일반고, 석식 있음)
G=B10; GC=7010278      # 서울공업고 (학과 여러 개)
S=B10; SC=7010084      # 서울과학고 (조식)

echo "=== 중학교 하루/교시 필터"
get m_day mis"Timetable" ATPT_OFCDC_SC_CODE=$M SD_SCHUL_CODE=$MC GRADE=1 CLASS_NM=1 TI_FROM_YMD=20261103 TI_TO_YMD=20261103; sum m_day misTimetable; periods m_day misTimetable
get m_day_alldate misTimetable ATPT_OFCDC_SC_CODE=$M SD_SCHUL_CODE=$MC GRADE=1 CLASS_NM=1 ALL_TI_YMD=20261103; sum m_day_alldate misTimetable; periods m_day_alldate misTimetable
get m_day_p6 misTimetable ATPT_OFCDC_SC_CODE=$M SD_SCHUL_CODE=$MC GRADE=1 CLASS_NM=1 TI_FROM_YMD=20261103 TI_TO_YMD=20261103 PERIO=6; sum m_day_p6 misTimetable; periods m_day_p6 misTimetable
get m_day_p7 misTimetable ATPT_OFCDC_SC_CODE=$M SD_SCHUL_CODE=$MC GRADE=1 CLASS_NM=1 TI_FROM_YMD=20261103 TI_TO_YMD=20261103 PERIO=7; sum m_day_p7 misTimetable; periods m_day_p7 misTimetable
get m_week_p1 misTimetable ATPT_OFCDC_SC_CODE=$M SD_SCHUL_CODE=$MC GRADE=1 CLASS_NM=1 TI_FROM_YMD=20261102 TI_TO_YMD=20261107 PERIO=1; sum m_week_p1 misTimetable; periods m_week_p1 misTimetable
get m_week_p7 misTimetable ATPT_OFCDC_SC_CODE=$M SD_SCHUL_CODE=$MC GRADE=1 CLASS_NM=1 TI_FROM_YMD=20261102 TI_TO_YMD=20261107 PERIO=7; sum m_week_p7 misTimetable; periods m_week_p7 misTimetable
get m_week misTimetable ATPT_OFCDC_SC_CODE=$M SD_SCHUL_CODE=$MC GRADE=1 CLASS_NM=1 TI_FROM_YMD=20261102 TI_TO_YMD=20261107; sum m_week misTimetable; periods m_week misTimetable
get m_sat misTimetable ATPT_OFCDC_SC_CODE=$M SD_SCHUL_CODE=$MC GRADE=1 CLASS_NM=1 TI_FROM_YMD=20261107 TI_TO_YMD=20261107; sum m_sat misTimetable
get m_sun_week misTimetable ATPT_OFCDC_SC_CODE=$M SD_SCHUL_CODE=$MC GRADE=1 CLASS_NM=1 TI_FROM_YMD=20261109 TI_TO_YMD=20261114; sum m_sun_week misTimetable
get m_c20 misTimetable ATPT_OFCDC_SC_CODE=$M SD_SCHUL_CODE=$MC GRADE=1 CLASS_NM=20 TI_FROM_YMD=20261103 TI_TO_YMD=20261103; sum m_c20 misTimetable
echo "=== 초등 하루"
get e_day elsTimetable ATPT_OFCDC_SC_CODE=$E SD_SCHUL_CODE=$EC GRADE=3 CLASS_NM=1 TI_FROM_YMD=20261103 TI_TO_YMD=20261103; sum e_day elsTimetable; periods e_day elsTimetable
get e_week elsTimetable ATPT_OFCDC_SC_CODE=$E SD_SCHUL_CODE=$EC GRADE=3 CLASS_NM=1 TI_FROM_YMD=20261102 TI_TO_YMD=20261107; sum e_week elsTimetable
echo "=== 고등 학과"
get g_major schoolMajorinfo ATPT_OFCDC_SC_CODE=$G SD_SCHUL_CODE=$GC; sum g_major schoolMajorinfo; head -c 1500 "$OUT/g_major.json"; echo
get g_major_big schoolMajorinfo ATPT_OFCDC_SC_CODE=$G SD_SCHUL_CODE=$GC pSize=1000; sum g_major_big schoolMajorinfo
get h_major schoolMajorinfo ATPT_OFCDC_SC_CODE=$H SD_SCHUL_CODE=$HC; sum h_major schoolMajorinfo; head -c 800 "$OUT/h_major.json"; echo
get s_major schoolMajorinfo ATPT_OFCDC_SC_CODE=$S SD_SCHUL_CODE=$SC; sum s_major schoolMajorinfo; head -c 800 "$OUT/s_major.json"; echo
get g_dept hisTimetable ATPT_OFCDC_SC_CODE=$G SD_SCHUL_CODE=$GC GRADE=1 CLASS_NM=1 DDDEP_NM=그래픽아트과 TI_FROM_YMD=20261102 TI_TO_YMD=20261107; sum g_dept hisTimetable
get g_dept_day hisTimetable ATPT_OFCDC_SC_CODE=$G SD_SCHUL_CODE=$GC GRADE=1 CLASS_NM=1 DDDEP_NM=그래픽아트과 TI_FROM_YMD=20261103 TI_TO_YMD=20261103; sum g_dept_day hisTimetable; periods g_dept_day hisTimetable
get g_dept_p1 hisTimetable ATPT_OFCDC_SC_CODE=$G SD_SCHUL_CODE=$GC GRADE=1 CLASS_NM=1 DDDEP_NM=그래픽아트과 TI_FROM_YMD=20261103 TI_TO_YMD=20261103 PERIO=1; sum g_dept_p1 hisTimetable; jq -c '[.hisTimetable[1].row[]? | {DDDEP_NM,CLASS_NM,CLRM_NM,PERIO,ITRT_CNTNT,ORD_SC_NM,DGHT_CRSE_SC_NM}]' "$OUT/g_dept_p1.json"
get g_nodept_p1 hisTimetable ATPT_OFCDC_SC_CODE=$G SD_SCHUL_CODE=$GC GRADE=1 CLASS_NM=1 TI_FROM_YMD=20261103 TI_TO_YMD=20261103 PERIO=1; sum g_nodept_p1 hisTimetable; jq -c '[.hisTimetable[1].row[]? | {DDDEP_NM,CLASS_NM,CLRM_NM,PERIO,ITRT_CNTNT}]' "$OUT/g_nodept_p1.json"
get h_day hisTimetable ATPT_OFCDC_SC_CODE=$H SD_SCHUL_CODE=$HC GRADE=2 CLASS_NM=3 TI_FROM_YMD=20261103 TI_TO_YMD=20261103; sum h_day hisTimetable; periods h_day hisTimetable
get h_week hisTimetable ATPT_OFCDC_SC_CODE=$H SD_SCHUL_CODE=$HC GRADE=2 CLASS_NM=3 TI_FROM_YMD=20261102 TI_TO_YMD=20261107; sum h_week hisTimetable
get s_day2 hisTimetable ATPT_OFCDC_SC_CODE=$S SD_SCHUL_CODE=$SC GRADE=2 CLASS_NM=1 TI_FROM_YMD=20261103 TI_TO_YMD=20261103; sum s_day2 hisTimetable; periods s_day2 hisTimetable
get s_week2 hisTimetable ATPT_OFCDC_SC_CODE=$S SD_SCHUL_CODE=$SC GRADE=2 CLASS_NM=1 TI_FROM_YMD=20261102 TI_TO_YMD=20261107; sum s_week2 hisTimetable
echo "=== 급식 필터"
get meal_day mealServiceDietInfo ATPT_OFCDC_SC_CODE=$H SD_SCHUL_CODE=$HC MLSV_YMD=20261103; sum meal_day mealServiceDietInfo; jq -c '[.mealServiceDietInfo[1].row[]? | {MLSV_YMD,MMEAL_SC_CODE,MMEAL_SC_NM,CAL_INFO}]' "$OUT/meal_day.json"
get meal_dinner mealServiceDietInfo ATPT_OFCDC_SC_CODE=$H SD_SCHUL_CODE=$HC MLSV_FROM_YMD=20261102 MLSV_TO_YMD=20261107 MMEAL_SC_CODE=3; sum meal_dinner mealServiceDietInfo; jq -c '[.mealServiceDietInfo[1].row[]? | {MLSV_YMD,MMEAL_SC_CODE,MMEAL_SC_NM}]' "$OUT/meal_dinner.json"
get meal_week mealServiceDietInfo ATPT_OFCDC_SC_CODE=$H SD_SCHUL_CODE=$HC MLSV_FROM_YMD=20261102 MLSV_TO_YMD=20261108; sum meal_week mealServiceDietInfo; jq -c '[.mealServiceDietInfo[1].row[]? | {MLSV_YMD,MMEAL_SC_CODE}]' "$OUT/meal_week.json"
get meal_sci_day mealServiceDietInfo ATPT_OFCDC_SC_CODE=$S SD_SCHUL_CODE=$SC MLSV_YMD=20261103; sum meal_sci_day mealServiceDietInfo; jq -c '[.mealServiceDietInfo[1].row[]? | {MLSV_YMD,MMEAL_SC_CODE,MMEAL_SC_NM}]' "$OUT/meal_sci_day.json"
get meal_sat mealServiceDietInfo ATPT_OFCDC_SC_CODE=$H SD_SCHUL_CODE=$HC MLSV_YMD=20261107; sum meal_sat mealServiceDietInfo
get meal_holiday mealServiceDietInfo ATPT_OFCDC_SC_CODE=$H SD_SCHUL_CODE=$HC MLSV_YMD=20261225; sum meal_holiday mealServiceDietInfo
echo "=== 학교 검색 나누기"
get s_all schoolInfo SCHUL_NM=서울; sum s_all schoolInfo
get s_els schoolInfo SCHUL_NM=서울 SCHUL_KND_SC_NM=초등학교; sum s_els schoolInfo; jq -r '.schoolInfo[1].row[]? | "\(.SCHUL_NM) \(.SCHUL_KND_SC_NM)"' "$OUT/s_els.json"
get s_mid schoolInfo SCHUL_NM=서울 SCHUL_KND_SC_NM=중학교; sum s_mid schoolInfo
get s_high schoolInfo SCHUL_NM=서울 SCHUL_KND_SC_NM=고등학교; sum s_high schoolInfo
get s_b10 schoolInfo SCHUL_NM=서울 ATPT_OFCDC_SC_CODE=B10; sum s_b10 schoolInfo
get s_b10_els schoolInfo SCHUL_NM=서울 ATPT_OFCDC_SC_CODE=B10 SCHUL_KND_SC_NM=초등학교; sum s_b10_els schoolInfo
get s_loc schoolInfo SCHUL_NM=대원 LCTN_SC_NM=서울특별시; sum s_loc schoolInfo
get s_dw schoolInfo SCHUL_NM=대원; sum s_dw schoolInfo; jq -r '.schoolInfo[1].row[]? | "\(.SCHUL_NM) \(.SCHUL_KND_SC_NM) \(.LCTN_SC_NM) [\(.SD_SCHUL_CODE)]"' "$OUT/s_dw.json"
get s_code schoolInfo ATPT_OFCDC_SC_CODE=$H SD_SCHUL_CODE=$HC; sum s_code schoolInfo; jq -c '.schoolInfo[1].row[0]' "$OUT/s_code.json"
get s_key_sample schoolInfo KEY=sample SCHUL_NM=서울 pIndex=2 pSize=5; sum s_key_sample schoolInfo; jq -r '.schoolInfo[1].row[0].SCHUL_NM' "$OUT/s_key_sample.json"
get s_two schoolInfo SCHUL_NM=서울 pIndex=3 pSize=100; sum s_two schoolInfo; jq -r '.schoolInfo[1].row[0].SCHUL_NM' "$OUT/s_two.json"
echo "=== 특수학교"
get sp_school schoolInfo SCHUL_NM=서울농학교; jq -c '.schoolInfo[1].row[]? | [.ATPT_OFCDC_SC_CODE,.SD_SCHUL_CODE,.SCHUL_NM,.SCHUL_KND_SC_NM]' "$OUT/sp_school.json"
SPC=$(jq -r '.schoolInfo[1].row[0].SD_SCHUL_CODE // empty' "$OUT/sp_school.json")
if [ -n "$SPC" ]; then
  get sp_tt spsTimetable ATPT_OFCDC_SC_CODE=B10 SD_SCHUL_CODE=$SPC GRADE=1 CLASS_NM=1 TI_FROM_YMD=20261103 TI_TO_YMD=20261103; sum sp_tt spsTimetable; head -c 700 "$OUT/sp_tt.json"; echo
fi
echo "=== 한 주 전체 (2026-11-02~07) 화면 표본"
get f_els elsTimetable ATPT_OFCDC_SC_CODE=$E SD_SCHUL_CODE=$EC GRADE=3 CLASS_NM=1 TI_FROM_YMD=20261102 TI_TO_YMD=20261102; sum f_els elsTimetable
echo done
