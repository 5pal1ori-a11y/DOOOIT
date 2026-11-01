#!/bin/bash
# 그래프·도형 판독 테스트 (Linux, Swift 6.1 Docker). 앱 타깃에 들어가지 않도록 DOOOIT 폴더 밖에 둠
# 저장소 맨 위에서: bash Tests/VisionCore/run.sh
set -e
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
docker run --rm -v "$ROOT":/src mirror.gcr.io/library/swift:6.1 bash -c '
  set -e
  mkdir -p /tmp/vc
  cd /src
  swiftc -O -swift-version 5 DOOOIT/Services/VisionCore/PixelImage.swift DOOOIT/Services/VisionCore/GraphReader.swift \
    DOOOIT/Services/VisionCore/ShapeReader.swift Tests/VisionCore/main.swift -o /tmp/vc/tests
  /tmp/vc/tests
'
