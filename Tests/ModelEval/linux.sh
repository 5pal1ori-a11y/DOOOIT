#!/usr/bin/env bash
# 두잇 1·2 모델 비교: 문제 만들기 / 채점 (앱 코드 그대로, Mac이나 Linux에서)
#   ./Tests/ModelEval/linux.sh dump Tests/ModelEval/eval.json
#   ./Tests/ModelEval/linux.sh score Tests/ModelEval/eval.json results/*.jsonl
# 스위프트가 없으면 Docker(swift:6.1)로 실행 (Tests/DoitAI/run.sh와 같은 파일 목록)
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
if [ -z "${INSIDE_RUNNER:-}" ] && ! command -v swiftc >/dev/null 2>&1; then
  exec docker run --rm -e INSIDE_RUNNER=1 -v "$ROOT":/src -w /src mirror.gcr.io/library/swift:6.1 bash Tests/ModelEval/linux.sh "$@"
fi
BUILD="$(mktemp -d)"
pushd "$ROOT/DOOOIT" >/dev/null
for f in Services/DoitAI/*.swift Services/DoitAI/Curriculum/*.swift Services/DoitAI/Study/*.swift Services/DoitAI/Mistake/*.swift Services/DoitAI/ProblemTypes/*.swift Services/DoitBrain/*.swift Services/StudyContentModels.swift Services/WordParser.swift Services/WordReview.swift Services/MathOCRFixer.swift Services/GeometryText.swift Services/OCRText.swift Services/SubjectOCRText.swift Services/FractionFinder.swift Services/TextSkew.swift Services/ProblemSplitter.swift Services/PaddleOCR/PaddleOCRText.swift Services/PaddleOCR/PaddleOCRSupport.swift Utilities/DateHelpers.swift; do
  case "$f" in *DoitActions.swift) continue;; esac
  { echo '#if canImport(FoundationNetworking)'; echo 'import FoundationNetworking'; echo '#endif'; sed 's/^import UIKit$/import Foundation/' "$f"; } > "$BUILD/$(basename "$f")"
done
popd >/dev/null
cp "$ROOT/Tests/DoitAI/Support/Stubs.swift" "$ROOT/Tests/DoitAI/SolverBatteryCases.swift" "$ROOT/Tests/DoitAI/SubjectBatteryCases.swift" "$BUILD/"
cp "$ROOT/Tests/ModelEval/Linux/main.swift" "$BUILD/main.swift"
swiftc -swift-version 5 "$BUILD"/*.swift -o "$BUILD/model-eval"
"$BUILD/model-eval" "$@"
