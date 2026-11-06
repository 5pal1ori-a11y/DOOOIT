#!/usr/bin/env bash
# 필기 판정 다시 돌리기 (리눅스·맥): 사진 테스트를 dump=1 로 돌려 로그에서 뽑은 dump.jsonl로 HandwritingFilter.tokens만 다시 판정
#   ./Tests/OCRImages/hwreplay.sh <dump.jsonl> [이름 필터] [-v]
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
FILE="$(cd "$(dirname "${1:?dump.jsonl}")" && pwd)/$(basename "$1")"
if [ -z "${INSIDE_RUNNER:-}" ] && ! command -v swiftc >/dev/null 2>&1; then
  exec docker run --rm -e INSIDE_RUNNER=1 -v "$ROOT":/src -v "$(dirname "$FILE")":/data -w /src mirror.gcr.io/library/swift:6.1 bash Tests/OCRImages/hwreplay.sh "/data/$(basename "$FILE")" "${@:2}"
fi
BUILD="$(mktemp -d)"
cp "$ROOT/DOOOIT/Services/HandwritingFilter.swift" "$ROOT/Tests/OCRImages/HwReplay/main.swift" "$BUILD/"
swiftc -O -swift-version 5 "$BUILD"/*.swift -o "$BUILD/hwreplay"
"$BUILD/hwreplay" "$FILE" "${@:2}"
