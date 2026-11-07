#!/usr/bin/env bash
# NEIS 공개 API 샘플 수집 (키 없음). 결과는 samples/ 에 저장하고 로그에도 찍음.
set -u
B="https://open.neis.go.kr/hub"
OUT="samples"; mkdir -p "$OUT"
log() { echo "=== $*"; }
get() { # name, endpoint, params...
  local name="$1" ep="$2"; shift 2
  local args=(); for p in "$@"; do args+=(--data-urlencode "$p"); done
  local code
  code=$(curl -sS -G "$B/$ep" --data-urlencode "Type=json" "${args[@]}" -o "$OUT/$name.json" -w "%{http_code}" --max-time 40) || code="curl-fail"
  sleep 0.4
  echo "[$code] $name <- $ep $*"
}
show() { echo "--- $1"; head -c "${2:-3000}" "$OUT/$1.json"; echo; }
summ() { # file, endpoint
  echo "$1 total=$(jq -r ".${2}[0].head[0].list_total_count // \"-\"" "$OUT/$1.json" 2>/dev/null) rows=$(jq -r "[.${2}[1].row[]?]|length" "$OUT/$1.json" 2>/dev/null) result=$(jq -c '.RESULT // empty' "$OUT/$1.json" 2>/dev/null)"
}

log "date"; date -u
MON=$(date -d "monday this week" +%Y%m%d)
PMON=$(date -d "$MON -7 days" +%Y%m%d); PSAT=$(date -d "$PMON +5 days" +%Y%m%d)
FIXMON=20251013; FIXFRI=20251017
echo "prev week $PMON..$PSAT"

log "schoolInfo searches"
i=0
for n in "서울초등학교" "대구초등학교" "서울중학교" "대원중학교" "서울고등학교" "선린인터넷고등학교" "서울과학고등학교" "대원외국어고등학교" "서울공업고등학교"; do
  i=$((i+1)); get "school_$i" schoolInfo "SCHUL_NM=$n" "pSize=20"
  jq -r '.schoolInfo[1].row[]? | [.ATPT_OFCDC_SC_CODE,.SD_SCHUL_CODE,.SCHUL_NM,.SCHUL_KND_SC_NM,.LCTN_SC_NM,.ORG_RDNMA,.HS_SC_NM] | @tsv' "$OUT/school_$i.json" | head -5
done
show school_1 2500
get school_nores schoolInfo "SCHUL_NM=없는학교이름zzzz"; show school_nores
get school_big schoolInfo "SCHUL_NM=서울" "pSize=1000"; show school_big 500
get school_paging1 schoolInfo "SCHUL_NM=서울" "pIndex=1" "pSize=5"
get school_paging2 schoolInfo "SCHUL_NM=서울" "pIndex=2" "pSize=5"
get school_paging2b schoolInfo "SCHUL_NM=서울" "pIndex=2" "pSize=3"
get school_paging_big schoolInfo "SCHUL_NM=서울" "pIndex=1" "pSize=100"
for f in school_big school_paging1 school_paging2 school_paging2b school_paging_big; do
  summ $f schoolInfo
  echo "   first=$(jq -r '.schoolInfo[1].row[0].SCHUL_NM // empty' $OUT/$f.json)"
done

pick() { # n kindname
  jq -r --arg k "$2" '[.schoolInfo[1].row[]? | select(.SCHUL_KND_SC_NM==$k)][0] | [.ATPT_OFCDC_SC_CODE,.SD_SCHUL_CODE,.SCHUL_NM] | @tsv' "$OUT/school_$1.json"
}
declare -A S
S[els1]=$(pick 1 초등학교); S[els2]=$(pick 2 초등학교)
S[mis1]=$(pick 3 중학교); S[mis2]=$(pick 4 중학교)
S[his1]=$(pick 5 고등학교); S[his2]=$(pick 6 고등학교); S[his3]=$(pick 7 고등학교); S[his4]=$(pick 8 고등학교); S[his5]=$(pick 9 고등학교)
for k in "${!S[@]}"; do echo "pick $k = ${S[$k]}"; done

for k in els1 els2 mis1 mis2 his1 his2 his3 his4 his5; do
  IFS=$'\t' read -r ATPT CODE NAME <<<"${S[$k]}"
  if [ -z "${CODE:-}" ] || [ "$CODE" = "null" ]; then echo "skip $k (not found)"; continue; fi
  case "$k" in els*) EP=elsTimetable;; mis*) EP=misTimetable;; *) EP=hisTimetable;; esac
  log "$k $NAME ($ATPT/$CODE) $EP"
  get "${k}_meal_prev" mealServiceDietInfo "ATPT_OFCDC_SC_CODE=$ATPT" "SD_SCHUL_CODE=$CODE" "MLSV_FROM_YMD=$PMON" "MLSV_TO_YMD=$PSAT"
  get "${k}_meal_fix" mealServiceDietInfo "ATPT_OFCDC_SC_CODE=$ATPT" "SD_SCHUL_CODE=$CODE" "MLSV_FROM_YMD=$FIXMON" "MLSV_TO_YMD=$FIXFRI"
  get "${k}_meal_fix_p2" mealServiceDietInfo "ATPT_OFCDC_SC_CODE=$ATPT" "SD_SCHUL_CODE=$CODE" "MLSV_FROM_YMD=$FIXMON" "MLSV_TO_YMD=$FIXFRI" "pIndex=2" "pSize=5"
  get "${k}_meal_month" mealServiceDietInfo "ATPT_OFCDC_SC_CODE=$ATPT" "SD_SCHUL_CODE=$CODE" "MLSV_FROM_YMD=20251001" "MLSV_TO_YMD=20251031" "pSize=1000"
  get "${k}_meal_month5" mealServiceDietInfo "ATPT_OFCDC_SC_CODE=$ATPT" "SD_SCHUL_CODE=$CODE" "MLSV_FROM_YMD=20251001" "MLSV_TO_YMD=20251031"
  for f in meal_prev meal_fix meal_fix_p2 meal_month meal_month5; do summ ${k}_$f mealServiceDietInfo; done
  maxg=3; [[ $k == els* ]] && maxg=6
  for g in $(seq 1 $maxg); do
    for c in 1 2; do
      get "${k}_tt_g${g}_c${c}" "$EP" "ATPT_OFCDC_SC_CODE=$ATPT" "SD_SCHUL_CODE=$CODE" "GRADE=$g" "CLASS_NM=$c" "TI_FROM_YMD=$FIXMON" "TI_TO_YMD=$FIXFRI"
      summ ${k}_tt_g${g}_c${c} $EP
    done
  done
  get "${k}_tt_prev" "$EP" "ATPT_OFCDC_SC_CODE=$ATPT" "SD_SCHUL_CODE=$CODE" "GRADE=1" "CLASS_NM=1" "TI_FROM_YMD=$PMON" "TI_TO_YMD=$PSAT"
  get "${k}_tt_prev_p2" "$EP" "ATPT_OFCDC_SC_CODE=$ATPT" "SD_SCHUL_CODE=$CODE" "GRADE=1" "CLASS_NM=1" "TI_FROM_YMD=$PMON" "TI_TO_YMD=$PSAT" "pIndex=2" "pSize=5"
  get "${k}_tt_big" "$EP" "ATPT_OFCDC_SC_CODE=$ATPT" "SD_SCHUL_CODE=$CODE" "GRADE=1" "CLASS_NM=1" "TI_FROM_YMD=$FIXMON" "TI_TO_YMD=$FIXFRI" "pSize=1000"
  get "${k}_tt_noclass" "$EP" "ATPT_OFCDC_SC_CODE=$ATPT" "SD_SCHUL_CODE=$CODE" "GRADE=1" "TI_FROM_YMD=$FIXMON" "TI_TO_YMD=$FIXMON" "pSize=1000"
  get "${k}_tt_nograde" "$EP" "ATPT_OFCDC_SC_CODE=$ATPT" "SD_SCHUL_CODE=$CODE" "TI_FROM_YMD=$FIXMON" "TI_TO_YMD=$FIXMON"
  get "${k}_tt_wrongclass" "$EP" "ATPT_OFCDC_SC_CODE=$ATPT" "SD_SCHUL_CODE=$CODE" "GRADE=1" "CLASS_NM=99" "TI_FROM_YMD=$FIXMON" "TI_TO_YMD=$FIXFRI"
  for f in tt_prev tt_prev_p2 tt_big tt_noclass tt_nograde tt_wrongclass; do summ ${k}_$f $EP; done
  echo "--- distinct class/dept in ${k}_tt_noclass"
  jq -c "[.${EP}[1].row[]? | {CLASS_NM, DDDEP_NM, ORD_SC_NM, CLRM_NM, GRADE, SEM, AY}] | unique | .[0:40]" "$OUT/${k}_tt_noclass.json"
  show "${k}_tt_g1_c1" 1800
  show "${k}_meal_fix" 2500
done

log "errors"
get bad_key mealServiceDietInfo "KEY=invalidkey" "ATPT_OFCDC_SC_CODE=B10" "SD_SCHUL_CODE=7010057" "MLSV_YMD=$FIXMON"; show bad_key
get bad_param mealServiceDietInfo "ATPT_OFCDC_SC_CODE=B10"; show bad_param
get bad_ep notAnEndpoint "x=1"; show bad_ep 400
log "done"; ls "$OUT" | wc -l
