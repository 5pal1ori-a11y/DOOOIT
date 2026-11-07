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
for f in Services/DoitAI/*.swift Services/DoitAI/Curriculum/*.swift Services/DoitAI/Study/*.swift Services/DoitAI/Grammar/*.swift Services/DoitAI/Mistake/*.swift Services/DoitAI/ProblemTypes/*.swift Services/DoitBrain/*.swift Services/StudyContentModels.swift Services/Badges.swift Services/SoundMix.swift Services/WordParser.swift Services/WordReview.swift Services/WatchBridgeLogic.swift Services/ExamPlanner.swift ../WatchShared/WatchProtocol.swift ../Shared/WidgetSnapshot.swift ../Shared/WidgetPreviewData.swift Services/MathOCRFixer.swift Services/GeometryText.swift Services/OCRText.swift Services/SubjectOCRText.swift Services/HandwritingFilter.swift Services/HandwritingLayout.swift Services/FractionFinder.swift Services/TextSkew.swift Services/ProblemSplitter.swift Services/PaddleOCR/PaddleOCRText.swift Services/PaddleOCR/PaddleOCRSupport.swift Utilities/DateHelpers.swift; do
  case "$f" in *DoitActions.swift) continue;; esac
  { echo '#if canImport(FoundationNetworking)'; echo 'import FoundationNetworking'; echo '#endif'; sed 's/^import UIKit$/import Foundation/' "$f"; } > "$BUILD/$(basename "$f")"
done
cp "$ROOT/Tests/DoitAI/Support/Stubs.swift" "$ROOT/Tests/DoitAI/main.swift" "$ROOT/Tests/DoitAI/WordCases.swift" "$ROOT/Tests/DoitAI/ProblemSplitCases.swift" "$ROOT/Tests/DoitAI/OCRCases.swift" "$ROOT/Tests/DoitAI/SolverCases.swift" "$ROOT/Tests/DoitAI/SolverCases2.swift" "$ROOT/Tests/DoitAI/MistakeSubjectCases.swift" "$ROOT/Tests/DoitAI/StudyScopeCases.swift" "$ROOT/Tests/DoitAI/ChatContextCases.swift" "$ROOT/Tests/DoitAI/ProblemTypeCases.swift" "$ROOT/Tests/DoitAI/ChatRelevanceCases.swift" "$ROOT/Tests/DoitAI/GuidedSolveCases.swift" "$ROOT/Tests/DoitAI/PaddleOCRCases.swift" "$ROOT/Tests/DoitAI/AutoSolveCases.swift" "$ROOT/Tests/DoitAI/ItemJudgeCases.swift" "$ROOT/Tests/DoitAI/SolverBatteryCases.swift" "$ROOT/Tests/DoitAI/SubjectBatteryCases.swift" "$ROOT/Tests/DoitAI/GeometryCases.swift" "$ROOT/Tests/DoitAI/FigureCases.swift" "$ROOT/Tests/DoitAI/HandwritingCases.swift" "$ROOT/Tests/DoitAI/HandwritingLayoutCases.swift" "$ROOT/Tests/DoitAI/FeatureCases.swift" "$ROOT/Tests/DoitAI/SubjectBattery2Cases.swift" "$ROOT/Tests/DoitAI/SubjectBattery3Cases.swift" "$ROOT/Tests/DoitAI/SentenceCheckCases.swift" "$ROOT/Tests/DoitAI/EnglishRuleCases.swift" "$ROOT/Tests/DoitAI/EnglishBatteryCases.swift" "$ROOT/Tests/DoitAI/EnglishBatteryPools.swift" "$ROOT/Tests/DoitAI/EnglishHandBattery.swift" "$ROOT/Tests/DoitAI/EnglishCurriculumCases.swift" "$ROOT/Tests/DoitAI/WatchCases.swift" "$ROOT/Tests/DoitAI/WidgetCases.swift" "$ROOT/Tests/DoitAI/ChatNaturalCases.swift" "$ROOT/Tests/DoitAI/MathBattery3Cases.swift" "$ROOT/Tests/DoitAI/ZeroAuditCases.swift" "$ROOT/Tests/DoitAI/ZeroFreshCases.swift" "$ROOT/Tests/DoitAI/ChatZeroCases.swift" "$ROOT/Tests/DoitAI/ThinkCases.swift" "$ROOT/Tests/DoitAI/ExamPlannerCases.swift" "$BUILD/"
swiftc -swift-version 5 "$BUILD"/*.swift -o "$BUILD/doit-tests"
"$BUILD/doit-tests"
