#!/usr/bin/env bash
# 정밀 인식(PaddleOCR-VL) 맥 비교: 앱의 Swift 모델 코드 vs 파이썬 mlx-vlm (같은 테스트 사진)
#   ./Tests/PaddleOCR/run.sh <작업 폴더> [사진 수 (기본 40)]
# 필요: Xcode 26 (MLX), python3 (mlx-vlm==0.7.11, huggingface_hub)
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
WORK="${1:-$ROOT/build/paddle-parity}"
LIMIT="${2:-40}"
mkdir -p "$WORK"
WORK="$(cd "$WORK" && pwd)"

echo "▶ 테스트 사진 만들기"
swiftc -O -swift-version 5 "$ROOT"/Tests/OCRImages/Generator/*.swift "$ROOT/Tests/OCRImages/Shared/CaseSpec.swift" -o "$WORK/ocr-generate"
"$WORK/ocr-generate" "$WORK/cases"

echo "▶ 문제 사진만 고르게 $LIMIT 장"
python3 - "$WORK/cases/cases.json" "$WORK/ids.json" "$LIMIT" <<'EOF'
import json, sys
specs = [s for s in json.load(open(sys.argv[1])) if s["kind"] != "words"]
n = int(sys.argv[3])
if n and len(specs) > n:
    step = len(specs) / n
    specs = [specs[int(k * step)] for k in range(n)]
json.dump([s["id"] for s in specs], open(sys.argv[2], "w"))
print(len(specs), "장")
EOF

echo "▶ 모델 받기"
MODEL="$(python3 -c "from huggingface_hub import snapshot_download; print(snapshot_download('mlx-community/PaddleOCR-VL-1.6-4bit', allow_patterns=['*.safetensors','*.json','*.jinja']))")"
echo "$MODEL"

echo "▶ Swift 비교 도구 빌드 (앱 코드 그대로)"
PKG="$WORK/pkg"
rm -rf "$PKG"
mkdir -p "$PKG/Sources/PaddleParity"
cp "$ROOT/Tests/PaddleOCR/Package.swift" "$PKG/"
cp "$ROOT/Tests/PaddleOCR/Parity/main.swift" "$PKG/Sources/PaddleParity/"
for f in PaddleOCRSupport PaddleOCRText PaddleOCRModel PaddleOCREngine; do
  cp "$ROOT/DOOOIT/Services/PaddleOCR/$f.swift" "$PKG/Sources/PaddleParity/"
done
cp "$ROOT/DOOOIT/Services/MathOCRFixer.swift" "$PKG/Sources/PaddleParity/"
cp "$ROOT/DOOOIT/Services/GeometryText.swift" "$PKG/Sources/PaddleParity/"
(cd "$PKG" && xcodebuild -scheme PaddleParity -destination 'platform=macOS' -configuration Release \
   -derivedDataPath "$WORK/dd" -skipMacroValidation -skipPackagePluginValidation build 2>&1 | tee "$WORK/build.log" | grep -E "error:|warning: .*Paddle|BUILD" || true)
BIN="$WORK/dd/Build/Products/Release/PaddleParity"
[ -x "$BIN" ] || { grep -E "error:" "$WORK/build.log" | head -40; exit 1; }

echo "▶ 파이썬 mlx-vlm으로 읽기"
python3 "$ROOT/Tests/PaddleOCR/read.py" "$WORK/cases" "$WORK/ids.json" "$MODEL" "$WORK/python.json"

echo "▶ Swift(앱 코드)로 읽기 + 비교"
"$BIN" "$WORK/cases" "$WORK/ids.json" "$MODEL" "$WORK/swift.json" "$WORK/python.json"
