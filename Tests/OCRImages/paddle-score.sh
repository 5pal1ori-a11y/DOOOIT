#!/usr/bin/env bash
# PaddleOCR-VL 비교 채점: PaddleOCR-VL이 읽은 글(paddle-*.json)을 앱의 글자 정리·문제 나누기 코드로 채점하고 Vision 결과와 표로 비교 (맥·리눅스)
#   ./Tests/OCRImages/paddle-score.sh <폴더(cases.json)> <Vision results.json | -> <이름=paddle.json>...
# 스위프트가 없으면 Docker(swift:6.1)로 실행 (이때 파일 경로는 폴더 안 이름으로)
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
DIR="$(cd "${1:?폴더}" && pwd)"
shift
if [ -z "${INSIDE_RUNNER:-}" ] && ! command -v swiftc >/dev/null 2>&1; then
  exec docker run --rm -e INSIDE_RUNNER=1 -v "$ROOT":/src -v "$DIR":/cases -w /cases mirror.gcr.io/library/swift:6.1 bash /src/Tests/OCRImages/paddle-score.sh /cases "$@"
fi
BUILD="$(mktemp -d)"
cd "$ROOT/DOOOIT"
for f in Services/DoitAI/*.swift Services/DoitAI/Curriculum/*.swift Services/DoitAI/Study/*.swift Services/DoitAI/Mistake/*.swift Services/DoitAI/ProblemTypes/*.swift Services/DoitBrain/*.swift Services/StudyContentModels.swift Services/WordParser.swift Services/WordReview.swift Services/MathOCRFixer.swift Services/OCRText.swift Services/FractionFinder.swift Services/TextSkew.swift Services/ProblemSplitter.swift Utilities/DateHelpers.swift; do
  case "$f" in *DoitActions.swift) continue;; esac
  { echo '#if canImport(FoundationNetworking)'; echo 'import FoundationNetworking'; echo '#endif'; sed 's/^import UIKit$/import Foundation/' "$f"; } > "$BUILD/$(basename "$f")"
done
cp "$ROOT/Tests/DoitAI/Support/Stubs.swift" "$ROOT/Tests/OCRImages/Shared/CaseSpec.swift" "$ROOT/Tests/OCRImages/Shared/Checks.swift" "$ROOT/Tests/OCRImages/Paddle/Latex.swift" "$BUILD/"
cp "$ROOT/Tests/OCRImages/Paddle/main.swift" "$BUILD/main.swift"
swiftc -swift-version 5 "$BUILD"/*.swift -o "$BUILD/ocr-paddle-score" 2>&1 | grep -E "error" || true
cd "$DIR"
"$BUILD/ocr-paddle-score" "$DIR" "$@"
