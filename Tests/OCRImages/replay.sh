#!/usr/bin/env bash
# 다시 채점: 맥 사진 테스트가 남긴 results.json(Vision 결과)을 지금 코드의 글자 정리 단계로 다시 채점 (리눅스 가능)
#   ./Tests/OCRImages/replay.sh <결과 폴더(cases.json, results.json)> [이름 필터]
# 스위프트가 없으면 Docker(swift:6.1)로 실행
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
DIR="$(cd "${1:?결과 폴더}" && pwd)"
FILTER="${2:-}"
if [ -z "${INSIDE_RUNNER:-}" ] && ! command -v swiftc >/dev/null 2>&1; then
  exec docker run --rm -e INSIDE_RUNNER=1 -e OCR_DEBUG="${OCR_DEBUG:-}" -v "$ROOT":/src -v "$DIR":/cases -w /src mirror.gcr.io/library/swift:6.1 bash Tests/OCRImages/replay.sh /cases "$FILTER"
fi
BUILD="$(mktemp -d)"
cd "$ROOT/DOOOIT"
for f in Services/DoitAI/*.swift Services/DoitAI/Curriculum/*.swift Services/DoitAI/Study/*.swift Services/DoitAI/Mistake/*.swift Services/DoitAI/ProblemTypes/*.swift Services/DoitBrain/*.swift Services/StudyContentModels.swift Services/WordParser.swift Services/WordReview.swift Services/MathOCRFixer.swift Services/GeometryText.swift Services/OCRText.swift Services/SubjectOCRText.swift Services/FractionFinder.swift Services/TextSkew.swift Services/ProblemSplitter.swift Utilities/DateHelpers.swift; do
  case "$f" in *DoitActions.swift) continue;; esac
  { echo '#if canImport(FoundationNetworking)'; echo 'import FoundationNetworking'; echo '#endif'; sed 's/^import UIKit$/import Foundation/' "$f"; } > "$BUILD/$(basename "$f")"
done
cp "$ROOT/Tests/DoitAI/Support/Stubs.swift" "$ROOT/Tests/OCRImages/Shared/CaseSpec.swift" "$ROOT/Tests/OCRImages/Shared/Checks.swift" "$BUILD/"
cp "$ROOT/Tests/OCRImages/Replay/main.swift" "$BUILD/main.swift"
swiftc -swift-version 5 "$BUILD"/*.swift -o "$BUILD/ocr-replay" 2>&1 | grep -E "error" || true
"$BUILD/ocr-replay" "$DIR" "$FILTER"
