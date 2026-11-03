#!/usr/bin/env bash
# 그림 읽기 확인 (맥): 테스트 그림 20장을 그려서 앱 코드 그대로 세 가지 길로 읽고 정답과 비교
#   ./Tests/FigureEval/run.sh <작업 폴더> [길: all | vision | paddle | vlm]
# 필요: Xcode 26 (Vision 문서 읽기, MLX), python3 (huggingface_hub: 정밀 인식 모델 받기)
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
WORK="${1:-$ROOT/build/figure-eval}"
WHICH="${2:-all}"
mkdir -p "$WORK"
WORK="$(cd "$WORK" && pwd)"

echo "▶ 테스트 그림 만들기"
swiftc -O -swift-version 5 "$ROOT/Tests/FigureEval/Generator/main.swift" -o "$WORK/figure-generate"
"$WORK/figure-generate" "$WORK/cases"

echo "▶ 확인 도구 빌드 (앱 코드 그대로)"
PKG="$WORK/pkg"
SRC="$PKG/Sources/FigureEval"
rm -rf "$PKG"
mkdir -p "$SRC"
cp "$ROOT/Tests/FigureEval/Package.swift" "$PKG/"
cp "$ROOT/Tests/FigureEval/Eval/main.swift" "$SRC/"
cp "$ROOT/DOOOIT/Services/DoitAI/Mistake/DoitFigureFacts.swift" "$ROOT/DOOOIT/Services/GeometryText.swift" "$ROOT/DOOOIT/Services/MathOCRFixer.swift" \
   "$ROOT/DOOOIT/Services/FigureVision.swift" "$ROOT/DOOOIT/Services/DoitBrain/DoitVisionEngine.swift" "$SRC/"
for f in PixelImage GraphReader ShapeReader; do cp "$ROOT/DOOOIT/Services/VisionCore/$f.swift" "$SRC/"; done
for f in PaddleOCRSupport PaddleOCRText PaddleOCRModel PaddleOCREngine; do cp "$ROOT/DOOOIT/Services/PaddleOCR/$f.swift" "$SRC/"; done
{ echo "import Foundation"; echo; sed -n '/^struct ThinkFilter/,$p' "$ROOT/DOOOIT/Services/DoitBrain/DoitBrain.swift"; } > "$SRC/ThinkFilter.swift"
(cd "$PKG" && xcodebuild -scheme FigureEval -destination 'platform=macOS' -configuration Release \
   -derivedDataPath "$WORK/dd" -skipMacroValidation -skipPackagePluginValidation build 2>&1 | tee "$WORK/build.log" | grep -E "error:|BUILD" || true)
BIN="$WORK/dd/Build/Products/Release/FigureEval"
[ -x "$BIN" ] || { grep -E "error:" "$WORK/build.log" | head -40; exit 1; }

if [ "$WHICH" = all ] || [ "$WHICH" = vision ]; then
  echo "▶ 기본 판독 (Vision + 픽셀)"
  "$BIN" vision "$WORK/cases" || echo "기본 판독 실패"
fi
if [ "$WHICH" = all ] || [ "$WHICH" = paddle ]; then
  echo "▶ 정밀 인식 (PaddleOCR-VL 1.6) 표·차트"
  MODEL="$(python3 -c "from huggingface_hub import snapshot_download; print(snapshot_download('mlx-community/PaddleOCR-VL-1.6-4bit', allow_patterns=['*.safetensors','*.json','*.jinja','*.md']))")"
  grep -h -o "[A-Za-z ]*Recognition:\|Spotting:\|OCR:" "$MODEL"/*.md "$MODEL"/*.jinja 2>/dev/null | sort | uniq -c | head -20 || true
  "$BIN" paddle "$WORK/cases" "$MODEL" || echo "정밀 인식 실패"
fi
if [ "$WHICH" = all ] || [ "$WHICH" = vlm ]; then
  echo "▶ 두잇 2 사진 읽기 (Qwen3.5 4B, MLXVLM)"
  /usr/bin/time -l "$BIN" vlm "$WORK/cases" "mlx-community/Qwen3.5-4B-MLX-4bit" 2> "$WORK/vlm-time.txt" || echo "두잇 2 사진 읽기 실패"
  grep -E "maximum resident|peak memory footprint" "$WORK/vlm-time.txt" || tail -5 "$WORK/vlm-time.txt"
fi
