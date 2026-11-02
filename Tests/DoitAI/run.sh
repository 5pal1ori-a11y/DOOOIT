#!/usr/bin/env bash
# 두잇 AI 엔진 테스트 (Mac이나 Linux에서 실행)
#   ./Tests/DoitAI/run.sh            → 스위프트가 있으면 바로, 없으면 Docker(swift:6.1)로 실행
# iOS 전용 부분(UIKit, SwiftData, Vision)은 Support/Stubs.swift 의 가짜로 바꿔서 엔진만 검사해요.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
if [ -z "${INSIDE_RUNNER:-}" ] && ! command -v swiftc >/dev/null 2>&1; then
  exec docker run --rm -e INSIDE_RUNNER=1 -v "$ROOT":/src -w /src mirror.gcr.io/library/swift:6.1 bash Tests/DoitAI/run.sh
fi
BUILD="$(mktemp -d)"
cd "$ROOT/DOOOIT"
for f in Services/DoitAI/*.swift Services/DoitAI/Curriculum/*.swift Services/DoitAI/Study/*.swift Services/DoitAI/Mistake/*.swift Services/DoitBrain/*.swift Services/StudyContentModels.swift Services/WordParser.swift Services/MathOCRFixer.swift Utilities/DateHelpers.swift; do
  case "$f" in *DoitActions.swift) continue;; esac
  { echo '#if canImport(FoundationNetworking)'; echo 'import FoundationNetworking'; echo '#endif'; sed 's/^import UIKit$/import Foundation/' "$f"; } > "$BUILD/$(basename "$f")"
done
cp "$ROOT/Tests/DoitAI/Support/Stubs.swift" "$ROOT/Tests/DoitAI/main.swift" "$ROOT/Tests/DoitAI/WordCases.swift" "$BUILD/"
swiftc -swift-version 5 "$BUILD"/*.swift -o "$BUILD/doit-tests"
"$BUILD/doit-tests"
