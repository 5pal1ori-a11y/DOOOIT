#!/usr/bin/env bash
# 두잇 1·2 모델 확인 (맥): 앱과 똑같이 불러와서 대화 질문(생각 끔·켬)과 문제 풀기
#   ./Tests/ModelEval/mac.sh <작업 폴더> <HF 저장소> <이름표> [문제 수 (0 = 전부)]
# 필요: Xcode 26 (MLX). 채점은 리눅스 도구로: linux.sh score (로그의 EVAL 줄을 모아서)
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
WORK="${1:?작업 폴더}"
REPO="${2:?저장소}"
LABEL="${3:?이름표}"
LIMIT="${4:-0}"
mkdir -p "$WORK"
WORK="$(cd "$WORK" && pwd)"

echo "▶ Swift 도구 빌드 (앱의 ThinkFilter 그대로)"
PKG="$WORK/pkg"
rm -rf "$PKG"
mkdir -p "$PKG/Sources/ModelEval"
cp "$ROOT/Tests/ModelEval/Package.swift" "$PKG/"
cp "$ROOT/Tests/ModelEval/Mac/ModelEval.swift" "$PKG/Sources/ModelEval/"
{ echo "import Foundation"; echo; sed -n '/^struct ThinkFilter/,$p' "$ROOT/DOOOIT/Services/DoitBrain/DoitBrain.swift"; } > "$PKG/Sources/ModelEval/ThinkFilter.swift"
grep -q "mutating func feed" "$PKG/Sources/ModelEval/ThinkFilter.swift" || { echo "ThinkFilter를 못 찾음"; exit 1; }
(cd "$PKG" && xcodebuild -scheme ModelEval -destination 'platform=macOS' -configuration Release \
   -derivedDataPath "$WORK/dd" -skipMacroValidation -skipPackagePluginValidation build 2>&1 | tee "$WORK/build.log" | grep -E "error:|BUILD" || true)
BIN="$WORK/dd/Build/Products/Release/ModelEval"
[ -x "$BIN" ] || { grep -E "error:" "$WORK/build.log" | head -40; exit 1; }
grep -E "Resolved source packages" -A12 "$WORK/build.log" | head -14 || true

echo "▶ $LABEL ($REPO)"
"$BIN" "$REPO" "$ROOT/Tests/ModelEval/checks.json" "$ROOT/Tests/ModelEval/eval.json" "$LABEL" "$LIMIT"
