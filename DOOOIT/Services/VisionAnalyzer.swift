import CoreGraphics
import UIKit
import Vision

/// 사진 한 장을 기기 안에서 판독한 결과 (외부 AI·서버 없음)
struct ImageAnalysis {
    enum Kind: String {
        /// 수학 문제 (글 + 식)
        case mathProblem
        /// 글이 많은 문서·필기
        case document
        /// 좌표평면 위 그래프
        case graph
        /// 도형 그림 (삼각형·사각형·원 …)
        case figure
        /// 일반 사진 (사물·풍경·사람)
        case photo
        /// QR 코드·바코드
        case qrCode
        /// 읽을 것이 없음
        case empty
    }

    var kind: Kind
    /// 한두 문장 요약 (해요체, **굵게** 사용)
    var summary: String
    /// 자세한 설명 줄
    var details: [String]
    /// 사진에서 읽은 글자 (위 → 아래)
    var text: String
    var graph: GraphAnalysis?
    var shapes: [ShapeAnalysis]
    /// 사진 속 사물·장면 (한국어)
    var labels: [String]
    var faceCount: Int
    /// QR·바코드 내용 (자동으로 열지 않음)
    var codes: [String]

    /// 채팅에 보여줄 글
    var message: String {
        ([summary] + details).filter { !$0.isEmpty }.joined(separator: "\n")
    }
}

enum VisionAnalyzer {
    // MARK: - 진입점

    static func analyze(_ image: UIImage) async -> ImageAnalysis {
        let prepared = image.preparedForOCR(maxDimension: 1200)
        guard let cgImage = prepared.cgImage, let pixels = pixelImage(cgImage) else {
            return ImageAnalysis(kind: .empty, summary: "사진을 읽지 못했어요. 다른 사진으로 다시 시도해 주세요.", details: [], text: "",
                                 graph: nil, shapes: [], labels: [], faceCount: 0, codes: [])
        }
        let vision = await runVision(cgImage, width: pixels.width, height: pixels.height)
        let text = vision.lines.joined(separator: "\n")

        // 1) 그래프: 좌표축이 있고 곡선이 맞으면
        var graph: GraphAnalysis?
        if GraphReader.findAxes(pixels) != nil, let result = GraphReader.analyze(pixels, labels: vision.labels), result.kind != .unknown {
            graph = result
        }
        // 2) 도형: 그래프가 아닐 때, 그림의 3% 이상을 차지하는 닫힌 도형
        var shapes: [ShapeAnalysis] = []
        if graph == nil {
            let minArea = Double(pixels.width * pixels.height) * 0.03
            shapes = ShapeReader.analyze(pixels, labels: vision.labels).filter { $0.bounds.w * $0.bounds.h >= minArea }
            // 글자 상자를 도형으로 착각하는 경우 (문서 속 표·칸)는 너무 많으면 버림
            if shapes.count > 6 { shapes = [] }
        }

        let isMath = looksLikeMath(text)
        var details: [String] = []
        let kind: ImageAnalysis.Kind
        var summary: String

        if !vision.codes.isEmpty {
            kind = .qrCode
            summary = "**QR·바코드**가 있어요."
            details += vision.codes.map { "내용: \($0)" }
            details.append("링크는 자동으로 열지 않아요. 믿을 수 있는 곳인지 확인하고 열어 주세요.")
        } else if let graph {
            kind = .graph
            summary = "**좌표평면 그래프**로 보여요."
            details += graph.explanation.components(separatedBy: "\n")
        } else if !shapes.isEmpty {
            kind = .figure
            summary = shapes.count > 1 ? "**도형 \(shapes.count)개**가 보여요." : "**도형 그림**이에요."
            for s in shapes.prefix(3) {
                details += s.description.components(separatedBy: "\n")
                details += s.computed.map { "→ " + $0 }
            }
        } else if isMath {
            kind = .mathProblem
            summary = "**수학 문제**로 보여요."
        } else if text.count >= 40 {
            kind = .document
            summary = "**글이 있는 문서**예요. 글자 \(text.count)자를 읽었어요."
        } else if !vision.classes.isEmpty {
            kind = .photo
            summary = "**사진**이에요. \(vision.classes.prefix(4).joined(separator: ", "))이(가) 보여요."
        } else if !text.isEmpty {
            kind = .document
            summary = "사진에서 글자를 읽었어요."
        } else {
            kind = .empty
            summary = "사진에서 글자나 알아볼 만한 것을 찾지 못했어요."
        }

        if vision.faces > 0 && kind == .photo { details.append("사람 얼굴 \(vision.faces)개가 보여요.") }
        if (kind == .graph || kind == .figure) && isMath {
            details.append("문제 글도 함께 읽었어요. 식으로 물어보면 바로 풀어드릴게요.")
        }
        if kind == .photo, !text.isEmpty {
            details.append("사진 속 글자: \(String(text.prefix(120)))")
        }
        return ImageAnalysis(kind: kind, summary: summary, details: details, text: text, graph: graph, shapes: shapes,
                             labels: vision.classes, faceCount: vision.faces, codes: vision.codes)
    }

    // MARK: - 수학 문제처럼 보이는지

    static func looksLikeMath(_ text: String) -> Bool {
        guard !text.isEmpty else { return false }
        let words = ["구하시오", "구하여라", "값은", "값을", "방정식", "부등식", "함수", "그래프", "좌표", "넓이", "길이", "넓이는", "몇 개", "경우의 수",
                     "실수", "자연수", "정수", "다항식", "인수분해", "꼭짓점", "직선", "원의", "삼각형", "①", "②", "③", "√", "²", "∠", "△", "π"]
        if words.contains(where: { text.contains($0) }) { return true }
        let mathChars = text.filter { "=+−-×÷^<>≤≥".contains($0) }.count
        let variables = text.filter { "xyab".contains($0) }.count
        return mathChars >= 2 && variables >= 1
    }

    // MARK: - Vision

    private struct VisionResult {
        var lines: [String] = []
        var labels: [TextLabel] = []
        var classes: [String] = []
        var faces = 0
        var codes: [String] = []
    }

    private static func runVision(_ cgImage: CGImage, width: Int, height: Int) async -> VisionResult {
        await withCheckedContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                var result = VisionResult()
                let text = VNRecognizeTextRequest()
                text.recognitionLevel = .accurate
                text.usesLanguageCorrection = true
                text.recognitionLanguages = ["ko-KR", "en-US"]
                let classify = VNClassifyImageRequest()
                let faces = VNDetectFaceRectanglesRequest()
                let barcodes = VNDetectBarcodesRequest()
                let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
                // 하나가 실패해도 나머지는 쓰도록 따로 실행
                for request in [text, classify, faces, barcodes] as [VNRequest] {
                    try? handler.perform([request])
                }

                let W = Double(width), H = Double(height)
                func pixelRect(_ r: CGRect) -> VRect {
                    VRect(x: Double(r.minX) * W, y: (1 - Double(r.maxY)) * H, w: Double(r.width) * W, h: Double(r.height) * H)
                }
                let observations = (text.results ?? []).sorted { $0.boundingBox.midY > $1.boundingBox.midY }
                for observation in observations {
                    guard let candidate = observation.topCandidates(1).first else { continue }
                    let string = candidate.string
                    result.lines.append(string)
                    // 눈금 숫자처럼 한 줄에 여러 개가 붙어 읽힌 경우를 위해 낱말마다 위치도 따로
                    var index = string.startIndex
                    var words: [TextLabel] = []
                    while index < string.endIndex {
                        guard let start = string[index...].firstIndex(where: { !$0.isWhitespace }) else { break }
                        let end = string[start...].firstIndex(where: { $0.isWhitespace }) ?? string.endIndex
                        if let box = try? candidate.boundingBox(for: start..<end)?.boundingBox {
                            words.append(TextLabel(text: String(string[start..<end]), box: pixelRect(box)))
                        }
                        index = end
                    }
                    if words.count > 1 {
                        result.labels += words
                    } else {
                        result.labels.append(TextLabel(text: string, box: pixelRect(observation.boundingBox)))
                    }
                }

                let classes = (classify.results ?? [])
                    .filter { $0.confidence >= 0.3 }
                    .sorted { $0.confidence > $1.confidence }
                    .compactMap { koreanLabels[$0.identifier] }
                var seen = Set<String>()
                result.classes = classes.filter { seen.insert($0).inserted }.prefix(6).map { $0 }
                result.faces = faces.results?.count ?? 0
                result.codes = (barcodes.results ?? []).compactMap { $0.payloadStringValue }
                    .map { String($0.prefix(300)) }
                continuation.resume(returning: result)
            }
        }
    }

    // MARK: - 픽셀

    /// CGImage → 밝기·색 버퍼 (RGBA로 그려서 읽음)
    private static func pixelImage(_ cgImage: CGImage) -> PixelImage? {
        let width = cgImage.width, height = cgImage.height
        guard width > 0, height > 0, width * height <= 4_000_000 else { return nil }
        var rgba = [UInt8](repeating: 255, count: width * height * 4)
        let drawn: Bool = rgba.withUnsafeMutableBytes { buffer in
            guard let context = CGContext(data: buffer.baseAddress, width: width, height: height, bitsPerComponent: 8,
                                          bytesPerRow: width * 4, space: CGColorSpaceCreateDeviceRGB(),
                                          bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else { return false }
            context.setFillColor(UIColor.white.cgColor)
            context.fill(CGRect(x: 0, y: 0, width: width, height: height))
            context.draw(cgImage, in: CGRect(x: 0, y: 0, width: width, height: height))
            return true
        }
        guard drawn else { return nil }
        return PixelImage(width: width, height: height, rgba: rgba)
    }

    // MARK: - 사물·장면 이름 (Vision 분류 이름 → 한국어)

    static let koreanLabels: [String: String] = [
        "people": "사람", "person": "사람", "adult": "어른", "child": "아이", "baby": "아기", "crowd": "사람들", "selfie": "셀카",
        "dog": "강아지", "cat": "고양이", "bird": "새", "fish": "물고기", "horse": "말", "cow": "소", "rabbit": "토끼", "hamster": "햄스터",
        "animal": "동물", "insect": "곤충", "butterfly": "나비", "pet": "반려동물",
        "food": "음식", "fruit": "과일", "apple": "사과", "banana": "바나나", "orange": "오렌지", "strawberry": "딸기", "vegetable": "채소",
        "bread": "빵", "cake": "케이크", "dessert": "디저트", "pizza": "피자", "hamburger": "햄버거", "sandwich": "샌드위치", "noodles": "면 요리",
        "rice": "밥", "sushi": "초밥", "salad": "샐러드", "soup": "국물 요리", "meat": "고기", "coffee": "커피", "tea": "차", "drink": "음료",
        "beverage": "음료", "juice": "주스", "ice_cream": "아이스크림", "cookie": "쿠키", "chocolate": "초콜릿", "snack": "간식",
        "document": "문서", "paper": "종이", "text": "글자", "book": "책", "notebook": "공책", "handwriting": "손글씨", "receipt": "영수증",
        "chart": "차트", "diagram": "도표", "map": "지도", "screenshot": "화면 캡처", "poster": "포스터", "sign": "표지판", "menu": "메뉴판",
        "whiteboard": "화이트보드", "blackboard": "칠판", "drawing": "그림", "painting": "그림", "illustration": "일러스트", "cartoon": "만화",
        "sky": "하늘", "cloud": "구름", "sunset": "노을", "sunrise": "해돋이", "night_sky": "밤하늘", "moon": "달", "star": "별", "rainbow": "무지개",
        "tree": "나무", "plant": "식물", "flower": "꽃", "grass": "잔디", "forest": "숲", "leaf": "나뭇잎", "garden": "정원", "park": "공원",
        "mountain": "산", "hill": "언덕", "beach": "바다", "sea": "바다", "ocean": "바다", "lake": "호수", "river": "강", "water": "물",
        "waterfall": "폭포", "snow": "눈", "ice": "얼음", "desert": "사막", "field": "들판", "rock": "바위", "sand": "모래",
        "city": "도시", "building": "건물", "house": "집", "skyscraper": "고층 건물", "street": "거리", "road": "도로", "bridge": "다리",
        "church": "교회", "temple": "절", "castle": "성", "tower": "탑", "school": "학교", "classroom": "교실", "office": "사무실",
        "room": "방", "kitchen": "부엌", "bedroom": "침실", "bathroom": "욕실", "interior": "실내", "library": "도서관", "store": "가게",
        "restaurant": "식당", "cafe": "카페", "stadium": "경기장",
        "car": "자동차", "bus": "버스", "train": "기차", "bicycle": "자전거", "motorcycle": "오토바이", "airplane": "비행기", "boat": "배",
        "ship": "배", "truck": "트럭", "vehicle": "탈것", "subway": "지하철",
        "computer": "컴퓨터", "laptop": "노트북", "phone": "휴대폰", "cellphone": "휴대폰", "smartphone": "스마트폰", "tablet": "태블릿",
        "keyboard": "키보드", "monitor": "모니터", "television": "텔레비전", "camera": "카메라", "headphones": "헤드폰", "clock": "시계",
        "watch": "손목시계", "pen": "펜", "pencil": "연필", "desk": "책상", "chair": "의자", "table": "탁자", "bag": "가방", "backpack": "가방",
        "cup": "컵", "bottle": "병", "glasses": "안경", "shoes": "신발", "clothing": "옷", "hat": "모자", "umbrella": "우산", "toy": "장난감",
        "ball": "공", "game": "게임", "sport": "운동", "soccer": "축구", "basketball": "농구", "baseball": "야구", "music": "음악",
        "guitar": "기타", "piano": "피아노", "art": "예술 작품", "sculpture": "조각", "statue": "동상", "flag": "깃발", "money": "돈",
        "card": "카드", "gift": "선물", "christmas_tree": "크리스마스트리", "fireworks": "불꽃놀이", "candle": "촛불",
        "indoor": "실내", "outdoor": "야외", "structure": "구조물", "machine": "기계", "tool": "도구", "furniture": "가구"
    ]
}
