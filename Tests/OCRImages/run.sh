#!/usr/bin/env bash
# 사진 OCR 테스트 (맥 전용: Apple Vision이 필요해요)
#   ./Tests/OCRImages/run.sh [출력 폴더] [이름 필터]
# 1) Generator: 문제지·단어장 사진을 그리고 휴대폰 사진처럼 망가뜨림 (+ 정답 cases.json)
# 2) Runner: 앱의 실제 OCRCore·MathOCRFixer·WordParser·DoitProblemScan으로 읽고 정답과 비교
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
HERE="$ROOT/Tests/OCRImages"
OUT="${1:-$ROOT/build/ocr-images}"
FILTER="${2:-}"
BUILD="$(mktemp -d)"
mkdir -p "$OUT"
OUT="$(cd "$OUT" && pwd)"

echo "▶ 사진 만들기 도구 빌드"
swiftc -O -swift-version 5 "$HERE"/Generator/*.swift "$HERE/Shared/CaseSpec.swift" -o "$BUILD/ocr-generate"
"$BUILD/ocr-generate" "$OUT"

echo "▶ 읽기 도구 빌드 (앱 코드 그대로)"
SRC="$BUILD/src"
mkdir -p "$SRC"
cd "$ROOT/DOOOIT"
for f in Services/DoitAI/*.swift Services/DoitAI/Curriculum/*.swift Services/DoitAI/Study/*.swift Services/DoitAI/Mistake/*.swift Services/DoitAI/ProblemTypes/*.swift Services/DoitBrain/*.swift Services/StudyContentModels.swift Services/WordParser.swift Services/WordReview.swift Services/MathOCRFixer.swift Services/OCRText.swift Services/FractionFinder.swift Services/TextSkew.swift Services/ProblemSplitter.swift Utilities/DateHelpers.swift; do
  case "$f" in *DoitActions.swift) continue;; esac
  sed 's/^import UIKit$/import Foundation/' "$f" > "$SRC/$(basename "$f")"
done
cp Services/OCRCore.swift "$SRC/"
# 리눅스 테스트용 가짜에서 진짜로 바뀌는 부분(OCRLine, OCRService 몸통)은 빼고 UIImage 입구만 가짜로
sed -e '/^struct OCRLine /d' -e '/static func printedText(from lines/d' -e 's/^enum OCRService {/extension OCRService {/' \
  "$ROOT/Tests/DoitAI/Support/Stubs.swift" > "$SRC/Stubs.swift"
cp "$HERE/Shared/CaseSpec.swift" "$HERE/Shared/Checks.swift" "$SRC/"
cp "$HERE/Runner/main.swift" "$SRC/main.swift"
swiftc -swift-version 5 "$SRC"/*.swift -o "$BUILD/ocr-runner"

echo "▶ 읽기"
"$BUILD/ocr-runner" "$OUT" "$FILTER"
