import Foundation

/// 두잇 AI 과학 엔진 (외부 AI·API 없이 직접 계산하고 설명)
/// - 공식 계산: 속력·가속도·힘·무게·일·일률·운동/위치 에너지·압력·밀도·옴의 법칙·전력·전력량·열량·파동·몰·농도
/// - 주기율표: 원자 번호·원소 기호·원자량·족·주기·전자 배치
/// - 화학식량(몰 질량), 단위 바꾸기, 핵심 개념 사전
enum DoitScience {
    /// 과학 질문이면 답(마크다운 텍스트), 아니면 nil. 빠르고 오프라인.
    static func answer(_ question: String) -> String? {
        let text = question.trimmingCharacters(in: .whitespacesAndNewlines)
        guard text.count >= 2, !isAppCommand(text) else { return nil }
        let context = SciContext(text)
        if let reply = molarMass(context) { return reply }
        if let reply = element(context) { return reply }
        if let reply = formula(context) { return reply }
        if let reply = conversion(context) { return reply }
        if let reply = concept(text) { return reply }
        return nil
    }

    // MARK: - 퀴즈

    /// 짧은 답 퀴즈 하나 (topic 예: "원소", "계산", "광합성")
    static func quiz(topic: String?) -> DoitQuizItem? {
        let t = topic.map(norm) ?? ""
        if !t.isEmpty {
            if t.contains("원소") || t.contains("주기율") || t.contains("화학") && !t.contains("반응") { return elementQuiz() }
            if t.contains("계산") || t.contains("공식") || t.contains("물리") || t.contains("전기") { return calcQuiz() }
            if let item = concepts.first(where: { $0.names.contains { norm($0).count >= 2 && (t.contains(norm($0)) || norm($0).contains(t)) } }) {
                return conceptQuiz(item)
            }
        }
        switch Int.random(in: 0..<3) {
        case 0: return elementQuiz()
        case 1: return calcQuiz()
        default: return concepts.filter(isQuizable).randomElement().flatMap(conceptQuiz)
        }
    }

    private static func elementQuiz() -> DoitQuizItem? {
        guard let e = elements.filter({ $0.z <= 30 || ["Ag", "Au", "Hg", "Pb", "I"].contains($0.symbol) }).randomElement() else { return nil }
        let details = "\(e.name)(\(e.symbol)): 원자 번호 \(e.z), \(e.period)주기" + (e.group > 0 ? " \(e.group)족" : "") + ", \(e.kind)"
        switch Int.random(in: 0..<3) {
        case 0:
            return DoitQuizItem(question: "\(e.name)의 원소 기호는 무엇일까요?", answers: [e.symbol], explanation: details)
        case 1:
            return DoitQuizItem(question: "원소 기호 \(e.symbol)는 어떤 원소일까요? (한글 이름)", answers: [e.name] + e.aliases, explanation: details)
        default:
            return DoitQuizItem(question: "\(e.name)(\(e.symbol))의 원자 번호는 몇 번일까요?", answers: ["\(e.z)", "\(e.z)번"], explanation: details)
        }
    }

    private static func calcQuiz() -> DoitQuizItem? {
        switch Int.random(in: 0..<5) {
        case 0:
            let t = Int.random(in: 2...10), v = Int.random(in: 2...15)
            return DoitQuizItem(question: "\(v * t) m를 \(t)초 동안 이동한 물체의 속력은 몇 m/s일까요?", answers: ["\(v)", "\(v)m/s"],
                                explanation: "속력 = 거리 ÷ 시간 = \(v * t) ÷ \(t) = \(v) m/s")
        case 1:
            let m = Int.random(in: 1...10), a = Int.random(in: 1...10)
            return DoitQuizItem(question: "질량 \(m) kg인 물체가 \(a) m/s²의 가속도로 움직일 때 작용한 힘은 몇 N일까요?", answers: ["\(m * a)", "\(m * a)N"],
                                explanation: "F = m × a = \(m) × \(a) = \(m * a) N")
        case 2:
            let i = Int.random(in: 1...6), r = Int.random(in: 2...10)
            return DoitQuizItem(question: "저항 \(r) Ω에 \(i) A의 전류가 흐를 때 전압은 몇 V일까요?", answers: ["\(i * r)", "\(i * r)V"],
                                explanation: "V = I × R = \(i) × \(r) = \(i * r) V (옴의 법칙)")
        case 3:
            let v = Int.random(in: 2...10), d = Int.random(in: 2...9)
            return DoitQuizItem(question: "부피 \(v) cm³, 질량 \(v * d) g인 물체의 밀도는 몇 g/cm³일까요?", answers: ["\(d)", "\(d)g/cm3", "\(d)g/cm³"],
                                explanation: "밀도 = 질량 ÷ 부피 = \(v * d) ÷ \(v) = \(d) g/cm³")
        default:
            let v = Int.random(in: 2...6), i = Int.random(in: 1...5)
            return DoitQuizItem(question: "전압 \(v) V에서 \(i) A의 전류가 흐르는 전기 기구의 전력은 몇 W일까요?", answers: ["\(v * i)", "\(v * i)W"],
                                explanation: "P = V × I = \(v) × \(i) = \(v * i) W")
        }
    }

    /// 설명 첫 줄이 "산: …"처럼 여러 용어를 나눠 설명하면 퀴즈로 내지 않음
    private static func isQuizable(_ item: SciConcept) -> Bool {
        guard let line = item.body.components(separatedBy: "\n").first else { return false }
        return !line.prefix(14).contains(":") && line.count >= 15
    }

    private static func conceptQuiz(_ item: SciConcept) -> DoitQuizItem? {
        guard var line = item.body.components(separatedBy: "\n").first else { return nil }
        for name in item.names.sorted(by: { $0.count > $1.count }) { line = line.replacingOccurrences(of: name, with: "(   )") }
        return DoitQuizItem(question: "다음 설명에 알맞은 과학 용어는 무엇일까요?\n\(line)", answers: item.names,
                            explanation: "정답: \(item.names[0])\n\(item.body)")
    }

    // MARK: - 공통

    private static func isAppCommand(_ text: String) -> Bool {
        let words = ["추가해", "추가", "타이머", "일정", "플랜", "삭제", "지워", "메모", "알람", "예약", "완료했", "단어장",
                     "할 일", "할일", "디데이", "d-day", "D-Day", "문제 내", "퀴즈", "스톱워치"]
        return words.contains { text.contains($0) }
    }

    /// 0.5 → "0.5", 13.888 → "13.89", 300000000 → "3×10⁸"
    static func fmt(_ value: Double) -> String {
        guard value.isFinite else { return "?" }
        if value == 0 { return "0" }
        let magnitude = abs(value)
        if magnitude >= 1e7 || magnitude < 1e-3 {
            var exponent = Int(floor(log10(magnitude)))
            var mantissa = value / pow(10, Double(exponent))
            if abs(mantissa) >= 9.995 { mantissa /= 10; exponent += 1 }
            let m = trim(mantissa, 2)
            return (m == "1" ? "" : m + "×") + "10" + superscript(exponent)
        }
        let digits = magnitude >= 1000 ? 1 : (magnitude >= 100 ? 2 : (magnitude >= 1 ? 3 : 4))
        return trim(value, digits)
    }

    private static func trim(_ value: Double, _ digits: Int) -> String {
        var s = String(format: "%.\(digits)f", value)
        if s.contains(".") {
            while s.hasSuffix("0") { s.removeLast() }
            if s.hasSuffix(".") { s.removeLast() }
        }
        return s == "-0" ? "0" : s
    }

    private static func superscript(_ n: Int) -> String {
        let map: [Character: Character] = ["0": "⁰", "1": "¹", "2": "²", "3": "³", "4": "⁴", "5": "⁵", "6": "⁶",
                                           "7": "⁷", "8": "⁸", "9": "⁹", "-": "⁻"]
        return String(String(n).compactMap { map[$0] })
    }

    private static func subscriptFormula(_ formula: String) -> String {
        let map: [Character: Character] = ["0": "₀", "1": "₁", "2": "₂", "3": "₃", "4": "₄", "5": "₅", "6": "₆",
                                           "7": "₇", "8": "₈", "9": "₉"]
        var out = ""
        var previous: Character = " "
        for ch in formula {
            if ch.isNumber, previous.isLetter || previous == ")" || previous == "]" || (map.values.contains(previous)) {
                out.append(map[ch] ?? ch)
                previous = map[ch] ?? ch
            } else {
                out.append(ch == "." || ch == "*" ? "·" : ch)
                previous = ch
            }
        }
        return out
    }

    private static func norm(_ s: String) -> String {
        s.lowercased().filter { !" ·・.-_\t\n'\"?!~".contains($0) }
    }

    private static let particles = ["이란", "으로", "에서", "에게", "이야", "은", "는", "이", "가", "을", "를", "의", "에", "로", "와", "과", "도", "란", "야"]

    private static func tokens(_ text: String) -> [String] {
        text.split(whereSeparator: { " ,.?!~\n\t()·".contains($0) }).map { raw in
            var word = String(raw)
            for p in particles where word.count > p.count && word.hasSuffix(p) {
                word.removeLast(p.count)
                break
            }
            return word
        }
    }

    private static func lineFor(_ q: SciQ) -> String? {
        guard q.dim != .temperature, q.dim != .percent else { return nil }
        let base = siShow(q.dim)
        guard q.unit.show != base else { return nil }
        return "\(q.shown) = \(fmt(q.si)) \(base)"
    }

    private static func siShow(_ dim: SciDim) -> String {
        switch dim {
        case .mass: return "kg"
        case .length: return "m"
        case .time: return "s"
        case .speed: return "m/s"
        case .accel: return "m/s²"
        case .force: return "N"
        case .energy: return "J"
        case .power: return "W"
        case .pressure: return "Pa"
        case .area: return "m²"
        case .volume: return "m³"
        case .density: return "kg/m³"
        case .voltage: return "V"
        case .current: return "A"
        case .resistance: return "Ω"
        case .frequency: return "Hz"
        case .temperature: return "℃"
        case .mole: return "mol"
        case .molarMass: return "g/mol"
        case .molarity: return "M"
        case .specificHeat: return "J/(kg·℃)"
        case .percent: return "%"
        }
    }

    private static func out(_ title: String, formula: String, given: [SciQ] = [], extra: [String] = [],
                            sub: String, answer: String, note: String? = nil) -> String {
        var lines = ["**\(title)**", "공식: \(formula)"]
        let conversions = given.compactMap(lineFor) + extra
        if !conversions.isEmpty { lines.append("단위 맞추기: " + conversions.joined(separator: ", ")) }
        lines.append("대입: \(sub)")
        lines.append("**답: \(answer)**")
        if let note { lines.append(note) }
        return lines.joined(separator: "\n")
    }

    private static func durationText(_ seconds: Double) -> String {
        let total = Int(seconds.rounded())
        if total >= 3600 {
            let h = total / 3600, m = (total % 3600) / 60
            return m == 0 ? "\(h)시간" : "\(h)시간 \(m)분"
        }
        if total >= 60 {
            let m = total / 60, s = total % 60
            return s == 0 ? "\(m)분" : "\(m)분 \(s)초"
        }
        return "\(fmt(seconds))초"
    }

    // MARK: - 수치·단위 읽기

    fileprivate enum SciDim {
        case mass, length, time, speed, accel, force, energy, power, pressure, area, volume, density
        case voltage, current, resistance, frequency, temperature, mole, molarMass, molarity, specificHeat, percent
    }

    fileprivate struct SciUnit {
        let token: String
        let dim: SciDim
        let factor: Double
        let show: String
        var offset: Double = 0
    }

    fileprivate struct SciQ {
        let dim: SciDim
        let si: Double
        let raw: Double
        let unit: SciUnit
        let label: String
        let start: Int
        let end: Int
        var shown: String { "\(DoitScience.fmt(raw)) \(unit.show)" }
    }

    private static let units: [SciUnit] = {
        let list: [SciUnit] = [
            SciUnit(token: "kg", dim: .mass, factor: 1, show: "kg"), SciUnit(token: "mg", dim: .mass, factor: 1e-6, show: "mg"),
            SciUnit(token: "g", dim: .mass, factor: 1e-3, show: "g"), SciUnit(token: "톤", dim: .mass, factor: 1000, show: "t"),
            SciUnit(token: "킬로그램", dim: .mass, factor: 1, show: "kg"), SciUnit(token: "그램", dim: .mass, factor: 1e-3, show: "g"),
            SciUnit(token: "km", dim: .length, factor: 1000, show: "km"), SciUnit(token: "cm", dim: .length, factor: 0.01, show: "cm"),
            SciUnit(token: "mm", dim: .length, factor: 0.001, show: "mm"), SciUnit(token: "nm", dim: .length, factor: 1e-9, show: "nm"),
            SciUnit(token: "μm", dim: .length, factor: 1e-6, show: "μm"), SciUnit(token: "m", dim: .length, factor: 1, show: "m"),
            SciUnit(token: "킬로미터", dim: .length, factor: 1000, show: "km"), SciUnit(token: "센티미터", dim: .length, factor: 0.01, show: "cm"),
            SciUnit(token: "밀리미터", dim: .length, factor: 0.001, show: "mm"), SciUnit(token: "미터", dim: .length, factor: 1, show: "m"),
            SciUnit(token: "시간", dim: .time, factor: 3600, show: "h"), SciUnit(token: "hr", dim: .time, factor: 3600, show: "h"),
            SciUnit(token: "h", dim: .time, factor: 3600, show: "h"), SciUnit(token: "분", dim: .time, factor: 60, show: "min"),
            SciUnit(token: "min", dim: .time, factor: 60, show: "min"), SciUnit(token: "초", dim: .time, factor: 1, show: "s"),
            SciUnit(token: "s", dim: .time, factor: 1, show: "s"), SciUnit(token: "ms", dim: .time, factor: 0.001, show: "ms"),
            SciUnit(token: "km/h", dim: .speed, factor: 1 / 3.6, show: "km/h"), SciUnit(token: "km/시", dim: .speed, factor: 1 / 3.6, show: "km/h"),
            SciUnit(token: "m/s", dim: .speed, factor: 1, show: "m/s"), SciUnit(token: "cm/s", dim: .speed, factor: 0.01, show: "cm/s"),
            SciUnit(token: "km/s", dim: .speed, factor: 1000, show: "km/s"),
            SciUnit(token: "m/s2", dim: .accel, factor: 1, show: "m/s²"),
            SciUnit(token: "kN", dim: .force, factor: 1000, show: "kN"), SciUnit(token: "N", dim: .force, factor: 1, show: "N"),
            SciUnit(token: "뉴턴", dim: .force, factor: 1, show: "N"),
            SciUnit(token: "kWh", dim: .energy, factor: 3.6e6, show: "kWh"), SciUnit(token: "Wh", dim: .energy, factor: 3600, show: "Wh"),
            SciUnit(token: "kJ", dim: .energy, factor: 1000, show: "kJ"), SciUnit(token: "J", dim: .energy, factor: 1, show: "J"),
            SciUnit(token: "kcal", dim: .energy, factor: 4200, show: "kcal"), SciUnit(token: "cal", dim: .energy, factor: 4.2, show: "cal"),
            SciUnit(token: "킬로칼로리", dim: .energy, factor: 4200, show: "kcal"), SciUnit(token: "칼로리", dim: .energy, factor: 4.2, show: "cal"),
            SciUnit(token: "kW", dim: .power, factor: 1000, show: "kW"), SciUnit(token: "W", dim: .power, factor: 1, show: "W"),
            SciUnit(token: "와트", dim: .power, factor: 1, show: "W"),
            SciUnit(token: "kPa", dim: .pressure, factor: 1000, show: "kPa"), SciUnit(token: "hPa", dim: .pressure, factor: 100, show: "hPa"),
            SciUnit(token: "Pa", dim: .pressure, factor: 1, show: "Pa"), SciUnit(token: "N/m2", dim: .pressure, factor: 1, show: "N/m²"),
            SciUnit(token: "atm", dim: .pressure, factor: 101325, show: "atm"), SciUnit(token: "기압", dim: .pressure, factor: 101325, show: "기압"),
            SciUnit(token: "km2", dim: .area, factor: 1e6, show: "km²"), SciUnit(token: "m2", dim: .area, factor: 1, show: "m²"),
            SciUnit(token: "cm2", dim: .area, factor: 1e-4, show: "cm²"), SciUnit(token: "mm2", dim: .area, factor: 1e-6, show: "mm²"),
            SciUnit(token: "m3", dim: .volume, factor: 1, show: "m³"), SciUnit(token: "cm3", dim: .volume, factor: 1e-6, show: "cm³"),
            SciUnit(token: "cc", dim: .volume, factor: 1e-6, show: "cc"), SciUnit(token: "mL", dim: .volume, factor: 1e-6, show: "mL"),
            SciUnit(token: "ml", dim: .volume, factor: 1e-6, show: "mL"), SciUnit(token: "dL", dim: .volume, factor: 1e-4, show: "dL"),
            SciUnit(token: "L", dim: .volume, factor: 1e-3, show: "L"), SciUnit(token: "리터", dim: .volume, factor: 1e-3, show: "L"),
            SciUnit(token: "g/cm3", dim: .density, factor: 1000, show: "g/cm³"), SciUnit(token: "g/mL", dim: .density, factor: 1000, show: "g/mL"),
            SciUnit(token: "g/ml", dim: .density, factor: 1000, show: "g/mL"), SciUnit(token: "kg/m3", dim: .density, factor: 1, show: "kg/m³"),
            SciUnit(token: "kg/L", dim: .density, factor: 1000, show: "kg/L"), SciUnit(token: "g/L", dim: .density, factor: 1, show: "g/L"),
            SciUnit(token: "kV", dim: .voltage, factor: 1000, show: "kV"), SciUnit(token: "mV", dim: .voltage, factor: 0.001, show: "mV"),
            SciUnit(token: "V", dim: .voltage, factor: 1, show: "V"), SciUnit(token: "볼트", dim: .voltage, factor: 1, show: "V"),
            SciUnit(token: "mA", dim: .current, factor: 0.001, show: "mA"), SciUnit(token: "A", dim: .current, factor: 1, show: "A"),
            SciUnit(token: "암페어", dim: .current, factor: 1, show: "A"),
            SciUnit(token: "kΩ", dim: .resistance, factor: 1000, show: "kΩ"), SciUnit(token: "Ω", dim: .resistance, factor: 1, show: "Ω"),
            SciUnit(token: "옴", dim: .resistance, factor: 1, show: "Ω"),
            SciUnit(token: "MHz", dim: .frequency, factor: 1e6, show: "MHz"), SciUnit(token: "kHz", dim: .frequency, factor: 1000, show: "kHz"),
            SciUnit(token: "Hz", dim: .frequency, factor: 1, show: "Hz"), SciUnit(token: "헤르츠", dim: .frequency, factor: 1, show: "Hz"),
            SciUnit(token: "℃", dim: .temperature, factor: 1, show: "℃"), SciUnit(token: "도", dim: .temperature, factor: 1, show: "℃"),
            SciUnit(token: "K", dim: .temperature, factor: 1, show: "K", offset: -273.15),
            SciUnit(token: "℉", dim: .temperature, factor: 5.0 / 9.0, show: "℉", offset: -32.0 * 5.0 / 9.0),
            SciUnit(token: "mmol", dim: .mole, factor: 0.001, show: "mmol"), SciUnit(token: "mol", dim: .mole, factor: 1, show: "mol"),
            SciUnit(token: "몰", dim: .mole, factor: 1, show: "mol"),
            SciUnit(token: "g/mol", dim: .molarMass, factor: 1, show: "g/mol"),
            SciUnit(token: "mol/L", dim: .molarity, factor: 1, show: "M"), SciUnit(token: "M", dim: .molarity, factor: 1, show: "M"),
            SciUnit(token: "J/g℃", dim: .specificHeat, factor: 1000, show: "J/(g·℃)"),
            SciUnit(token: "cal/g℃", dim: .specificHeat, factor: 4200, show: "cal/(g·℃)"),
            SciUnit(token: "kJ/kg℃", dim: .specificHeat, factor: 1000, show: "kJ/(kg·℃)"),
            SciUnit(token: "kcal/kg℃", dim: .specificHeat, factor: 4200, show: "kcal/(kg·℃)"),
            SciUnit(token: "J/kg℃", dim: .specificHeat, factor: 1, show: "J/(kg·℃)"),
            SciUnit(token: "%", dim: .percent, factor: 1, show: "%")
        ]
        return list.sorted { $0.token.count > $1.token.count }
    }()

    fileprivate struct SciContext {
        let original: String
        let text: String
        let chars: [Character]
        let quantities: [SciQ]

        init(_ raw: String) {
            original = raw
            let cleaned = SciContext.prepare(raw)
            text = cleaned
            chars = Array(cleaned)
            quantities = SciContext.scan(chars)
        }

        func first(_ dim: SciDim) -> SciQ? { quantities.first { $0.dim == dim } }
        func all(_ dim: SciDim) -> [SciQ] { quantities.filter { $0.dim == dim } }
        func has(_ words: [String]) -> Bool { words.contains { text.contains($0) } }

        /// 그 낱말이 "구하려는 값"으로 쓰였는지 (바로 뒤에 숫자가 오면 주어진 값의 이름표)
        func asked(_ word: String, notBefore: [String] = [], notAfter: [String] = []) -> Bool {
            var from = text.startIndex
            while from < text.endIndex, let range = text.range(of: word, range: from..<text.endIndex) {
                from = range.upperBound
                let before = text[..<range.lowerBound]
                let after = text[range.upperBound...]
                if let previous = before.reversed().first(where: { $0 != " " }), previous.isNumber { continue }
                if notBefore.contains(where: { before.hasSuffix($0) }) { continue }
                if notAfter.contains(where: { after.hasPrefix($0) }) { continue }
                let rest = after.drop { " :=은는이가을를의(".contains($0) }
                if let next = rest.first, next.isNumber || (next == "-" && rest.dropFirst().first?.isNumber == true) { continue }
                return true
            }
            return false
        }

        func askedAny(_ words: [String], notBefore: [String] = [], notAfter: [String] = []) -> Bool {
            words.contains { asked($0, notBefore: notBefore, notAfter: notAfter) }
        }

        /// 기호 통일: ° C → ℃, m/s² → m/s2, J/(g·℃) → J/g℃, 1,000 → 1000
        private static func prepare(_ raw: String) -> String {
            var t = raw.replacingOccurrences(of: "°C", with: "℃").replacingOccurrences(of: "° C", with: "℃")
                .replacingOccurrences(of: "°F", with: "℉").replacingOccurrences(of: "\u{2126}", with: "Ω")
                .replacingOccurrences(of: "㎞", with: "km").replacingOccurrences(of: "㎏", with: "kg")
                .replacingOccurrences(of: "㎝", with: "cm").replacingOccurrences(of: "㎖", with: "mL")
                .replacingOccurrences(of: "ℓ", with: "L")
            // 단위 뒤 지수: m², s^2 → m2, s2 (숫자 지수 10^8 은 그대로)
            var output = ""
            let characters = Array(t)
            var i = 0
            while i < characters.count {
                let ch = characters[i]
                let previous: Character? = i > 0 ? characters[i - 1] : nil
                let previousIsLetter = previous.map { $0.isASCII && $0.isLetter } ?? false
                if ch == "²" && previousIsLetter { output.append("2") }
                else if ch == "³" && previousIsLetter { output.append("3") }
                else if ch == "^" && previousIsLetter && i + 1 < characters.count && "23".contains(characters[i + 1]) { }
                else { output.append(ch) }
                i += 1
            }
            t = output
            t = t.replacingOccurrences(of: #"(k?cal|k?J)\s*/\s*\(?\s*(k?g)\s*[·⋅•.*×]?\s*(℃|K|도)\s*\)?"#,
                                       with: "$1/$2℃", options: .regularExpression)
            for _ in 0..<2 {
                t = t.replacingOccurrences(of: #"(\d),(\d{3})"#, with: "$1$2", options: .regularExpression)
            }
            return t
        }

        private static func scan(_ chars: [Character]) -> [SciQ] {
            var result: [SciQ] = []
            var i = 0
            var lastEnd = 0
            let supers: [Character: Character] = ["⁰": "0", "¹": "1", "²": "2", "³": "3", "⁴": "4", "⁵": "5", "⁶": "6",
                                                  "⁷": "7", "⁸": "8", "⁹": "9", "⁻": "-"]
            while i < chars.count {
                let ch = chars[i]
                guard ch.isNumber, ch.isASCII else { i += 1; continue }
                if i > 0, (chars[i - 1].isASCII && chars[i - 1].isLetter) || chars[i - 1] == ")" { i += 1; continue }
                let start = i
                var numberText = ""
                while i < chars.count, (chars[i].isNumber && chars[i].isASCII) || (chars[i] == "." && i + 1 < chars.count && chars[i + 1].isNumber) {
                    numberText.append(chars[i]); i += 1
                }
                guard var value = Double(numberText) else { continue }
                if start > 0, chars[start - 1] == "-", start < 2 || !(chars[start - 2].isNumber || chars[start - 2].isLetter) { value = -value }
                // 과학적 표기: 3×10^8, 3×10⁸, 3e8
                var j = i
                while j < chars.count, chars[j] == " " { j += 1 }
                if j < chars.count, "×xX*".contains(chars[j]) {
                    var k = j + 1
                    while k < chars.count, chars[k] == " " { k += 1 }
                    if k + 1 < chars.count, chars[k] == "1", chars[k + 1] == "0" {
                        k += 2
                        if k < chars.count, chars[k] == "^" { k += 1 }
                        var exponent = ""
                        while k < chars.count {
                            if let s = supers[chars[k]] { exponent.append(s) }
                            else if chars[k].isNumber && chars[k].isASCII || (chars[k] == "-" && exponent.isEmpty) { exponent.append(chars[k]) }
                            else { break }
                            k += 1
                        }
                        if let e = Double(exponent) { value *= pow(10, e); i = k }
                    }
                } else if i < chars.count, chars[i] == "e" || chars[i] == "E" {
                    var k = i + 1
                    var exponent = ""
                    if k < chars.count, chars[k] == "-" { exponent = "-"; k += 1 }
                    while k < chars.count, chars[k].isNumber, chars[k].isASCII { exponent.append(chars[k]); k += 1 }
                    if let e = Double(exponent), exponent != "-" { value *= pow(10, e); i = k }
                }
                // 단위
                var u = i
                while u < chars.count, chars[u] == " ", u - i < 2 { u += 1 }
                let rest = String(chars[u..<min(chars.count, u + 10)])
                guard var unit = DoitScience.units.first(where: { candidate in
                    guard rest.hasPrefix(candidate.token) else { return false }
                    let after = rest.dropFirst(candidate.token.count).first
                    if let last = candidate.token.last, last.isASCII, last.isLetter || last.isNumber,
                       let after, after.isASCII, after.isLetter || after.isNumber { return false }
                    if candidate.token == "분", after == "의" { return false }
                    return true
                }) else { continue }
                let end = u + unit.token.count
                let labelStart = max(lastEnd, start - 10)
                let label = String(chars[labelStart..<start]).trimmingCharacters(in: .whitespaces)
                // 시속 60km → 60 km/h, 초속 3m → 3 m/s, 화씨 100도 → ℉
                if label.hasSuffix("시속"), unit.dim == .length, unit.token == "km" || unit.token == "킬로미터" {
                    unit = SciUnit(token: unit.token, dim: .speed, factor: 1 / 3.6, show: "km/h")
                } else if label.hasSuffix("초속"), unit.dim == .length {
                    unit = SciUnit(token: unit.token, dim: .speed, factor: unit.factor, show: unit.show + "/s")
                } else if label.hasSuffix("화씨"), unit.token == "도" {
                    unit = SciUnit(token: "도", dim: .temperature, factor: 5.0 / 9.0, show: "℉", offset: -32.0 * 5.0 / 9.0)
                }
                let si = value * unit.factor + unit.offset
                result.append(SciQ(dim: unit.dim, si: si, raw: value, unit: unit, label: label, start: start, end: end))
                i = end
                lastEnd = end
            }
            return result
        }
    }

    // MARK: - 공식 계산

    private static func formula(_ c: SciContext) -> String? {
        guard !c.quantities.isEmpty else { return nil }
        let solvers: [(SciContext) -> String?] = [wave, electricity, heat, density, pressure, kinetic, potential,
                                                  mechanicalPower, work, weight, force, speed, concentration, mole]
        for solver in solvers {
            if let reply = solver(c) { return reply }
        }
        return generic(c)
    }

    private static let speedWords = ["속력", "속도", "빠르기"]

    private static func askedSpeed(_ c: SciContext) -> Bool {
        c.askedAny(speedWords, notBefore: ["가"])
    }

    private static func speed(_ c: SciContext) -> String? {
        let d = c.first(.length), t = c.first(.time), v = c.first(.speed)
        let kmh = (d?.unit.show == "km" && t?.unit.show == "h") || v?.unit.show == "km/h"
        if askedSpeed(c), let d, let t, t.si > 0 {
            let ms = d.si / t.si
            if kmh {
                let value = (d.si / 1000) / (t.si / 3600)
                return out("속력 구하기", formula: "속력 = 이동 거리 ÷ 걸린 시간",
                           sub: "\(fmt(d.si / 1000)) km ÷ \(fmt(t.si / 3600)) h", answer: "\(fmt(value)) km/h (약 \(fmt(ms)) m/s)")
            }
            return out("속력 구하기", formula: "속력 = 이동 거리 ÷ 걸린 시간", given: [d, t],
                       sub: "\(fmt(d.si)) m ÷ \(fmt(t.si)) s", answer: "\(fmt(ms)) m/s (약 \(fmt(ms * 3.6)) km/h)")
        }
        if c.askedAny(["거리", "이동 거리", "얼마나 멀리", "몇 km", "몇 m"]), let v, let t {
            if v.unit.show == "km/h" {
                let km = v.raw * (t.si / 3600)
                return out("거리 구하기", formula: "이동 거리 = 속력 × 시간",
                           sub: "\(fmt(v.raw)) km/h × \(fmt(t.si / 3600)) h", answer: "\(fmt(km)) km")
            }
            let meters = v.si * t.si
            return out("거리 구하기", formula: "이동 거리 = 속력 × 시간", given: [v, t],
                       sub: "\(fmt(v.si)) m/s × \(fmt(t.si)) s", answer: "\(fmt(meters)) m" + (meters >= 1000 ? " (\(fmt(meters / 1000)) km)" : ""))
        }
        if c.askedAny(["시간", "걸리는", "걸릴까", "걸려"]), let d, let v, v.si > 0 {
            let seconds = d.si / v.si
            if v.unit.show == "km/h" {
                let hours = (d.si / 1000) / v.raw
                return out("걸리는 시간 구하기", formula: "시간 = 이동 거리 ÷ 속력",
                           sub: "\(fmt(d.si / 1000)) km ÷ \(fmt(v.raw)) km/h", answer: "\(fmt(hours)) h (\(durationText(seconds)))")
            }
            return out("걸리는 시간 구하기", formula: "시간 = 이동 거리 ÷ 속력", given: [d, v],
                       sub: "\(fmt(d.si)) m ÷ \(fmt(v.si)) m/s", answer: "\(fmt(seconds)) s" + (seconds >= 60 ? " (\(durationText(seconds)))" : ""))
        }
        return nil
    }

    private static func force(_ c: SciContext) -> String? {
        let m = c.first(.mass), a = c.first(.accel), f = c.first(.force)
        if c.asked("힘", notAfter: ["들", "든", "내", "써"]), let m, let a {
            return out("힘 구하기 (뉴턴 운동 제2법칙)", formula: "F = m × a", given: [m],
                       sub: "F = \(fmt(m.si)) kg × \(fmt(a.si)) m/s²", answer: "\(fmt(m.si * a.si)) N")
        }
        if c.asked("가속도") {
            if let f, let m, m.si > 0 {
                return out("가속도 구하기", formula: "a = F ÷ m", given: [f, m],
                           sub: "a = \(fmt(f.si)) N ÷ \(fmt(m.si)) kg", answer: "\(fmt(f.si / m.si)) m/s²")
            }
            let speeds = c.all(.speed)
            if let t = c.first(.time), t.si > 0, let firstSpeed = speeds.first {
                let change = speeds.count >= 2 ? speeds[1].si - firstSpeed.si : firstSpeed.si
                let sub = speeds.count >= 2
                    ? "a = (\(fmt(speeds[1].si)) − \(fmt(firstSpeed.si))) m/s ÷ \(fmt(t.si)) s"
                    : "a = \(fmt(change)) m/s ÷ \(fmt(t.si)) s"
                return out("가속도 구하기", formula: "가속도 = 속도 변화량 ÷ 걸린 시간", given: speeds.prefix(2) + [t],
                           sub: sub, answer: "\(fmt(change / t.si)) m/s²",
                           note: speeds.count >= 2 ? nil : "처음에 정지해 있었다고 보고 계산했어요.")
            }
        }
        if c.asked("질량"), let f, let a, a.si != 0, !c.has(["무게"]) {
            return out("질량 구하기", formula: "m = F ÷ a", given: [f],
                       sub: "m = \(fmt(f.si)) N ÷ \(fmt(a.si)) m/s²", answer: "\(fmt(f.si / a.si)) kg")
        }
        return nil
    }

    private static func weight(_ c: SciContext) -> String? {
        if c.askedAny(["무게", "중력의 크기", "중력은", "중력이"]), let m = c.first(.mass) {
            return out("무게 구하기", formula: "무게 = 9.8 × 질량 (W = mg)", given: [m],
                       sub: "W = \(fmt(m.si)) kg × 9.8 m/s²", answer: "\(fmt(m.si * 9.8)) N",
                       note: "질량은 어디서나 같지만, 무게는 중력에 따라 달라져요. 달에서는 지구의 약 1/6이에요.")
        }
        if c.has(["무게"]), c.asked("질량"), let w = c.first(.force) {
            return out("질량 구하기", formula: "질량 = 무게 ÷ 9.8", given: [w],
                       sub: "m = \(fmt(w.si)) N ÷ 9.8 m/s²", answer: "\(fmt(w.si / 9.8)) kg")
        }
        return nil
    }

    /// 힘이 없으면 질량으로 무게(mg)를 대신 씀
    private static func forceOrWeight(_ c: SciContext) -> (value: Double, text: String, note: String?)? {
        if let f = c.first(.force) { return (f.si, "\(fmt(f.si)) N", lineFor(f)) }
        if let m = c.first(.mass) {
            return (m.si * 9.8, "(\(fmt(m.si)) kg × 9.8) N", "물체의 무게 = 9.8 × \(fmt(m.si)) kg = \(fmt(m.si * 9.8)) N")
        }
        return nil
    }

    private static func work(_ c: SciContext) -> String? {
        guard c.askedAny(["한 일", "일의 양", "일의 크기", "일은", "일을", "일이", "일(J)"]) else { return nil }
        guard let s = c.first(.length), let f = forceOrWeight(c) else { return nil }
        return out("일 구하기", formula: "일(W) = 힘 × 힘의 방향으로 이동한 거리", given: [s], extra: f.note.map { [$0] } ?? [],
                   sub: "W = \(f.text) × \(fmt(s.si)) m", answer: "\(fmt(f.value * s.si)) J",
                   note: "힘의 방향과 이동 방향이 수직이면(예: 물체를 들고 수평으로 걷기) 한 일은 0이에요.")
    }

    private static func mechanicalPower(_ c: SciContext) -> String? {
        guard c.asked("일률"), let t = c.first(.time), t.si > 0 else { return nil }
        if let w = c.first(.energy) {
            return out("일률 구하기", formula: "일률(P) = 일 ÷ 걸린 시간", given: [w, t],
                       sub: "P = \(fmt(w.si)) J ÷ \(fmt(t.si)) s", answer: "\(fmt(w.si / t.si)) W")
        }
        if let s = c.first(.length), let f = forceOrWeight(c) {
            let workDone = f.value * s.si
            return out("일률 구하기", formula: "일률 = (힘 × 거리) ÷ 시간", given: [s, t], extra: f.note.map { [$0] } ?? [],
                       sub: "P = \(f.text) × \(fmt(s.si)) m ÷ \(fmt(t.si)) s", answer: "\(fmt(workDone / t.si)) W")
        }
        return nil
    }

    private static func kinetic(_ c: SciContext) -> String? {
        guard c.askedAny(["운동 에너지", "운동에너지"]), let m = c.first(.mass), let v = c.first(.speed) else { return nil }
        let energy = 0.5 * m.si * v.si * v.si
        return out("운동 에너지 구하기", formula: "Eₖ = ½ × m × v²", given: [m, v],
                   sub: "Eₖ = ½ × \(fmt(m.si)) kg × (\(fmt(v.si)) m/s)²", answer: "\(fmt(energy)) J",
                   note: "속력이 2배가 되면 운동 에너지는 4배가 돼요.")
    }

    private static func potential(_ c: SciContext) -> String? {
        guard c.askedAny(["위치 에너지", "위치에너지"]), let m = c.first(.mass), let h = c.first(.length) else { return nil }
        return out("중력에 의한 위치 에너지 구하기", formula: "Eₚ = 9.8 × m × h", given: [m, h],
                   sub: "Eₚ = 9.8 × \(fmt(m.si)) kg × \(fmt(h.si)) m", answer: "\(fmt(9.8 * m.si * h.si)) J")
    }

    private static func pressure(_ c: SciContext) -> String? {
        guard c.asked("압력"), let area = c.first(.area), area.si > 0, let f = forceOrWeight(c) else { return nil }
        return out("압력 구하기", formula: "압력 = 힘 ÷ 힘을 받는 넓이", given: [area], extra: f.note.map { [$0] } ?? [],
                   sub: "P = \(f.text) ÷ \(fmt(area.si)) m²", answer: "\(fmt(f.value / area.si)) Pa (N/m²)",
                   note: "같은 힘이라도 넓이가 좁을수록 압력이 커져요. (예: 칼날, 눈 위의 스키)")
    }

    private static func density(_ c: SciContext) -> String? {
        let m = c.first(.mass), v = c.first(.volume), rho = c.first(.density)
        let small = [m?.unit.show, v?.unit.show, rho?.unit.show].contains { ["g", "mg", "cm³", "mL", "cc", "g/cm³", "g/mL"].contains($0 ?? "") }
        if c.asked("밀도"), let m, let v, v.si > 0 {
            if small {
                let grams = m.si * 1000, cm3 = v.si * 1e6
                return out("밀도 구하기", formula: "밀도 = 질량 ÷ 부피",
                           sub: "\(fmt(grams)) g ÷ \(fmt(cm3)) cm³", answer: "\(fmt(grams / cm3)) g/cm³",
                           note: "물의 밀도는 약 1 g/cm³이에요. 이보다 크면 물에 가라앉고 작으면 떠요.")
            }
            return out("밀도 구하기", formula: "밀도 = 질량 ÷ 부피", given: [m, v],
                       sub: "\(fmt(m.si)) kg ÷ \(fmt(v.si)) m³", answer: "\(fmt(m.si / v.si)) kg/m³ (= \(fmt(m.si / v.si / 1000)) g/cm³)")
        }
        if c.asked("부피"), let m, let rho, rho.si > 0 {
            let grams = m.si * 1000, gcm3 = rho.si / 1000
            return out("부피 구하기", formula: "부피 = 질량 ÷ 밀도",
                       sub: "\(fmt(grams)) g ÷ \(fmt(gcm3)) g/cm³", answer: "\(fmt(grams / gcm3)) cm³")
        }
        if c.asked("질량"), let v, let rho {
            let cm3 = v.si * 1e6, gcm3 = rho.si / 1000
            return out("질량 구하기", formula: "질량 = 밀도 × 부피",
                       sub: "\(fmt(gcm3)) g/cm³ × \(fmt(cm3)) cm³", answer: "\(fmt(gcm3 * cm3)) g")
        }
        return nil
    }

    private static func electricity(_ c: SciContext) -> String? {
        let v = c.first(.voltage), i = c.first(.current), r = c.first(.resistance), p = c.first(.power), t = c.first(.time)
        if c.asked("전력량") {
            var watts: Double?
            var how = ""
            if let p { watts = p.si; how = "\(fmt(p.si)) W" }
            else if let v, let i { watts = v.si * i.si; how = "(\(fmt(v.si)) V × \(fmt(i.si)) A)" }
            if let watts, let t {
                let wh = watts * t.si / 3600
                let whText = wh >= 1000 ? "\(fmt(wh)) Wh (\(fmt(wh / 1000)) kWh)" : "\(fmt(wh)) Wh"
                return out("전력량 구하기", formula: "전력량 = 전력 × 시간",
                           sub: "\(how) × \(fmt(t.si / 3600)) h", answer: "\(whText) = \(fmt(watts * t.si)) J")
            }
        }
        if c.asked("전력", notAfter: ["량"]) || c.asked("소비 전력") {
            if let v, let i {
                return out("전력 구하기", formula: "P = V × I", given: [v, i],
                           sub: "P = \(fmt(v.si)) V × \(fmt(i.si)) A", answer: "\(fmt(v.si * i.si)) W")
            }
            if let i, let r {
                return out("전력 구하기", formula: "P = I² × R", given: [i, r],
                           sub: "P = (\(fmt(i.si)) A)² × \(fmt(r.si)) Ω", answer: "\(fmt(i.si * i.si * r.si)) W")
            }
            if let v, let r, r.si > 0 {
                return out("전력 구하기", formula: "P = V² ÷ R", given: [v, r],
                           sub: "P = (\(fmt(v.si)) V)² ÷ \(fmt(r.si)) Ω", answer: "\(fmt(v.si * v.si / r.si)) W")
            }
        }
        if c.asked("전류") {
            if let v, let r, r.si > 0 {
                return out("전류 구하기 (옴의 법칙)", formula: "I = V ÷ R", given: [v, r],
                           sub: "I = \(fmt(v.si)) V ÷ \(fmt(r.si)) Ω", answer: "\(fmt(v.si / r.si)) A")
            }
            if let p, let v, v.si > 0 {
                return out("전류 구하기", formula: "I = P ÷ V", given: [p, v],
                           sub: "I = \(fmt(p.si)) W ÷ \(fmt(v.si)) V", answer: "\(fmt(p.si / v.si)) A")
            }
        }
        if c.asked("전압") {
            if let i, let r {
                return out("전압 구하기 (옴의 법칙)", formula: "V = I × R", given: [i, r],
                           sub: "V = \(fmt(i.si)) A × \(fmt(r.si)) Ω", answer: "\(fmt(i.si * r.si)) V")
            }
            if let p, let i, i.si > 0 {
                return out("전압 구하기", formula: "V = P ÷ I", given: [p, i],
                           sub: "V = \(fmt(p.si)) W ÷ \(fmt(i.si)) A", answer: "\(fmt(p.si / i.si)) V")
            }
        }
        if c.asked("저항") {
            let resistors = c.all(.resistance)
            if resistors.count >= 2, c.has(["직렬", "병렬"]) {
                let values = resistors.map(\.si)
                if c.has(["병렬"]) {
                    let total = 1 / values.reduce(0) { $0 + 1 / $1 }
                    return out("병렬 연결 합성 저항", formula: "1/R = 1/R₁ + 1/R₂ + …",
                               sub: "1/R = " + values.map { "1/\(fmt($0))" }.joined(separator: " + "), answer: "\(fmt(total)) Ω",
                               note: "병렬로 연결하면 합성 저항은 가장 작은 저항보다도 작아져요.")
                }
                return out("직렬 연결 합성 저항", formula: "R = R₁ + R₂ + …",
                           sub: "R = " + values.map { fmt($0) }.joined(separator: " + "), answer: "\(fmt(values.reduce(0, +))) Ω")
            }
            if let v, let i, i.si > 0 {
                return out("저항 구하기 (옴의 법칙)", formula: "R = V ÷ I", given: [v, i],
                           sub: "R = \(fmt(v.si)) V ÷ \(fmt(i.si)) A", answer: "\(fmt(v.si / i.si)) Ω")
            }
            if let v, let p, p.si > 0 {
                return out("저항 구하기", formula: "R = V² ÷ P", given: [v, p],
                           sub: "R = (\(fmt(v.si)) V)² ÷ \(fmt(p.si)) W", answer: "\(fmt(v.si * v.si / p.si)) Ω")
            }
        }
        return nil
    }

    private static func heat(_ c: SciContext) -> String? {
        let askHeat = c.askedAny(["열량", "열에너지", "열 에너지", "필요한 열"])
        let askSpecific = c.asked("비열")
        guard askHeat || askSpecific else { return nil }
        let temps = c.all(.temperature)
        var deltaT: Double?
        var deltaText = ""
        if temps.count >= 2 {
            deltaT = abs(temps[1].si - temps[0].si)
            deltaText = "(\(fmt(max(temps[0].si, temps[1].si))) − \(fmt(min(temps[0].si, temps[1].si)))) ℃"
        } else if let only = temps.first {
            deltaT = abs(only.si)
            deltaText = "\(fmt(abs(only.si))) ℃"
        }
        guard let deltaT, let m = c.first(.mass) else { return nil }
        if askHeat {
            var note: String?
            var cValue: Double
            var cToken: String
            var cShow: String
            if let given = c.first(.specificHeat) {
                cValue = given.raw; cToken = given.unit.token; cShow = given.unit.show
            } else if c.has(["물"]) {
                cValue = 1; cToken = "cal/g℃"; cShow = "cal/(g·℃)"
                note = "물의 비열 1 cal/(g·℃) (≈ 4.2 J/(g·℃))를 썼어요."
            } else { return nil }
            let perGram = cToken.contains("/g")
            let mass = perGram ? m.si * 1000 : m.si
            let massUnit = perGram ? "g" : "kg"
            let qUnit = cToken.components(separatedBy: "/").first ?? "J"
            let q = cValue * mass * deltaT
            return out("열량 구하기", formula: "Q = c × m × Δt (비열 × 질량 × 온도 변화)",
                       sub: "Q = \(fmt(cValue)) \(cShow) × \(fmt(mass)) \(massUnit) × \(deltaText)",
                       answer: "\(fmt(q)) \(qUnit)", note: note)
        }
        guard let q = c.first(.energy), deltaT > 0 else { return nil }
        let isCal = q.unit.show == "cal" || q.unit.show == "kcal"
        let grams = q.unit.show == "kcal" ? m.si : m.si * 1000
        let massUnit = q.unit.show == "kcal" ? "kg" : "g"
        let energy = isCal ? q.raw : q.si
        let energyUnit = isCal ? q.unit.show : "J"
        let value = energy / (grams * deltaT)
        return out("비열 구하기", formula: "c = Q ÷ (m × Δt)",
                   sub: "c = \(fmt(energy)) \(energyUnit) ÷ (\(fmt(grams)) \(massUnit) × \(deltaText))",
                   answer: "\(fmt(value)) \(energyUnit)/(\(massUnit)·℃)",
                   note: "비열이 클수록 온도가 잘 변하지 않아요. 물은 비열이 커서 해안 지역의 기온 변화가 작아요.")
    }

    private static func wave(_ c: SciContext) -> String? {
        let f = c.first(.frequency), lambda = c.first(.length), v = c.first(.speed)
        let waveContext = f != nil || c.has(["파동", "파장", "진동수", "주기"])
        guard waveContext else { return nil }
        if c.asked("진동수") {
            if let v, let lambda, lambda.si > 0 {
                return out("진동수 구하기", formula: "f = v ÷ λ (속력 ÷ 파장)", given: [v, lambda],
                           sub: "f = \(fmt(v.si)) m/s ÷ \(fmt(lambda.si)) m", answer: "\(fmt(v.si / lambda.si)) Hz")
            }
            if let period = c.first(.time), period.si > 0 {
                return out("진동수 구하기", formula: "f = 1 ÷ T (주기)", given: [period],
                           sub: "f = 1 ÷ \(fmt(period.si)) s", answer: "\(fmt(1 / period.si)) Hz")
            }
        }
        if c.asked("파장"), let v, let f, f.si > 0 {
            return out("파장 구하기", formula: "λ = v ÷ f (속력 ÷ 진동수)", given: [v, f],
                       sub: "λ = \(fmt(v.si)) m/s ÷ \(fmt(f.si)) Hz", answer: "\(fmt(v.si / f.si)) m")
        }
        if c.asked("주기", notBefore: ["몇 "]), let f, f.si > 0 {
            return out("주기 구하기", formula: "T = 1 ÷ f", given: [f],
                       sub: "T = 1 ÷ \(fmt(f.si)) Hz", answer: "\(fmt(1 / f.si)) s")
        }
        if askedSpeed(c) || c.asked("전파 속력"), let f, let lambda {
            return out("파동의 속력 구하기", formula: "v = f × λ (진동수 × 파장)", given: [f, lambda],
                       sub: "v = \(fmt(f.si)) Hz × \(fmt(lambda.si)) m", answer: "\(fmt(f.si * lambda.si)) m/s")
        }
        return nil
    }

    private static let avogadro = 6.02e23

    private static func mole(_ c: SciContext) -> String? {
        let askMol = c.asked("몰", notAfter: ["질량", "농도", " 질량", " 농도", "질"]) || c.has(["몰수", "몰 수", "물질의 양"])
        let askParticles = c.askedAny(["분자 수", "분자수", "입자 수", "입자수", "원자 수", "원자수", "개수", "몇 개"])
        let askMass = c.asked("질량")
        let askVolume = c.asked("부피") && c.has(["기체", "0℃", "0 ℃", "표준", "STP"])
        guard askMol || askParticles || askMass || askVolume else { return nil }
        let substance = findSubstance(c.original)
        let molar = c.first(.molarMass)?.si ?? substance.map { molarMassOf($0.counts) }
        let name = substance.map { "\($0.name)(\(subscriptFormula($0.formula)))" } ?? "물질"
        let molarText = molar.map { "\(fmt($0)) g/mol" } ?? ""
        var moles: Double?
        var mainLine: String?
        if let n = c.first(.mole) { moles = n.si }
        else if let m = c.first(.mass), let molar, molar > 0 {
            moles = m.si * 1000 / molar
            mainLine = "\(fmt(m.si * 1000)) g ÷ \(molarText) = \(fmt(m.si * 1000 / molar)) mol"
        } else if let volume = c.first(.volume), c.has(["기체", "0℃", "0 ℃", "표준", "STP"]) || substance?.gas == true {
            moles = volume.si * 1000 / 22.4
            mainLine = "\(fmt(volume.si * 1000)) L ÷ 22.4 L/mol = \(fmt(volume.si * 1000 / 22.4)) mol"
        }
        if askParticles, let moles {
            let particles = moles * avogadro
            return out("입자 수 구하기", formula: "입자 수 = 몰 수 × 6.02×10²³", extra: mainLine.map { [$0] } ?? [],
                       sub: "\(fmt(moles)) mol × 6.02×10²³", answer: "\(fmt(particles))개")
        }
        if askMol, let mainLine, let moles {
            let isGas = c.first(.mass) == nil
            return out("몰 수 구하기", formula: isGas ? "몰 수 = 기체 부피 ÷ 22.4 L (0℃, 1기압)" : "몰 수 = 질량 ÷ 몰 질량",
                       extra: (isGas || molar == nil) ? [] : ["\(name)의 몰 질량 \(molarText)"],
                       sub: mainLine, answer: "\(fmt(moles)) mol")
        }
        if askMass, let n = c.first(.mole), let molar {
            return out("질량 구하기", formula: "질량 = 몰 수 × 몰 질량", extra: ["\(name)의 몰 질량 \(molarText)"],
                       sub: "\(fmt(n.si)) mol × \(molarText)", answer: "\(fmt(n.si * molar)) g")
        }
        if askVolume, let moles {
            return out("기체 부피 구하기", formula: "부피 = 몰 수 × 22.4 L (0℃, 1기압)",
                       sub: "\(fmt(moles)) mol × 22.4 L/mol", answer: "\(fmt(moles * 22.4)) L")
        }
        return nil
    }

    private static func concentration(_ c: SciContext) -> String? {
        let askMolarity = c.has(["몰 농도", "몰농도"])
        let askPercent = c.has(["퍼센트 농도", "% 농도", "%농도", "질량 백분율"]) || (c.asked("농도") && !askMolarity)
        let masses = c.all(.mass)
        if askMolarity || (c.asked("농도") && c.first(.volume) != nil && masses.count <= 1) {
            guard let volume = c.first(.volume), volume.si > 0 else { return nil }
            let liters = volume.si * 1000
            var moles: Double?
            var extra: [String] = []
            if let n = c.first(.mole) { moles = n.si }
            else if let m = c.first(.mass), let substance = findSubstance(c.original) {
                let molar = c.first(.molarMass)?.si ?? molarMassOf(substance.counts)
                moles = m.si * 1000 / molar
                extra.append("\(substance.name) \(fmt(m.si * 1000)) g ÷ \(fmt(molar)) g/mol = \(fmt(moles ?? 0)) mol")
            }
            guard let moles else { return nil }
            if volume.unit.show != "L" { extra.append("\(volume.shown) = \(fmt(liters)) L") }
            return out("몰 농도 구하기", formula: "몰 농도(M) = 용질의 몰 수 ÷ 용액의 부피(L)", extra: extra,
                       sub: "\(fmt(moles)) mol ÷ \(fmt(liters)) L", answer: "\(fmt(moles / liters)) M (mol/L)")
        }
        let percent = c.first(.percent)
        let askSolute = c.askedAny(["녹아 있는", "녹아있는", "들어 있는", "들어있는", "용질의 질량", "소금의 질량", "설탕의 질량",
                                    "소금의 양", "설탕의 양", "용질의 양"])
        if let percent, askSolute || c.asked("질량"), let solution = masses.first {
            let grams = solution.si * 1000
            return out("녹아 있는 용질의 질량", formula: "용질의 질량 = 용액의 질량 × 농도 ÷ 100",
                       sub: "\(fmt(grams)) g × \(fmt(percent.raw)) ÷ 100", answer: "\(fmt(grams * percent.raw / 100)) g")
        }
        guard askPercent, masses.count >= 2 else { return nil }
        let soluteWords = ["용질", "설탕", "소금", "녹인", "녹였", "포도당", "염화", "수산화", "황산구리"]
        let solutionWords = ["용액", "소금물", "설탕물", "수용액", "전체"]
        let solventWords = ["용매", "물"]
        let solutionQ = masses.first { q in solutionWords.contains { q.label.contains($0) } }
        let soluteQ = masses.first { q in q.start != solutionQ?.start && soluteWords.contains { q.label.contains($0) } }
            ?? masses.first { $0.start != solutionQ?.start }
        let solventQ = masses.first { q in q.start != soluteQ?.start && q.start != solutionQ?.start && solventWords.contains { q.label.contains($0) } }
        guard let soluteQ else { return nil }
        let solute = soluteQ.si * 1000
        var solution: Double
        var sub: String
        if let solutionQ {
            solution = solutionQ.si * 1000
            sub = "\(fmt(solute)) g ÷ \(fmt(solution)) g × 100"
        } else if let other = solventQ ?? masses.first(where: { $0.start != soluteQ.start }) {
            let solvent = other.si * 1000
            solution = solute + solvent
            sub = "\(fmt(solute)) g ÷ (\(fmt(solute)) g + \(fmt(solvent)) g) × 100"
        } else { return nil }
        guard solution > 0 else { return nil }
        return out("퍼센트 농도 구하기", formula: "퍼센트 농도(%) = 용질의 질량 ÷ 용액의 질량 × 100",
                   sub: sub, answer: "\(fmt(solute / solution * 100))%",
                   note: "용액의 질량 = 용질의 질량 + 용매의 질량이에요.")
    }

    /// 무엇을 구하는지 말하지 않았을 때: 주어진 값의 짝으로 짐작
    private static func generic(_ c: SciContext) -> String? {
        guard c.has(["구해", "얼마", "몇", "?", "계산", "은?", "는?"]) else { return nil }
        let dims = Set(c.quantities.map { "\($0.dim)" })
        guard c.quantities.count == 2 else { return nil }
        if dims == ["length", "time"], let d = c.first(.length), let t = c.first(.time), t.si > 0 {
            return out("속력 구하기", formula: "속력 = 이동 거리 ÷ 걸린 시간", given: [d, t],
                       sub: "\(fmt(d.si)) m ÷ \(fmt(t.si)) s", answer: "\(fmt(d.si / t.si)) m/s (약 \(fmt(d.si / t.si * 3.6)) km/h)")
        }
        if dims == ["mass", "volume"], let m = c.first(.mass), let v = c.first(.volume), v.si > 0 {
            return out("밀도 구하기", formula: "밀도 = 질량 ÷ 부피",
                       sub: "\(fmt(m.si * 1000)) g ÷ \(fmt(v.si * 1e6)) cm³", answer: "\(fmt(m.si * 1000 / (v.si * 1e6))) g/cm³")
        }
        if dims == ["mass", "accel"], let m = c.first(.mass), let a = c.first(.accel) {
            return out("힘 구하기", formula: "F = m × a", given: [m],
                       sub: "F = \(fmt(m.si)) kg × \(fmt(a.si)) m/s²", answer: "\(fmt(m.si * a.si)) N")
        }
        if dims == ["voltage", "resistance"], let v = c.first(.voltage), let r = c.first(.resistance), r.si > 0 {
            return out("전류 구하기 (옴의 법칙)", formula: "I = V ÷ R", given: [v, r],
                       sub: "I = \(fmt(v.si)) V ÷ \(fmt(r.si)) Ω", answer: "\(fmt(v.si / r.si)) A")
        }
        return nil
    }

    // MARK: - 단위 바꾸기

    private static let unitNames: [(String, String)] = [
        ("킬로칼로리", "kcal"), ("칼로리", "cal"), ("킬로미터", "km"), ("센티미터", "cm"), ("밀리미터", "mm"), ("미터", "m"),
        ("킬로그램", "kg"), ("밀리그램", "mg"), ("그램", "g"), ("밀리리터", "mL"), ("리터", "L"), ("켈빈", "K"), ("화씨", "℉"),
        ("섭씨", "℃"), ("시간", "시간"), ("초", "초")
    ]

    private static func conversion(_ c: SciContext) -> String? {
        guard c.has(["몇", "바꿔", "변환", "환산", "나타내", "단위", "로 하면", "으로 하면"]), let q = c.quantities.first else { return nil }
        guard q.end <= c.chars.count else { return nil }
        let after = String(c.chars[q.end...])
        var target: SciUnit?
        // 한글 단위 이름
        for (name, token) in unitNames where after.contains(name) {
            if token == "℃", q.unit.show == "℃" { continue }
            if let unit = units.first(where: { $0.token == token }) { target = unit; break }
        }
        if target == nil, q.dim == .temperature, after.contains("몇 도") || after.contains("몇도") {
            target = units.first { $0.token == "℃" }
        }
        if target == nil {
            let afterChars = Array(after)
            var best: (index: Int, unit: SciUnit)?
            for unit in units where unit.dim == q.dim {
                let tokenChars = Array(unit.token)
                guard afterChars.count >= tokenChars.count else { continue }
                for index in 0...(afterChars.count - tokenChars.count) where Array(afterChars[index..<index + tokenChars.count]) == tokenChars {
                    let previous: Character? = index > 0 ? afterChars[index - 1] : nil
                    let next: Character? = index + tokenChars.count < afterChars.count ? afterChars[index + tokenChars.count] : nil
                    if let previous, previous.isNumber || (previous.isASCII && previous.isLetter) || previous == "/" { continue }
                    if let next, next.isASCII, next.isLetter || next.isNumber || next == "/" { continue }
                    if best == nil || index < best!.index || (index == best!.index && unit.token.count > best!.unit.token.count) {
                        best = (index, unit)
                    }
                }
            }
            target = best?.unit
        }
        guard let target, target.dim == q.dim, target.show != q.unit.show else { return nil }
        if q.dim == .temperature {
            let celsius = q.si
            let value: Double
            switch target.show {
            case "K": value = celsius + 273.15
            case "℉": value = celsius * 9 / 5 + 32
            default: value = celsius
            }
            let rule: String
            switch (q.unit.show, target.show) {
            case ("℃", "K"): rule = "K = ℃ + 273 (정확히는 273.15)"
            case ("K", "℃"): rule = "℃ = K − 273 (정확히는 273.15)"
            case ("℃", "℉"): rule = "℉ = ℃ × 9/5 + 32"
            case ("℉", "℃"): rule = "℃ = (℉ − 32) × 5/9"
            default: rule = "섭씨 온도를 거쳐서 바꿨어요"
            }
            return "**온도 단위 바꾸기**\n\(q.shown) = \(fmt(value)) \(target.show)\n\(rule)"
        }
        let value = q.si / target.factor
        var lines = ["**단위 바꾸기**", "\(q.shown) = \(fmt(value)) \(target.show)"]
        if q.raw != 1 { lines.append("1 \(q.unit.show) = \(fmt(q.unit.factor / target.factor)) \(target.show)") }
        if q.dim == .energy, [q.unit.show, target.show].contains(where: { $0.contains("cal") }) {
            lines.append("1 cal ≈ 4.2 J로 계산했어요.")
        }
        if q.dim == .speed { lines.append("km/h를 m/s로 바꿀 때는 3.6으로 나누고, 반대는 3.6을 곱해요.") }
        return lines.joined(separator: "\n")
    }

    // MARK: - 주기율표

    fileprivate struct SciElement {
        let z: Int
        let symbol: String
        let name: String
        let aliases: [String]
        let mass: Double
        let group: Int
        let period: Int
        let kind: String
    }

    private static func el(_ z: Int, _ symbol: String, _ name: String, _ mass: Double, _ group: Int, _ period: Int,
                           _ kind: String, _ aliases: [String] = []) -> SciElement {
        SciElement(z: z, symbol: symbol, name: name, aliases: aliases, mass: mass, group: group, period: period, kind: kind)
    }

    private static let elements: [SciElement] = [
        el(1, "H", "수소", 1.008, 1, 1, "비금속"),
        el(2, "He", "헬륨", 4.003, 18, 1, "비활성 기체"),
        el(3, "Li", "리튬", 6.94, 1, 2, "금속 (알칼리 금속)"),
        el(4, "Be", "베릴륨", 9.012, 2, 2, "금속 (알칼리 토금속)"),
        el(5, "B", "붕소", 10.81, 13, 2, "준금속"),
        el(6, "C", "탄소", 12.011, 14, 2, "비금속"),
        el(7, "N", "질소", 14.007, 15, 2, "비금속"),
        el(8, "O", "산소", 15.999, 16, 2, "비금속"),
        el(9, "F", "플루오린", 18.998, 17, 2, "비금속 (할로젠)", ["불소"]),
        el(10, "Ne", "네온", 20.180, 18, 2, "비활성 기체"),
        el(11, "Na", "나트륨", 22.990, 1, 3, "금속 (알칼리 금속)", ["소듐"]),
        el(12, "Mg", "마그네슘", 24.305, 2, 3, "금속 (알칼리 토금속)"),
        el(13, "Al", "알루미늄", 26.982, 13, 3, "금속"),
        el(14, "Si", "규소", 28.085, 14, 3, "준금속", ["실리콘"]),
        el(15, "P", "인", 30.974, 15, 3, "비금속"),
        el(16, "S", "황", 32.06, 16, 3, "비금속"),
        el(17, "Cl", "염소", 35.45, 17, 3, "비금속 (할로젠)"),
        el(18, "Ar", "아르곤", 39.948, 18, 3, "비활성 기체"),
        el(19, "K", "칼륨", 39.098, 1, 4, "금속 (알칼리 금속)", ["포타슘"]),
        el(20, "Ca", "칼슘", 40.078, 2, 4, "금속 (알칼리 토금속)"),
        el(21, "Sc", "스칸듐", 44.956, 3, 4, "금속 (전이 금속)"),
        el(22, "Ti", "타이타늄", 47.867, 4, 4, "금속 (전이 금속)", ["티타늄"]),
        el(23, "V", "바나듐", 50.942, 5, 4, "금속 (전이 금속)"),
        el(24, "Cr", "크로뮴", 51.996, 6, 4, "금속 (전이 금속)", ["크롬"]),
        el(25, "Mn", "망가니즈", 54.938, 7, 4, "금속 (전이 금속)", ["망간"]),
        el(26, "Fe", "철", 55.845, 8, 4, "금속 (전이 금속)"),
        el(27, "Co", "코발트", 58.933, 9, 4, "금속 (전이 금속)"),
        el(28, "Ni", "니켈", 58.693, 10, 4, "금속 (전이 금속)"),
        el(29, "Cu", "구리", 63.546, 11, 4, "금속 (전이 금속)"),
        el(30, "Zn", "아연", 65.38, 12, 4, "금속 (전이 금속)"),
        el(31, "Ga", "갈륨", 69.723, 13, 4, "금속"),
        el(32, "Ge", "저마늄", 72.630, 14, 4, "준금속", ["게르마늄"]),
        el(33, "As", "비소", 74.922, 15, 4, "준금속"),
        el(34, "Se", "셀레늄", 78.971, 16, 4, "비금속"),
        el(35, "Br", "브로민", 79.904, 17, 4, "비금속 (할로젠)", ["브롬"]),
        el(36, "Kr", "크립톤", 83.798, 18, 4, "비활성 기체"),
        el(37, "Rb", "루비듐", 85.468, 1, 5, "금속 (알칼리 금속)"),
        el(38, "Sr", "스트론튬", 87.62, 2, 5, "금속 (알칼리 토금속)"),
        el(47, "Ag", "은", 107.87, 11, 5, "금속 (전이 금속)"),
        el(50, "Sn", "주석", 118.71, 14, 5, "금속"),
        el(53, "I", "아이오딘", 126.90, 17, 5, "비금속 (할로젠)", ["요오드"]),
        el(54, "Xe", "제논", 131.29, 18, 5, "비활성 기체", ["크세논"]),
        el(55, "Cs", "세슘", 132.91, 1, 6, "금속 (알칼리 금속)"),
        el(56, "Ba", "바륨", 137.33, 2, 6, "금속 (알칼리 토금속)"),
        el(78, "Pt", "백금", 195.08, 10, 6, "금속 (전이 금속)"),
        el(79, "Au", "금", 196.97, 11, 6, "금속 (전이 금속)"),
        el(80, "Hg", "수은", 200.59, 12, 6, "금속 (전이 금속, 상온에서 액체)"),
        el(82, "Pb", "납", 207.2, 14, 6, "금속"),
        el(86, "Rn", "라돈", 222, 18, 6, "비활성 기체 (방사성)"),
        el(92, "U", "우라늄", 238.03, 0, 7, "금속 (악티늄족, 방사성)")
    ]

    /// 교과서에서 흔히 쓰는 원자량 (정수 근사)
    private static func schoolMass(_ e: SciElement) -> Double {
        switch e.symbol {
        case "Cl": return 35.5
        case "Cu": return 63.5
        default: return e.mass.rounded()
        }
    }

    private static func elementBySymbol(_ symbol: String) -> SciElement? {
        elements.first { $0.symbol == symbol }
    }

    private static let elementKeys = ["원자번호", "원자 번호", "원소기호", "원소 기호", "원자량", "몇 족", "몇족", "몇 주기", "몇주기",
                                      "족 원소", "족이", "족인", "주기 원소", "원소", "전자 배치", "전자배치", "원자가 전자", "원자가전자",
                                      "양성자 수", "양성자수", "전자 수", "전자수", "전자 껍질", "금속이야", "금속인가", "금속이에요", "비금속"]

    private static func element(_ c: SciContext) -> String? {
        let t = c.original
        guard elementKeys.contains(where: t.contains) else { return nil }
        var found: SciElement?
        // 기호 (Na, Fe …)
        for word in t.split(whereSeparator: { !($0.isASCII && $0.isLetter) }) {
            if let e = elementBySymbol(String(word)) { found = e; break }
        }
        // 한글 이름
        if found == nil {
            let compact = norm(t)
            let words = Set(tokens(t))
            var best: (SciElement, Int)?
            for e in elements {
                for name in [e.name] + e.aliases {
                    let matched = name.count >= 2 ? compact.contains(name) : words.contains(name)
                    if matched, name.count > (best?.1 ?? 0) { best = (e, name.count) }
                }
            }
            found = best?.0
        }
        // 원자 번호
        if found == nil {
            let patterns = [#"원자\s*번호\s*(가|는|이)?\s*\d+"#, #"\d+\s*번\s*원소"#]
            for pattern in patterns {
                if let range = t.range(of: pattern, options: .regularExpression) {
                    let digits = t[range].filter(\.isNumber)
                    if let z = Int(digits) {
                        found = elements.first { $0.z == z }
                        if found == nil {
                            return "원자 번호 \(z)번 원소는 아직 두잇 AI 주기율표에 없어요. 1~38번과 자주 나오는 원소(은, 금, 수은, 납, 우라늄 등)를 알고 있어요."
                        }
                    }
                    break
                }
            }
        }
        guard let e = found else { return nil }
        var lines: [String] = []
        let compact = norm(t)
        if compact.contains("원소기호") {
            lines.append("**\(e.name)의 원소 기호: \(e.symbol)**")
        } else if compact.contains("원자번호") || compact.contains("양성자") || compact.contains("전자수") {
            lines.append("**\(e.name)(\(e.symbol))의 원자 번호: \(e.z)**")
            lines.append("중성 원자에서는 양성자 수 = 전자 수 = \(e.z)개예요.")
        } else if compact.contains("원자량") {
            lines.append("**\(e.name)(\(e.symbol))의 원자량: 약 \(fmt(e.mass))**")
            lines.append("계산 문제에서는 보통 \(fmt(schoolMass(e)))(으)로 써요.")
        } else if compact.contains("족") || compact.contains("주기") {
            lines.append("**\(e.name)(\(e.symbol)): \(e.period)주기" + (e.group > 0 ? " \(e.group)족**" : "**"))
        } else if compact.contains("전자배치") || compact.contains("원자가전자") || compact.contains("전자껍질") {
            lines.append("**\(e.name)(\(e.symbol))의 전자 배치**")
        } else {
            lines.append("**\(e.name) (\(e.symbol))**")
        }
        lines.append("원자 번호 \(e.z) · 원자량 약 \(fmt(e.mass))")
        lines.append("\(e.period)주기" + (e.group > 0 ? " \(e.group)족" : "") + " · \(e.kind)")
        if let config = electronConfig(e.z) { lines.append("전자 배치: \(config)") }
        if let valence = valenceElectrons(e) { lines.append("원자가 전자: \(valence)개") }
        return lines.joined(separator: "\n")
    }

    private static func valenceElectrons(_ e: SciElement) -> Int? {
        if e.group == 18 { return 0 }
        if e.group == 1 || e.group == 2 { return e.group }
        if (13...17).contains(e.group) { return e.group - 10 }
        return nil
    }

    /// 1s² 2s² 2p⁶ … (36번까지, 껍질 표기는 20번까지)
    private static func electronConfig(_ z: Int) -> String? {
        guard z <= 36 else { return nil }
        let order: [(String, Int)] = [("1s", 2), ("2s", 2), ("2p", 6), ("3s", 2), ("3p", 6), ("4s", 2), ("3d", 10), ("4p", 6)]
        var left = z
        var parts: [(String, Int)] = []
        for (name, capacity) in order where left > 0 {
            let n = min(capacity, left)
            parts.append((name, n))
            left -= n
        }
        // 예외: 크로뮴, 구리는 3d를 먼저 채움
        if z == 24 { parts = parts.filter { $0.0 != "4s" && $0.0 != "3d" } + [("3d", 5), ("4s", 1)] }
        if z == 29 { parts = parts.filter { $0.0 != "4s" && $0.0 != "3d" } + [("3d", 10), ("4s", 1)] }
        var text = parts.map { "\($0.0)\(superscript($0.1))" }.joined(separator: " ")
        if z <= 20 {
            let names = ["K", "L", "M", "N"]
            var shells: [Int] = []
            var remaining = z
            for capacity in [2, 8, 8, 2] where remaining > 0 {
                let n = min(capacity, remaining)
                shells.append(n)
                remaining -= n
            }
            text += " (" + shells.enumerated().map { "\(names[$0.offset]) \($0.element)" }.joined(separator: ", ") + ")"
        }
        return text
    }

    // MARK: - 화학식량 (몰 질량)

    fileprivate struct SciSubstance {
        let name: String
        let formula: String
        let counts: [(String, Int)]
        let gas: Bool
    }

    private static let substances: [(names: [String], formula: String, gas: Bool)] = [
        (["물"], "H2O", false), (["이산화 탄소", "이산화탄소"], "CO2", true), (["일산화 탄소", "일산화탄소"], "CO", true),
        (["산소 기체", "산소"], "O2", true), (["수소 기체", "수소"], "H2", true), (["질소 기체", "질소"], "N2", true),
        (["염소 기체"], "Cl2", true), (["메테인", "메탄"], "CH4", true), (["암모니아"], "NH3", true),
        (["염화 나트륨", "염화나트륨", "소금"], "NaCl", false), (["포도당"], "C6H12O6", false), (["설탕"], "C12H22O11", false),
        (["탄산 칼슘", "탄산칼슘"], "CaCO3", false), (["수산화 나트륨", "수산화나트륨"], "NaOH", false),
        (["염화 수소", "염화수소", "염산"], "HCl", false), (["황산"], "H2SO4", false), (["질산"], "HNO3", false),
        (["에탄올"], "C2H5OH", false), (["오존"], "O3", true), (["과산화 수소", "과산화수소"], "H2O2", false),
        (["탄산수소 나트륨", "탄산수소나트륨", "베이킹 소다"], "NaHCO3", false), (["산화 칼슘", "산화칼슘"], "CaO", false),
        (["수산화 칼슘", "수산화칼슘"], "Ca(OH)2", false), (["산화 구리", "산화구리"], "CuO", false),
        (["프로페인", "프로판"], "C3H8", true), (["아세트산", "초산"], "CH3COOH", false), (["이산화 황", "이산화황"], "SO2", true)
    ]

    private static let unitWords: Set<String> = ["N", "J", "V", "W", "A", "K", "M", "L", "Pa", "Hz", "Wh", "kWh", "mL", "STP"]

    private static func findSubstance(_ text: String) -> SciSubstance? {
        // 화학식 (H2SO4, Ca(OH)2, CuSO4·5H2O)
        let allowed = Set("ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789()[]·•.*")
        var token = ""
        var formulaTokens: [String] = []
        var previous: Character = " "
        var startsAfterDigit = false
        for ch in text + " " {
            if allowed.contains(ch) {
                if token.isEmpty { startsAfterDigit = previous.isNumber }
                token.append(ch)
            } else {
                if !token.isEmpty, !startsAfterDigit { formulaTokens.append(token) }
                token = ""
            }
            previous = ch
        }
        for raw in formulaTokens {
            var candidate = raw
            while candidate.hasSuffix(".") { candidate.removeLast() }
            guard let first = candidate.first, first.isUppercase || first == "(", !unitWords.contains(candidate) else { continue }
            if let counts = parseFormula(candidate) {
                let name = substances.first { $0.formula == candidate }?.names.first ?? candidate
                return SciSubstance(name: name, formula: candidate, counts: counts,
                                    gas: substances.first { $0.formula == candidate }?.gas ?? false)
            }
        }
        // 한글 이름
        let compact = norm(text)
        let words = Set(tokens(text))
        var best: (SciSubstance, Int)?
        for entry in substances {
            for name in entry.names {
                let key = norm(name)
                let matched = key.count >= 2 ? compact.contains(key) : words.contains(name)
                if matched, key.count > (best?.1 ?? 0), let counts = parseFormula(entry.formula) {
                    best = (SciSubstance(name: entry.names[0], formula: entry.formula, counts: counts, gas: entry.gas), key.count)
                }
            }
        }
        return best?.0
    }

    private static func parseFormula(_ formula: String) -> [(String, Int)]? {
        let parts = formula.split(whereSeparator: { "·•.*".contains($0) })
        guard !parts.isEmpty else { return nil }
        var total: [(String, Int)] = []
        for part in parts {
            let chars = Array(part)
            var i = 0
            var coefficient = 0
            while i < chars.count, chars[i].isNumber { coefficient = coefficient * 10 + (chars[i].wholeNumberValue ?? 0); i += 1 }
            if coefficient == 0 { coefficient = 1 }
            guard let group = parseGroup(chars, &i), i == chars.count, !group.isEmpty else { return nil }
            for (symbol, n) in group { merge(&total, symbol, n * coefficient) }
        }
        return total
    }

    private static func parseGroup(_ chars: [Character], _ i: inout Int) -> [(String, Int)]? {
        var result: [(String, Int)] = []
        while i < chars.count, chars[i] != ")", chars[i] != "]" {
            let ch = chars[i]
            if ch == "(" || ch == "[" {
                i += 1
                guard let inner = parseGroup(chars, &i), i < chars.count else { return nil }
                i += 1
                let n = readCount(chars, &i)
                for (symbol, count) in inner { merge(&result, symbol, count * n) }
            } else if ch.isUppercase, ch.isASCII {
                var symbol = String(ch)
                i += 1
                if i < chars.count, chars[i].isLowercase, chars[i].isASCII { symbol.append(chars[i]); i += 1 }
                guard elementBySymbol(symbol) != nil else { return nil }
                merge(&result, symbol, readCount(chars, &i))
            } else {
                return nil
            }
        }
        return result
    }

    private static func readCount(_ chars: [Character], _ i: inout Int) -> Int {
        var n = 0
        while i < chars.count, chars[i].isNumber, chars[i].isASCII { n = n * 10 + (chars[i].wholeNumberValue ?? 0); i += 1 }
        return n == 0 ? 1 : n
    }

    private static func merge(_ list: inout [(String, Int)], _ symbol: String, _ n: Int) {
        if let index = list.firstIndex(where: { $0.0 == symbol }) { list[index].1 += n } else { list.append((symbol, n)) }
    }

    /// school: 교과서 원자량(H=1, C=12, O=16, Cl=35.5 …)으로 계산 — 계산 문제의 답과 맞추기 위해
    private static func molarMassOf(_ counts: [(String, Int)], school: Bool = true) -> Double {
        counts.reduce(0) { total, item in
            guard let e = elementBySymbol(item.0) else { return total }
            return total + (school ? schoolMass(e) : e.mass) * Double(item.1)
        }
    }

    private static func molarMass(_ c: SciContext) -> String? {
        guard c.has(["화학식량", "분자량", "몰 질량", "몰질량", "화학식 량", "1몰의 질량", "1 몰의 질량", "식량은", "g/mol은", "g/mol이"]) else { return nil }
        guard !c.asked("몰", notAfter: ["질량", "농도", " 질량", " 농도", "질", "의 질량"]), c.first(.mass) == nil else { return nil }
        guard let substance = findSubstance(c.original) else { return nil }
        var lines = ["**\(substance.name == substance.formula ? subscriptFormula(substance.formula) : "\(substance.name)(\(subscriptFormula(substance.formula)))")의 화학식량 (몰 질량)**"]
        var total = 0.0
        var school = 0.0
        for (symbol, n) in substance.counts {
            guard let e = elementBySymbol(symbol) else { continue }
            let part = e.mass * Double(n)
            total += part
            school += schoolMass(e) * Double(n)
            lines.append("\(e.symbol)(\(e.name)) \(fmt(e.mass)) × \(n) = \(fmt(part))")
        }
        lines.append("**답: 약 \(fmt(total)) (1몰의 질량 \(fmt(total)) g, 몰 질량 \(fmt(total)) g/mol)**")
        let schoolValues = substance.counts.compactMap { elementBySymbol($0.0) }.map { "\($0.symbol)=\(fmt(schoolMass($0)))" }
        lines.append("교과서 원자량(\(schoolValues.joined(separator: ", ")))으로 계산하면: \(fmt(school))")
        return lines.joined(separator: "\n")
    }

    // MARK: - 개념 사전

    private struct SciConcept {
        let names: [String]
        let body: String
    }

    private static let askCues = ["뭐야", "뭔가요", "뭐예요", "뭐지", "뭔데", "무엇", "설명", "알려", "란", "정의", "개념", "의미", "뜻",
                                  "어떤", "궁금", "?", "가르쳐", "정리", "차이", "원리", "이유", "왜", "법칙"]

    /// 영어 약어(UN, GDP, pH 등)는 낱말 전체가 있을 때만 (abundant 속 "un" 같은 오인 방지)
    private static func latinSafe(_ key: String, _ text: String) -> Bool {
        guard key.allSatisfy({ $0.isASCII && $0.isLetter }) else { return true }
        let pattern = "(?<![A-Za-z])" + NSRegularExpression.escapedPattern(for: key) + "(?![A-Za-z])"
        return text.range(of: pattern, options: [.regularExpression, .caseInsensitive]) != nil
    }

    private static func concept(_ text: String) -> String? {
        let compact = norm(text)
        var best: (SciConcept, Int)?
        for item in concepts {
            for name in item.names {
                let key = norm(name)
                if key.count >= 2, compact.contains(key), latinSafe(key, text), key.count > (best?.1 ?? 0) { best = (item, key.count) }
            }
        }
        guard let (item, length) = best else { return nil }
        // 개념 이름만 말했거나, 묻는 말이 함께 있을 때만
        let isOnlyName = compact.count <= length + 2
        guard isOnlyName || askCues.contains(where: text.contains) else { return nil }
        return "**\(item.names[0])**\n\(item.body)"
    }

    private static let concepts: [SciConcept] = [
        SciConcept(names: ["광합성"], body: "식물이 엽록체에서 빛에너지를 이용해 이산화 탄소와 물로 포도당을 만들고 산소를 내보내는 과정이에요.\n식: 6CO₂ + 6H₂O → (빛, 엽록체) → C₆H₁₂O₆ + 6O₂\n빛의 세기, 이산화 탄소 농도, 온도가 광합성 속도에 영향을 줘요.\n암기 팁: 광합성은 에너지를 '저장', 세포 호흡은 에너지를 '꺼내 쓰기'예요."),
        SciConcept(names: ["세포 호흡", "세포호흡", "호흡"], body: "세포의 미토콘드리아에서 포도당을 산소로 분해해 생명 활동에 필요한 에너지(ATP)를 얻는 과정이에요.\n식: C₆H₁₂O₆ + 6O₂ → 6CO₂ + 6H₂O + 에너지\n광합성과 반대 방향의 반응이고, 낮과 밤 모두 일어나요."),
        SciConcept(names: ["뉴턴 운동 법칙", "뉴턴의 운동 법칙", "뉴턴 법칙", "운동 법칙"], body: "제1법칙(관성 법칙): 힘을 받지 않으면 정지한 물체는 계속 정지, 움직이는 물체는 등속 직선 운동을 해요.\n제2법칙(가속도 법칙): F = ma, 가속도는 힘에 비례하고 질량에 반비례해요.\n제3법칙(작용 반작용 법칙): A가 B를 밀면 B도 A를 같은 크기, 반대 방향으로 밀어요."),
        SciConcept(names: ["관성", "관성 법칙", "관성의 법칙", "뉴턴 제1법칙", "운동 제1법칙"], body: "물체가 원래의 운동 상태를 계속 유지하려는 성질이에요. 질량이 클수록 관성이 커요.\n예: 버스가 갑자기 출발하면 몸이 뒤로, 갑자기 멈추면 앞으로 쏠려요. 이불을 막대로 털면 먼지가 떨어지는 것도 관성 때문이에요."),
        SciConcept(names: ["가속도 법칙", "가속도의 법칙", "뉴턴 제2법칙", "운동 제2법칙"], body: "물체의 가속도는 작용한 알짜힘에 비례하고 질량에 반비례해요. 식으로 F = ma (힘 = 질량 × 가속도)예요.\n예: 같은 힘으로 밀면 빈 수레가 짐 실은 수레보다 빨리 속력이 빨라져요."),
        SciConcept(names: ["작용 반작용", "작용반작용", "작용 반작용 법칙", "뉴턴 제3법칙", "운동 제3법칙"], body: "두 물체가 서로 힘을 주고받을 때, 두 힘은 크기가 같고 방향이 반대이며 서로 다른 물체에 작용해요.\n예: 로켓이 가스를 뒤로 밀면 가스가 로켓을 앞으로 밀어요. 노를 저으면 물이 배를 앞으로 밀어요.\n주의: 힘의 평형은 '한 물체'에 작용하는 두 힘이라 작용 반작용과 달라요."),
        SciConcept(names: ["힘의 평형", "평형"], body: "한 물체에 여러 힘이 작용하는데 알짜힘이 0인 상태예요. 이때 물체는 정지해 있거나 등속 직선 운동을 해요.\n예: 줄다리기에서 양쪽이 같은 힘으로 당기면 줄이 움직이지 않아요."),
        SciConcept(names: ["역학적 에너지 보존", "역학적 에너지"], body: "역학적 에너지는 운동 에너지와 위치 에너지의 합이에요. 마찰이나 공기 저항이 없으면 그 합은 항상 일정하게 보존돼요.\n예: 떨어지는 공은 위치 에너지가 줄어든 만큼 운동 에너지가 늘어나요."),
        SciConcept(names: ["에너지 보존 법칙", "에너지 보존", "에너지 전환"], body: "에너지는 새로 생기거나 없어지지 않고 한 형태에서 다른 형태로 바뀔 뿐, 전체 양은 일정해요.\n예: 전등은 전기 에너지를 빛에너지와 열에너지로, 발전기는 운동 에너지를 전기 에너지로 바꿔요."),
        SciConcept(names: ["운동 에너지", "운동에너지"], body: "움직이는 물체가 가진 에너지로, Eₖ = ½mv²이에요. 질량에 비례하고 속력의 제곱에 비례해요.\n예: 속력이 2배가 되면 운동 에너지는 4배가 돼요."),
        SciConcept(names: ["위치 에너지", "위치에너지"], body: "높은 곳에 있는 물체가 가진 에너지로, 중력에 의한 위치 에너지는 Eₚ = 9.8mh (질량 × 9.8 × 높이)예요.\n기준면을 어디로 잡느냐에 따라 값이 달라져요."),
        SciConcept(names: ["일률"], body: "1초 동안 하는 일의 양이에요. 일률 = 일 ÷ 시간이고 단위는 W(와트, J/s)예요.\n예: 같은 일을 더 짧은 시간에 하면 일률이 커요."),
        SciConcept(names: ["자유 낙하", "자유낙하"], body: "공기 저항 없이 중력만 받아 떨어지는 운동이에요. 속력이 1초마다 9.8 m/s씩 빨라져요(중력 가속도 9.8 m/s²).\n질량과 상관없이 같은 높이에서 동시에 떨어뜨리면 동시에 땅에 닿아요(진공에서)."),
        SciConcept(names: ["만유인력", "만유인력 법칙", "중력"], body: "질량을 가진 모든 물체 사이에 서로 끌어당기는 힘이에요. 두 물체 질량의 곱에 비례하고 거리의 제곱에 반비례해요.\n지구가 물체를 당기는 힘이 중력(무게)이고, 달이 지구 둘레를 도는 것도 만유인력 때문이에요."),
        SciConcept(names: ["마찰력"], body: "접촉한 면에서 물체의 운동을 방해하는 힘이에요. 면이 거칠수록, 물체가 무거울수록 커져요.\n예: 운동화 바닥 무늬는 마찰력을 크게, 자전거 체인 기름칠은 마찰력을 작게 해요."),
        SciConcept(names: ["전자기 유도", "전자기유도"], body: "코일 속을 지나는 자기장이 변할 때 코일에 전류(유도 전류)가 흐르는 현상이에요. 자석을 빠르게 움직일수록, 코일을 많이 감을수록 전류가 세져요.\n예: 발전기, 교통 카드, 무선 충전기, 인덕션."),
        SciConcept(names: ["옴의 법칙"], body: "도선에 흐르는 전류는 전압에 비례하고 저항에 반비례해요. 식으로 V = IR (전압 = 전류 × 저항)이에요.\n예: 전압 12V에 저항 4Ω이면 전류는 3A예요."),
        SciConcept(names: ["직렬 연결", "직렬", "병렬 연결", "병렬"], body: "직렬 연결: 전류가 한 길로 흘러 각 저항의 전류가 같고, 전압은 나뉘며 합성 저항 R = R₁ + R₂예요.\n병렬 연결: 각 저항에 걸리는 전압이 같고, 전류는 나뉘며 1/R = 1/R₁ + 1/R₂예요.\n집의 전기 기구는 하나가 꺼져도 다른 것이 켜지도록 병렬로 연결해요."),
        SciConcept(names: ["자기장"], body: "자석이나 전류 주위에 자기력이 작용하는 공간이에요. 자기장의 방향은 나침반 N극이 가리키는 방향(N극 → S극)이에요.\n직선 도선 주위의 자기장 방향은 오른손 엄지를 전류 방향으로 했을 때 나머지 네 손가락이 감기는 방향이에요."),
        SciConcept(names: ["정전기", "대전 현상"], body: "서로 다른 두 물체를 문지르면 전자가 한쪽으로 이동해 전기를 띠게 되는데, 이를 대전이라 하고 이때 생긴 전기를 정전기라고 해요.\n전자를 잃은 물체는 (+), 얻은 물체는 (−) 전하를 띠어요. 같은 전하끼리는 밀고 다른 전하끼리는 당겨요."),
        SciConcept(names: ["산화 환원", "산화환원", "산화", "환원"], body: "산화: 물질이 산소를 얻거나 전자를 잃는 반응. 환원: 산소를 잃거나 전자를 얻는 반응이에요.\n산화와 환원은 항상 동시에 일어나요.\n예: 철이 녹스는 것, 광합성과 세포 호흡, 철광석을 제련해 철을 얻는 것."),
        SciConcept(names: ["산과 염기", "산 염기", "산염기", "염기"], body: "산: 물에 녹아 수소 이온(H⁺)을 내놓는 물질로 신맛이 나고, 푸른 리트머스 종이를 붉게 바꾸며 금속과 반응해 수소 기체를 내요. (예: 염산, 식초)\n염기: 물에 녹아 수산화 이온(OH⁻)을 내놓는 물질로 쓴맛, 미끈거림이 있고 붉은 리트머스 종이를 푸르게, 페놀프탈레인 용액을 붉게 바꿔요. (예: 수산화 나트륨, 비눗물)"),
        SciConcept(names: ["중화 반응", "중화반응", "중화열"], body: "산과 염기가 반응해 물과 염이 생기는 반응이에요. 핵심은 H⁺ + OH⁻ → H₂O이고, 이때 열(중화열)이 나요.\n예: 위산이 많을 때 제산제 먹기, 벌레 물린 곳에 암모니아수 바르기, 산성화된 토양에 석회 뿌리기."),
        SciConcept(names: ["pH", "수소 이온 농도", "피에이치"], body: "용액의 산성·염기성 정도를 0~14로 나타낸 값이에요. 7은 중성, 7보다 작으면 산성, 크면 염기성이에요.\npH가 1 작아지면 수소 이온 농도는 10배 커져요. (예: 레몬즙 약 2, 순수한 물 7, 비눗물 약 10)"),
        SciConcept(names: ["지시약"], body: "용액의 액성(산성·중성·염기성)에 따라 색이 변하는 물질이에요.\n리트머스: 산성 → 붉은색, 염기성 → 푸른색. 페놀프탈레인: 염기성에서만 붉은색. BTB: 산성 노랑, 중성 초록, 염기성 파랑."),
        SciConcept(names: ["이온 결합"], body: "금속 원자가 전자를 잃어 생긴 양이온과 비금속 원자가 전자를 얻어 생긴 음이온이 정전기적 인력으로 결합한 것이에요.\n예: 염화 나트륨(NaCl). 고체일 때는 전기가 통하지 않지만, 녹이거나 물에 녹이면 전기가 통해요."),
        SciConcept(names: ["공유 결합"], body: "비금속 원자끼리 전자쌍을 함께 나누어 가지며 이루는 결합이에요.\n예: 물(H₂O), 이산화 탄소(CO₂), 산소(O₂), 메테인(CH₄). 대부분 녹는점이 낮고 전기가 잘 통하지 않아요."),
        SciConcept(names: ["금속 결합"], body: "금속 양이온과 자유롭게 움직이는 자유 전자 사이의 인력으로 이루어진 결합이에요.\n자유 전자 덕분에 전기와 열이 잘 통하고, 두드리면 얇게 펴지고(전성) 길게 늘어나요(연성)."),
        SciConcept(names: ["원자 구조", "원자의 구조", "원자"], body: "원자는 가운데 (+)전하를 띤 원자핵과 그 주위의 (−)전하를 띤 전자로 이루어져 있어요. 원자핵은 양성자와 중성자로 되어 있어요.\n원자 번호 = 양성자 수, 질량수 = 양성자 수 + 중성자 수예요. 중성 원자는 양성자 수와 전자 수가 같아요."),
        SciConcept(names: ["이온"], body: "원자가 전자를 잃거나 얻어서 전하를 띠게 된 입자예요. 전자를 잃으면 양이온(예: Na⁺), 얻으면 음이온(예: Cl⁻)이 돼요.\n금속 원소는 양이온, 비금속 원소는 음이온이 되기 쉬워요."),
        SciConcept(names: ["동위 원소", "동위원소"], body: "양성자 수는 같지만 중성자 수가 달라 질량수가 다른 원소예요. 화학적 성질은 거의 같아요.\n예: 수소(¹H), 중수소(²H), 삼중수소(³H). 탄소-14는 유물의 나이를 알아내는 연대 측정에 쓰여요."),
        SciConcept(names: ["주기율표", "주기율"], body: "원소를 원자 번호 순서로 배열하고 성질이 비슷한 원소가 같은 세로줄에 오도록 만든 표예요.\n가로줄(주기)은 전자 껍질 수가 같고, 세로줄(족)은 원자가 전자 수가 같아 화학적 성질이 비슷해요.\n예: 1족 알칼리 금속(Li, Na, K), 17족 할로젠(F, Cl, Br), 18족 비활성 기체(He, Ne, Ar)."),
        SciConcept(names: ["알칼리 금속"], body: "주기율표 1족의 금속 원소(리튬, 나트륨, 칼륨 등)예요. 원자가 전자가 1개라 +1가 양이온이 되기 쉽고, 물과 격렬하게 반응해 수소를 내요.\n칼로 자를 수 있을 만큼 무르고, 공기와 잘 반응해서 석유 속에 보관해요."),
        SciConcept(names: ["할로젠", "할로겐"], body: "주기율표 17족의 비금속 원소(플루오린, 염소, 브로민, 아이오딘)예요. 원자가 전자가 7개라 전자 1개를 얻어 −1가 음이온이 되기 쉬워요.\n반응성이 크고 금속과 잘 반응해 염을 만들어요."),
        SciConcept(names: ["비활성 기체"], body: "주기율표 18족 원소(헬륨, 네온, 아르곤 등)예요. 가장 바깥 전자 껍질이 안정해서 다른 원소와 거의 반응하지 않아요.\n예: 헬륨은 비행선, 네온은 광고 조명, 아르곤은 전구 속 기체로 쓰여요."),
        SciConcept(names: ["몰", "몰이란", "몰이 뭐", "몰 개념", "아보가드로수", "아보가드로 수"], body: "입자 6.02×10²³개를 한 묶음으로 나타낸 단위예요(아보가드로수).\n물질 1몰의 질량은 화학식량에 g을 붙인 값이고(예: 물 1몰 = 18 g), 0℃ 1기압에서 기체 1몰의 부피는 22.4 L예요."),
        SciConcept(names: ["질량 보존 법칙", "질량 보존"], body: "화학 반응이 일어나도 반응 전 물질의 총질량과 반응 후 물질의 총질량은 같아요(라부아지에).\n원자는 없어지거나 새로 생기지 않고 배열만 바뀌기 때문이에요. 기체가 빠져나가는 열린 용기에서는 질량이 줄어든 것처럼 보여요."),
        SciConcept(names: ["일정 성분비 법칙", "일정 성분비"], body: "화합물을 이루는 성분 원소의 질량비는 항상 일정해요(프루스트).\n예: 물에서 수소와 산소의 질량비는 언제나 1 : 8이에요."),
        SciConcept(names: ["보일 법칙", "보일의 법칙"], body: "온도가 일정할 때 기체의 부피는 압력에 반비례해요(PV = 일정).\n예: 높은 산에 올라가면 과자 봉지가 부풀어요. 잠수부가 내뿜은 공기 방울은 위로 올라갈수록 커져요."),
        SciConcept(names: ["샤를 법칙", "샤를의 법칙"], body: "압력이 일정할 때 기체의 부피는 절대 온도에 비례해요. 온도가 1℃ 올라갈 때마다 0℃ 부피의 1/273씩 늘어나요.\n예: 찌그러진 탁구공을 뜨거운 물에 넣으면 펴져요. 여름에 자동차 타이어가 팽팽해져요."),
        SciConcept(names: ["상태 변화"], body: "물질이 고체·액체·기체 사이에서 상태가 바뀌는 현상이에요. 융해(고→액), 응고(액→고), 기화(액→기), 액화(기→액), 승화(고↔기)가 있어요.\n융해·기화·승화(고→기)는 열을 흡수하고, 응고·액화·승화(기→고)는 열을 방출해요.\n상태가 변해도 물질의 종류와 질량은 변하지 않아요."),
        SciConcept(names: ["확산"], body: "분자가 스스로 운동해서 농도가 높은 곳에서 낮은 곳으로 퍼져 나가는 현상이에요.\n예: 향수 냄새가 방 안에 퍼지는 것, 폐포와 모세 혈관 사이에서 산소와 이산화 탄소가 교환되는 것."),
        SciConcept(names: ["삼투", "삼투 현상", "삼투압"], body: "반투과성 막을 사이에 두고 물이 용질의 농도가 낮은 쪽에서 높은 쪽으로 이동하는 현상이에요.\n예: 배추를 소금에 절이면 숨이 죽어요. 적혈구를 증류수에 넣으면 물이 들어가 터져요."),
        SciConcept(names: ["세포"], body: "생물을 이루는 기본 단위예요. 핵(유전 물질), 세포막(물질 출입 조절), 세포질, 미토콘드리아(세포 호흡)를 공통으로 가져요.\n식물 세포에는 엽록체(광합성)와 세포벽이 더 있어요."),
        SciConcept(names: ["DNA", "디엔에이"], body: "유전 정보를 저장하는 물질로, 두 가닥이 꼬인 이중 나선 구조예요. 뉴클레오타이드(인산 + 당 + 염기)가 길게 이어져 있어요.\n염기는 A, T, G, C 네 가지이고 A는 T와, G는 C와 짝을 이뤄요(상보적 결합)."),
        SciConcept(names: ["유전자"], body: "DNA 중에서 특정 형질(유전 정보)을 결정하는 부분이에요. 유전자에 담긴 정보에 따라 단백질이 만들어지고 형질이 나타나요.\n예: 눈꺼풀 모양, 혈액형을 결정하는 유전자."),
        SciConcept(names: ["염색체"], body: "DNA와 단백질이 뭉쳐서 만들어진 구조로, 세포가 분열할 때 막대 모양으로 보여요.\n사람의 체세포에는 46개(23쌍)가 있고, 22쌍의 상염색체와 1쌍의 성염색체(여자 XX, 남자 XY)로 이루어져요."),
        SciConcept(names: ["체세포 분열", "체세포분열"], body: "몸을 이루는 세포가 늘어나는 분열로, 한 번 분열해서 딸세포 2개가 생겨요. 염색체 수가 모세포와 같아요.\n생장(키가 크는 것)과 상처 재생에 필요해요. 단계: 간기 → 전기 → 중기 → 후기 → 말기."),
        SciConcept(names: ["감수 분열", "감수분열", "생식세포 분열"], body: "생식세포(정자, 난자)를 만드는 분열로, 연속 두 번 분열해서 딸세포 4개가 생겨요. 염색체 수가 모세포의 절반이 돼요.\n제1분열에서 상동 염색체가 분리돼요. 덕분에 수정 후에도 자손의 염색체 수가 일정하게 유지돼요."),
        SciConcept(names: ["멘델 법칙", "멘델의 법칙", "멘델 유전 법칙", "우열의 법칙", "분리의 법칙", "독립의 법칙"], body: "우열의 법칙: 대립 형질을 가진 순종끼리 교배하면 잡종 1대에는 우성 형질만 나타나요.\n분리의 법칙: 잡종 1대를 자가 교배하면 잡종 2대에서 우성 : 열성 = 3 : 1로 나타나요.\n독립의 법칙: 두 쌍 이상의 형질은 서로 영향 없이 독립적으로 유전돼요(잡종 2대 9 : 3 : 3 : 1)."),
        SciConcept(names: ["효소"], body: "생물체 안에서 화학 반응을 빠르게 해 주는 생체 촉매로, 주성분은 단백질이에요. 활성화 에너지를 낮춰 반응을 쉽게 만들어요.\n한 효소는 특정 물질에만 작용하고(기질 특이성), 알맞은 온도와 pH가 있어요. 예: 침의 아밀레이스(녹말 분해), 위의 펩신(단백질 분해)."),
        SciConcept(names: ["항상성"], body: "몸 밖 환경이 바뀌어도 체온, 혈당량, 체내 수분량 등을 일정하게 유지하려는 성질이에요. 신경계와 호르몬이 함께 조절해요.\n예: 혈당이 높으면 인슐린이 혈당을 낮추고, 낮으면 글루카곤이 혈당을 높여요. 더우면 땀을 흘려 체온을 낮춰요."),
        SciConcept(names: ["호르몬"], body: "내분비샘에서 만들어져 혈액을 따라 이동하며 특정 기관에 작용하는 화학 물질이에요. 적은 양으로 효과가 크고 신경보다 느리지만 오래 작용해요.\n예: 인슐린(혈당 낮춤), 글루카곤(혈당 높임), 티록신(물질대사 촉진), 생장 호르몬."),
        SciConcept(names: ["혈액 순환", "온몸 순환", "폐순환", "체순환"], body: "온몸 순환(체순환): 좌심실 → 대동맥 → 온몸의 모세 혈관 → 대정맥 → 우심방. 산소와 영양소를 온몸에 전달해요.\n폐순환: 우심실 → 폐동맥 → 폐의 모세 혈관 → 폐정맥 → 좌심방. 폐에서 이산화 탄소를 내보내고 산소를 받아요."),
        SciConcept(names: ["뉴런", "신경 세포"], body: "신경계를 이루는 기본 단위로, 자극을 전달해요. 감각 뉴런 → 연합 뉴런(뇌·척수) → 운동 뉴런 순서로 신호가 전달돼요.\n뜨거운 것에 손이 닿았을 때 바로 손을 떼는 무조건 반사는 척수가 중추예요."),
        SciConcept(names: ["면역", "백신"], body: "몸에 침입한 병원체를 막고 없애는 방어 작용이에요. 피부·점막 같은 1차 방어와, 특정 항원에 항체를 만드는 특이적 면역이 있어요.\n백신은 약하게 만든 병원체(항원)를 미리 넣어 기억 세포를 만들어 두는 원리예요."),
        SciConcept(names: ["생태계"], body: "생물(생산자·소비자·분해자)과 그를 둘러싼 비생물 환경(빛, 온도, 물, 공기, 토양)이 서로 영향을 주고받는 체계예요.\n생산자는 광합성으로 양분을 만들고, 소비자는 다른 생물을 먹고, 분해자(세균, 곰팡이)는 죽은 생물을 분해해요."),
        SciConcept(names: ["먹이 사슬", "먹이사슬", "먹이 그물", "먹이그물", "생태 피라미드", "에너지 피라미드"], body: "생물 사이의 먹고 먹히는 관계를 사슬처럼 나타낸 것이 먹이 사슬, 여러 먹이 사슬이 그물처럼 얽힌 것이 먹이 그물이에요.\n위 단계로 갈수록 전달되는 에너지가 줄어서(대략 10% 정도) 생물의 수와 에너지양이 피라미드 모양이 돼요.\n먹이 그물이 복잡할수록 생태계가 안정적이에요."),
        SciConcept(names: ["생물 다양성", "생물다양성"], body: "일정한 지역에 사는 생물의 다양한 정도로 유전적 다양성, 종 다양성, 생태계 다양성을 모두 포함해요.\n서식지 파괴, 외래종 유입, 남획, 환경 오염이 생물 다양성을 줄여요."),
        SciConcept(names: ["자연 선택", "자연선택", "진화"], body: "같은 종이라도 개체마다 변이가 있고, 환경에 잘 적응한 개체가 더 많이 살아남아 자손을 남기는 과정이에요(다윈).\n이것이 오랜 시간 쌓이면 생물이 진화해요. 예: 항생제를 계속 쓰면 내성 세균이 늘어나요."),
        SciConcept(names: ["판 구조론", "판구조론", "판의 이동"], body: "지구의 겉 부분(암석권)은 여러 개의 판으로 나뉘어 있고, 맨틀 대류에 의해 판이 조금씩 움직인다는 이론이에요.\n판의 경계에서 지진과 화산이 자주 일어나요. 발산형(해령), 수렴형(해구, 습곡 산맥), 보존형(변환 단층) 경계가 있어요."),
        SciConcept(names: ["대륙 이동설", "대륙이동설", "판게아"], body: "베게너가 주장한 이론으로, 과거에 하나였던 초대륙 판게아가 갈라져 지금의 대륙이 되었다는 내용이에요.\n증거: 해안선 모양의 일치, 같은 화석 분포, 빙하 흔적, 지질 구조 연결. 당시에는 원동력을 설명하지 못했지만 판 구조론으로 이어졌어요."),
        SciConcept(names: ["지진"], body: "지구 내부에 쌓인 에너지가 갑자기 방출되며 땅이 흔들리는 현상으로, 주로 판의 경계에서 일어나요.\n규모는 지진 자체의 에너지(한 지진에 하나의 값), 진도는 장소마다 느끼는 흔들림 정도예요. 지진파는 P파(빠름, 고체·액체·기체 통과)와 S파(느림, 고체만 통과)가 있어요."),
        SciConcept(names: ["지구 온난화", "온난화"], body: "온실 기체(이산화 탄소, 메테인 등)가 늘어나 온실 효과가 강해지면서 지구의 평균 기온이 올라가는 현상이에요.\n결과: 빙하가 녹아 해수면 상승, 폭염·가뭄·홍수 같은 이상 기후, 생태계 변화.\n대책: 화석 연료 사용 줄이기, 신재생 에너지 쓰기, 숲 가꾸기."),
        SciConcept(names: ["온실 효과", "온실효과", "온실 기체", "온실가스"], body: "대기 중 온실 기체가 지표에서 나오는 적외선(지구 복사 에너지)을 흡수했다가 다시 지표로 내보내 지구를 따뜻하게 하는 현상이에요.\n온실 효과 자체는 생물이 살기에 알맞은 온도를 유지해 주지만, 온실 기체가 너무 많아지면 지구 온난화가 생겨요."),
        SciConcept(names: ["엘니뇨", "라니냐"], body: "엘니뇨: 무역풍이 약해져 동태평양 적도 부근의 바닷물 온도가 평소보다 높아지는 현상이에요. 페루 쪽에는 홍수, 인도네시아·호주 쪽에는 가뭄이 생기기 쉬워요.\n라니냐: 무역풍이 강해져 동태평양 바닷물 온도가 평소보다 낮아지는 현상으로, 엘니뇨와 반대예요."),
        SciConcept(names: ["대기권", "대기의 층"], body: "지표에서부터 대류권 → 성층권 → 중간권 → 열권으로 나뉘어요.\n대류권: 기상 현상이 일어나고 높이 올라갈수록 기온이 낮아져요. 성층권: 오존층이 자외선을 흡수해 위로 갈수록 기온이 올라가요. 열권: 오로라가 나타나요."),
        SciConcept(names: ["지구계", "지구 시스템"], body: "지구를 이루는 기권(대기), 수권(물), 지권(땅), 생물권(생물), 외권(우주 공간)이 서로 물질과 에너지를 주고받는 하나의 시스템이에요.\n예: 화산 폭발(지권)이 화산재를 대기(기권)로 내보내 기온을 낮추기도 해요."),
        SciConcept(names: ["빅뱅", "빅뱅 우주론", "대폭발 우주론"], body: "약 138억 년 전 매우 뜨겁고 밀도가 높은 한 점에서 우주가 팽창하기 시작했다는 이론이에요.\n증거: 멀리 있는 은하일수록 빠르게 멀어짐(허블 법칙), 우주 배경 복사, 우주 전체의 수소와 헬륨 질량비 약 3 : 1."),
        SciConcept(names: ["별의 진화", "별의 일생"], body: "성운 → 원시별 → 주계열성(중심에서 수소 핵융합) → 적색 거성(또는 초거성) 순서로 변해요.\n태양 정도의 별은 행성상 성운을 남기고 백색 왜성이 되고, 매우 무거운 별은 초신성 폭발 후 중성자별이나 블랙홀이 돼요.\n무거운 원소는 별의 내부와 초신성 폭발에서 만들어졌어요."),
        SciConcept(names: ["핵융합"], body: "가벼운 원자핵 여러 개가 합쳐져 무거운 원자핵이 되면서 큰 에너지를 내는 반응이에요. 줄어든 질량만큼 에너지가 나와요(E = mc²).\n예: 태양 중심에서 수소 원자핵이 헬륨 원자핵으로 바뀌며 빛과 열을 내요."),
        SciConcept(names: ["핵분열"], body: "우라늄-235처럼 무거운 원자핵이 중성자를 흡수한 뒤 가벼운 원자핵 두 개로 쪼개지면서 큰 에너지와 중성자를 내는 반응이에요.\n원자력 발전은 핵분열의 연쇄 반응을 조절해서 전기를 만들어요. 방사성 폐기물 처리가 과제예요."),
        SciConcept(names: ["열의 이동", "열 전달", "열의 전달", "전도 대류 복사"], body: "전도: 물체를 이루는 입자의 운동이 이웃 입자로 전달되는 방식(예: 뜨거운 국 속 숟가락).\n대류: 액체나 기체가 직접 움직이며 열을 옮기는 방식(예: 에어컨은 위에, 난로는 아래에).\n복사: 물질을 거치지 않고 열이 직접 이동하는 방식(예: 햇볕, 모닥불 앞의 따뜻함)."),
        SciConcept(names: ["비열"], body: "어떤 물질 1 g의 온도를 1℃ 높이는 데 필요한 열량이에요. 물의 비열은 1 cal/(g·℃)(≈ 4.2 J/(g·℃))로 매우 커요.\n비열이 클수록 온도가 잘 변하지 않아요. 예: 해안 지역은 내륙보다 기온 변화가 작고, 해륙풍이 불어요."),
        SciConcept(names: ["열평형"], body: "온도가 다른 두 물체가 접촉하면 열이 높은 온도에서 낮은 온도로 이동해 결국 온도가 같아지는 상태예요.\n고온 물체가 잃은 열량 = 저온 물체가 얻은 열량이에요(열량 보존)."),
        SciConcept(names: ["파동"], body: "한 곳에서 생긴 진동이 주위로 퍼져 나가는 현상이에요. 매질은 제자리에서 진동할 뿐 함께 이동하지 않고 에너지만 전달돼요.\n횡파(진동 방향 ⊥ 진행 방향, 예: 빛, 지진의 S파)와 종파(진동 방향 ∥ 진행 방향, 예: 소리, P파)가 있어요.\n파동의 속력 = 진동수 × 파장이에요."),
        SciConcept(names: ["소리의 3요소", "소리의 성질", "음파"], body: "소리는 공기 같은 매질을 통해 전달되는 종파예요(진공에서는 전달되지 않아요).\n소리의 3요소: 크기(진폭이 클수록 큼), 높낮이(진동수가 클수록 높음), 맵시(파형에 따라 다름)."),
        SciConcept(names: ["빛의 굴절", "굴절"], body: "빛이 서로 다른 물질의 경계를 지날 때 속력이 달라져 진행 방향이 꺾이는 현상이에요.\n예: 물속의 다리가 짧아 보이는 것, 컵 속 빨대가 꺾여 보이는 것, 볼록 렌즈로 빛 모으기."),
        SciConcept(names: ["전반사"], body: "빛이 굴절률이 큰 물질에서 작은 물질로 갈 때, 입사각이 임계각보다 크면 빛이 모두 반사되는 현상이에요.\n예: 광섬유(인터넷 통신, 내시경), 다이아몬드의 반짝임."),
        SciConcept(names: ["빛의 합성", "빛의 삼원색", "삼원색"], body: "빛의 삼원색은 빨강(R), 초록(G), 파랑(B)이에요. 빨강 + 초록 = 노랑, 초록 + 파랑 = 청록, 파랑 + 빨강 = 자홍, 세 빛을 모두 합치면 흰색이에요.\n텔레비전과 스마트폰 화면은 이 세 빛으로 여러 색을 만들어요."),
        SciConcept(names: ["전해질"], body: "물에 녹았을 때 이온으로 나뉘어 전류가 흐르게 하는 물질이에요. 예: 염화 나트륨, 염산, 수산화 나트륨.\n설탕이나 에탄올처럼 물에 녹아도 이온으로 나뉘지 않아 전류가 흐르지 않는 물질은 비전해질이에요."),
        SciConcept(names: ["순물질", "혼합물", "순물질과 혼합물"], body: "순물질: 한 가지 물질로만 이루어져 녹는점·끓는점·밀도가 일정해요(예: 물, 금, 산소).\n혼합물: 두 가지 이상의 물질이 섞인 것으로 섞인 비율에 따라 성질이 달라요(예: 소금물, 공기, 우유). 끓는점·밀도·용해도 차이로 분리할 수 있어요."),
        SciConcept(names: ["용해도"], body: "일정한 온도에서 용매 100 g에 최대로 녹을 수 있는 용질의 g 수예요.\n고체의 용해도는 대체로 온도가 높을수록 커지고, 기체의 용해도는 온도가 낮고 압력이 높을수록 커요(예: 탄산음료는 차갑게 보관)."),
        SciConcept(names: ["신재생 에너지", "재생 에너지", "신재생에너지"], body: "고갈되지 않고 환경 오염이 적은 에너지로 태양광, 태양열, 풍력, 수력, 지열, 조력, 바이오 에너지, 수소·연료 전지 등이 있어요.\n날씨나 지역의 영향을 받고 설치 비용이 드는 것이 단점이에요."),
        SciConcept(names: ["반도체"], body: "도체와 부도체의 중간 정도로 전기가 통하는 물질로, 대표적으로 규소(Si)와 저마늄(Ge)이 있어요.\n불순물을 넣어 p형·n형 반도체를 만들고, 이를 이용해 다이오드(한 방향으로만 전류), 트랜지스터, LED를 만들어요."),
        SciConcept(names: ["초전도체", "초전도"], body: "특정 온도(임계 온도) 아래에서 전기 저항이 0이 되는 물질이에요. 자석 위에 뜨는 마이스너 효과가 나타나요.\n이용: MRI(자기 공명 영상), 자기 부상 열차, 손실 없는 송전 연구."),
        SciConcept(names: ["태양계"], body: "태양과 그 주위를 도는 8개의 행성(수성, 금성, 지구, 화성, 목성, 토성, 천왕성, 해왕성), 위성, 소행성, 혜성 등으로 이루어져 있어요.\n지구형 행성(수·금·지·화)은 작고 단단하고, 목성형 행성(목·토·천·해)은 크고 고리가 있어요."),
        SciConcept(names: ["달의 위상", "달의 모양"], body: "달이 지구 둘레를 공전하면서 햇빛을 받는 부분이 우리에게 보이는 모양이 바뀌는 현상이에요. 약 한 달(29.5일) 주기로 삭 → 초승달 → 상현달 → 보름달(망) → 하현달 → 그믐달 순서로 변해요.\n일식은 삭일 때, 월식은 망일 때 일어날 수 있어요.")
    ]
}

// MARK: - 두잇 AI 지식 검색용

extension DoitScience {
    /// 개념 사전 전체 (이름들, 설명)
    static var knowledgeEntries: [(names: [String], body: String)] { concepts.map { ($0.names, $0.body) } }
}
