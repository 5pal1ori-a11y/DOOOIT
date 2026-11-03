import Foundation

/// 그림·그래프·차트·표에서 읽은 것 (기계가 읽은 값: 학생이 문제 탭에서 확인한 뒤에만 풀이에 씀)
///
/// 문제 글 끝에 이런 블록으로 붙여 둠 → 고치기 화면에서 글처럼 고칠 수 있고, 확정하면 풀이가 이 줄을 씀
///   [그림에서 읽음]
///   △ABC
///   A̅B̅ = 10
///   ∠C = 90°
///   [막대그래프] 1월 30, 2월 45, 3월 25
/// - 정밀 인식(PaddleOCR-VL)의 표·차트 읽기, 두잇 2(Qwen3.5 4B)의 그림 읽기, 기본 그래프 판독이 모두 이 모양으로 냄
/// - 모델이 답을 내게 하지 않음: 그림에 보이는 사실만 읽고, 계산은 규칙형 풀이가 함
enum DoitFigureFacts {
    static let header = "[그림에서 읽음]"

    /// 그림에서 읽은 것 한 묶음
    struct Reading: Equatable {
        enum Kind: String { case geometry, graph, chart, table }
        var kind: Kind
        /// 앱 표기 한 줄씩
        var lines: [String]
        /// 어디서 읽었는지 ("정밀 인식", "두잇 2", "기본 판독")
        var source: String = ""
        var isEmpty: Bool { lines.isEmpty }
    }

    // MARK: - 블록 붙이기·찾기

    /// 문제 글 끝에 붙일 블록 (줄이 없으면 빈 글)
    static func block(_ lines: [String]) -> String {
        let clean = lines.map { $0.trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty }
        guard !clean.isEmpty else { return "" }
        return ([header] + clean).joined(separator: "\n")
    }

    /// 글 → (블록 앞 문제 글, 블록 줄들). 블록이 없으면 줄은 빈 배열
    static func split(_ text: String) -> (problem: String, facts: [String]) {
        guard let r = text.range(of: header) else { return (text, []) }
        let problem = String(text[..<r.lowerBound]).trimmingCharacters(in: .whitespacesAndNewlines)
        let facts = text[r.upperBound...].components(separatedBy: "\n")
            .map { $0.trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty && $0 != header }
        return (problem, facts)
    }

    /// 블록을 바꿔 끼움 (없으면 끝에 붙이고, 줄이 비면 블록을 지움)
    static func replacing(_ text: String, with facts: [String]) -> String {
        let problem = split(text).problem
        let b = block(facts)
        return b.isEmpty ? problem : (problem.isEmpty ? b : problem + "\n" + b)
    }

    /// 사진 글에 그림에서 읽은 것을 붙임 (이미 블록이 있으면 바꿈)
    static func attach(_ reading: Reading?, to text: String) -> String {
        guard let reading, !reading.isEmpty else { return text }
        return replacing(text, with: reading.lines)
    }

    /// 문제 글에 그림·그래프·표가 있다고 적혀 있는지 (대화 사진: 이때만 그림을 읽음)
    static func mentionsFigure(_ text: String) -> Bool {
        let t = text.replacingOccurrences(of: " ", with: "")
        if ["그림", "그래프", "도표", "자료", "좌표평면"].contains(where: { t.contains($0) }) { return true }
        return route(text) == .table
    }

    /// 대화에 먼저 보여 줄 짧은 블록 ("그림에서 읽은 것" + 줄들 + 확인 부탁). 블록이 없으면 nil
    static func chatBlock(_ text: String) -> String? {
        let facts = split(text).facts
        guard !facts.isEmpty else { return nil }
        let shown = facts.prefix(8).map { "· " + $0 }.joined(separator: "\n")
        return "🔎 \(title(facts))에서 읽은 것\n\(shown)\n(사진에서 기계가 읽은 값이에요. 다르면 고쳐서 보내 주세요)"
    }

    /// 화면에 보일 짧은 이름
    static func title(_ facts: [String]) -> String {
        if facts.contains(where: { $0.hasPrefix("[") && $0.contains("그래프]") || $0.hasPrefix("[표]") || $0.contains(" | ") }) { return "자료" }
        if facts.contains(where: { $0.contains("그래프") || $0.contains("꼭짓점 (") || $0.contains("절편") || $0.hasPrefix("지나는 점") }) { return "그래프" }
        return "그림"
    }

    // MARK: - 어떤 그림인지 (문제 글로)

    /// 그림을 어떻게 읽을지: 표 / 차트(막대·꺾은선·원그래프) / 좌표 그래프 / 도형 / 없음
    enum Route: String { case table, chart, graph, geometry, none }

    static func route(_ problem: String) -> Route {
        let t = problem.replacingOccurrences(of: " ", with: "")
        func has(_ w: [String]) -> Bool { w.contains { t.contains($0) } }
        if has(["막대그래프", "꺾은선그래프", "원그래프", "띠그래프", "그림그래프", "히스토그램", "도수분포다각형", "그래프는", "그래프를"]),
           !has(["함수", "직선", "포물선", "좌표", "방정식", "기울기", "절편", "x축", "y축", "y=", "꼭짓점"]) { return .chart }
        if t.range(of: #"(도수분포|상대도수)?(?<![가-힣])표(는|를|에서|와|의|이다|로|$|,|\.)"#, options: .regularExpression) != nil
            || has(["도수분포표", "다음표", "아래표"]) { return .table }
        if has(["그래프", "좌표평면"]), has(["함수", "직선", "포물선", "좌표", "방정식", "기울기", "절편", "x축", "y축", "y=", "꼭짓점", "그래프의식"]) { return .graph }
        if has(["그래프"]) { return .chart }
        if has(["그림", "도형", "삼각형", "사각형", "원O", "∠", "△", "∥", "평행", "부채꼴", "직각"]) { return .geometry }
        return .none
    }

    // MARK: - 표 읽기 (정밀 인식의 표·차트 결과, 마크다운, HTML, OTSL)

    /// 모델이 낸 표 글 → 칸들 (빈 줄·구분선은 뺌). 표가 아니면 빈 배열
    static func parseTable(_ raw: String) -> [[String]] {
        let text = raw.replacingOccurrences(of: "\r", with: "")
        var rows: [[String]]
        if text.contains("<fcel>") || text.contains("<ecel>") || text.contains("<nl>") {
            rows = otslRows(text)
        } else if text.range(of: "<t[dh][ >]", options: [.regularExpression, .caseInsensitive]) != nil {
            rows = htmlRows(text)
        } else if text.contains("&"), text.contains("\\\\") {
            // LaTeX tabular
            let body = text.replacingOccurrences(of: #"\\(begin|end)\{(tabular|array)\}(\{[^}]*\})?"#, with: "", options: .regularExpression)
                .replacingOccurrences(of: "\\hline", with: "")
            rows = body.components(separatedBy: "\\\\").map { $0.components(separatedBy: "&").map(cleanCell) }
        } else {
            rows = text.components(separatedBy: "\n").compactMap { line -> [String]? in
                let t = line.trimmingCharacters(in: .whitespaces)
                guard !t.isEmpty else { return nil }
                // 마크다운 구분선 |---|:---:|
                if t.range(of: #"^\|?\s*:?-{2,}:?\s*(\|\s*:?-{2,}:?\s*)*\|?$"#, options: .regularExpression) != nil { return nil }
                if t.contains("|") {
                    var cells = t.components(separatedBy: "|")
                    if t.hasPrefix("|") { cells.removeFirst() }
                    if t.hasSuffix("|"), !cells.isEmpty { cells.removeLast() }
                    return cells.map(cleanCell)
                }
                if t.contains("\t") { return t.components(separatedBy: "\t").map(cleanCell) }
                return nil
            }
        }
        rows = rows.map { $0.map(cleanCell) }.filter { $0.contains(where: { !$0.isEmpty }) }
        // 칸 수를 맞춤 (모자라면 빈칸)
        let width = rows.map(\.count).max() ?? 0
        guard width >= 2, rows.count >= 2 else { return [] }
        return rows.map { $0 + Array(repeating: "", count: width - $0.count) }
    }

    private static func otslRows(_ text: String) -> [[String]] {
        var rows: [[String]] = []
        var row: [String] = []
        var cell: String?
        var rest = Substring(text)
        func closeCell() { if let c = cell { row.append(c) }; cell = nil }
        while !rest.isEmpty {
            if rest.hasPrefix("<") , let end = rest.firstIndex(of: ">") {
                let tag = rest[rest.startIndex...end]
                rest = rest[rest.index(after: end)...]
                switch tag {
                case "<fcel>": closeCell(); cell = ""
                case "<ecel>", "<lcel>", "<ucel>", "<xcel>": closeCell(); row.append("")
                case "<nl>": closeCell(); if !row.isEmpty { rows.append(row) }; row = []
                default: cell? += tag
                }
            } else {
                let ch = rest.removeFirst()
                if cell != nil { cell!.append(ch) } else if !ch.isWhitespace { cell = String(ch) }
            }
        }
        closeCell()
        if !row.isEmpty { rows.append(row) }
        return rows
    }

    private static func htmlRows(_ text: String) -> [[String]] {
        var rows: [[String]] = []
        for tr in text.components(separatedBy: #"<tr"#).dropFirst() {
            var cells: [String] = []
            let parts = tr.components(separatedBy: "<t").dropFirst()
            for part in parts where part.hasPrefix("d") || part.hasPrefix("h") {
                guard let start = part.firstIndex(of: ">") else { continue }
                var content = String(part[part.index(after: start)...])
                if let end = content.range(of: "</t") { content = String(content[..<end.lowerBound]) }
                cells.append(content.replacingOccurrences(of: "<[^>]+>", with: "", options: .regularExpression))
            }
            if !cells.isEmpty { rows.append(cells) }
        }
        return rows
    }

    private static func cleanCell(_ s: String) -> String {
        var t = s.replacingOccurrences(of: "**", with: "")
            .replacingOccurrences(of: #"\$([^$]*)\$"#, with: "$1", options: .regularExpression)
            .replacingOccurrences(of: "\\%", with: "%")
            .replacingOccurrences(of: "&nbsp;", with: " ")
        t = t.replacingOccurrences(of: #"\s+"#, with: " ", options: .regularExpression)
        return t.trimmingCharacters(in: .whitespaces)
    }

    // MARK: - 표·차트 → 줄

    /// 차트 종류 (이름표에 씀)
    enum ChartKind: String {
        case bar = "막대그래프", line = "꺾은선그래프", pie = "원그래프", table = "표"
    }

    /// 표를 문제에 붙일 줄로: 값이 한 줄로 이어지는 자료(이름-값 두 칸)는 "[막대그래프] 1월 30, 2월 45",
    /// 칸이 많은 표는 "[표]" 다음에 "연도 | 2019 | 2020" 줄들
    static func tableLines(_ table: [[String]], kind: ChartKind) -> [String] {
        guard table.count >= 2, let width = table.first?.count, width >= 2 else { return [] }
        let isValue: (String) -> Bool = { number(in: $0) != nil }
        // 이름 | 값 (세로로 긴 두 칸 표) → 머리줄이 이름이면 빼고 한 줄로
        if width == 2 {
            let body = table.first.map { !isValue($0[1]) } == true ? Array(table.dropFirst()) : table
            if body.count >= 2, body.allSatisfy({ !$0[0].isEmpty && isValue($0[1]) }) {
                let unit = table.first.map { !isValue($0[1]) ? unitHint($0[1]) : "" } ?? ""
                return ["[\(kind.rawValue)] " + body.map { "\($0[0]) \(withUnit($0[1], unit))" }.joined(separator: ", ")]
            }
        }
        // 가로로 긴 두 줄 표 (첫 줄 이름, 둘째 줄 값)
        if table.count == 2, width >= 3, table[1].dropFirst().allSatisfy(isValue), !table[0].dropFirst().contains(where: { $0.isEmpty }) {
            let pairs = zip(table[0].dropFirst(), table[1].dropFirst()).map { "\($0) \($1)" }
            let name = table[1][0].isEmpty ? "" : " (\(table[1][0]))"
            return ["[\(kind.rawValue)]\(name) " + pairs.joined(separator: ", ")]
        }
        return ["[\(kind == .table ? "표" : kind.rawValue)]"] + table.map { $0.joined(separator: " | ") }
    }

    private static func unitHint(_ header: String) -> String {
        // "인구(만 명)" → "만 명" 같은 단위는 값 뒤에 붙이지 않음 (풀이가 숫자로 읽게) → 지금은 쓰지 않음
        ""
    }

    private static func withUnit(_ v: String, _ unit: String) -> String { unit.isEmpty ? v : v + unit }

    /// 글 속 첫 숫자 ("45%", "1,200명", "-3.5")
    static func number(in s: String) -> Double? {
        guard let r = s.range(of: #"-?\d{1,3}(?:,\d{3})+(?:\.\d+)?|-?\d+(?:\.\d+)?"#, options: .regularExpression) else { return nil }
        let hasOther = s[..<r.lowerBound].contains(where: { $0.isNumber })
        guard !hasOther else { return nil }
        return Double(s[r].replacingOccurrences(of: ",", with: ""))
    }

    // MARK: - 자료(차트) 읽기 → 풀이

    /// 이름-값 자료 하나
    struct Series: Equatable {
        var name: String
        var labels: [String]
        var values: [Double]
    }

    /// 블록 줄에서 자료를 찾음: "[막대그래프] 1월 30, 2월 45" 줄이나 "[표]" 다음 칸 줄들
    static func series(in facts: [String]) -> [Series] {
        var found: [Series] = []
        var tableRows: [[String]] = []
        for line in facts {
            if line.contains("|") {
                tableRows.append(line.components(separatedBy: "|").map { $0.trimmingCharacters(in: .whitespaces) })
                continue
            }
            guard line.hasPrefix("["), let close = line.firstIndex(of: "]") else { continue }
            var rest = line[line.index(after: close)...].trimmingCharacters(in: .whitespaces)
            var name = String(line[line.index(after: line.startIndex)..<close])
            // "(인구(만 명))"처럼 괄호 안에 괄호가 있어도 짝이 맞는 데까지가 자료 이름
            if rest.hasPrefix("(") {
                var depth = 0
                var end: String.Index?
                for i in rest.indices {
                    if rest[i] == "(" { depth += 1 } else if rest[i] == ")" { depth -= 1; if depth == 0 { end = i; break } }
                }
                if let end {
                    name = String(rest[rest.index(after: rest.startIndex)..<end])
                    rest = rest[rest.index(after: end)...].trimmingCharacters(in: .whitespaces)
                }
            }
            var labels: [String] = [], values: [Double] = []
            for item in rest.components(separatedBy: ",") {
                let t = item.trimmingCharacters(in: .whitespaces)
                // 마지막 숫자가 값, 그 앞이 이름 ("1월 30", "A 45%", "2019년 1,200")
                guard let m = t.range(of: #"(-?\d+(?:\.\d+)?)\s*(%|[가-힣A-Za-z]{0,3})$"#, options: .regularExpression) else { continue }
                let label = t[..<m.lowerBound].trimmingCharacters(in: .whitespaces)
                guard !label.isEmpty, let v = number(in: String(t[m])) else { continue }
                labels.append(label); values.append(v)
            }
            if labels.count >= 2 { found.append(Series(name: name, labels: labels, values: values)) }
        }
        // 칸 표: 첫 줄 머리, 첫 칸 이름, 숫자 칸마다 자료 하나 (세로), 또는 첫 칸이 머리인 줄마다 (가로)
        if tableRows.count >= 2, let width = tableRows.first?.count, width >= 2 {
            let rows = tableRows.filter { $0.count == width }
            let header = rows[0]
            for col in 1..<width {
                let body = rows.dropFirst()
                let values = body.compactMap { number(in: $0[col]) }
                if values.count == body.count, values.count >= 2 {
                    found.append(Series(name: header[col], labels: body.map { $0[0] }, values: values))
                }
            }
            if found.isEmpty || width > rows.count {
                for row in rows.dropFirst() {
                    let values = row.dropFirst().compactMap { number(in: $0) }
                    if values.count == width - 1, values.count >= 2 {
                        found.append(Series(name: row[0], labels: Array(header.dropFirst()), values: values))
                    }
                }
            }
        }
        // 합계 줄은 자료가 아님 (가장 큰 값·합·평균에 섞이지 않게)
        let totals: Set<String> = ["합계", "계", "총계", "합", "전체", "총합"]
        return found.map { s in
            let keep = s.labels.indices.filter { !totals.contains(s.labels[$0].replacingOccurrences(of: " ", with: "")) }
            return Series(name: s.name, labels: keep.map { s.labels[$0] }, values: keep.map { s.values[$0] })
        }.filter { $0.labels.count >= 2 }
    }

    struct ChartAnswer {
        var topic: String
        var steps: [(String, String)]
        var answer: String
        /// 답이 자료의 이름 (가장 많은 것 …)
        var label: String?
        var value: Double?
    }

    private static func fmt(_ v: Double) -> String {
        if abs(v - v.rounded()) < 1e-9 { return String(Int(v.rounded())) }
        var s = String(format: "%.2f", v)
        while s.hasSuffix("0") { s.removeLast() }
        if s.hasSuffix(".") { s.removeLast() }
        return s
    }

    /// 자료로 답할 수 있는 질문: 가장 많은·적은 것, 합, 평균, 두 값의 차, 몇 배, 증가율·감소율, 한 값
    static func solveChart(question raw: String, facts: [String]) -> ChartAnswer? {
        let all = series(in: facts)
        guard !all.isEmpty else { return nil }
        let q = raw
        let compact = q.filter { !$0.isWhitespace }
        // 물은 자료 (자료 이름이 질문에 있으면 그것, 아니면 첫 자료)
        let s = all.first(where: { !$0.name.isEmpty && compact.contains($0.name.filter { !$0.isWhitespace }) }) ?? all[0]
        // 질문에 나온 이름표 (나온 차례대로): 긴 이름부터 찾아 "10월"이 "1월"로 잡히지 않게
        var mentioned: [(Int, String.Index)] = []
        var taken: [Range<String.Index>] = []
        for i in s.labels.indices.sorted(by: { s.labels[$0].count > s.labels[$1].count }) {
            var from = q.startIndex
            while let r = q.range(of: s.labels[i], range: from..<q.endIndex) {
                let before = r.lowerBound > q.startIndex ? q[q.index(before: r.lowerBound)] : " "
                if !taken.contains(where: { $0.overlaps(r) }), !(before.isNumber && s.labels[i].first?.isNumber == true) {
                    taken.append(r); mentioned.append((i, r.lowerBound)); break
                }
                from = r.upperBound
            }
        }
        let named = mentioned.sorted { $0.1 < $1.1 }.map(\.0)
        let pairs = zip(s.labels, s.values).map { "\($0) \(fmt($1))" }.joined(separator: ", ")
        let readStep = ("그림에서 읽은 자료", pairs)
        func has(_ w: [String]) -> Bool { w.contains { compact.contains($0) } }

        if has(["증가율", "감소율", "변화율", "몇%증가", "몇%감소", "몇퍼센트"]), named.count >= 2 {
            let a = s.values[named[0]], b = s.values[named[1]]
            guard a != 0 else { return nil }
            let rate = (b - a) / abs(a) * 100
            return ChartAnswer(topic: "자료의 증가율", steps: [readStep, ("증가율 = (나중 값 − 처음 값) ÷ 처음 값 × 100", "(\(fmt(b)) − \(fmt(a))) ÷ \(fmt(a)) × 100 = \(fmt(rate))%")],
                               answer: "\(fmt(rate))%", label: nil, value: rate)
        }
        if has(["몇배"]), named.count >= 2 {
            let a = s.values[named[0]], b = s.values[named[1]]
            guard b != 0 else { return nil }
            return ChartAnswer(topic: "자료의 비교", steps: [readStep, ("\(s.labels[named[0]]) ÷ \(s.labels[named[1]])", "\(fmt(a)) ÷ \(fmt(b)) = \(fmt(a / b))")],
                               answer: "\(fmt(a / b))배", label: nil, value: a / b)
        }
        if has(["차는", "차를", "차이", "얼마나더", "몇더", "차가"]), named.count >= 2 {
            let a = s.values[named[0]], b = s.values[named[1]]
            return ChartAnswer(topic: "자료의 비교", steps: [readStep, ("두 값의 차", "|\(fmt(a)) − \(fmt(b))| = \(fmt(abs(a - b)))")],
                               answer: fmt(abs(a - b)), label: nil, value: abs(a - b))
        }
        if has(["평균"]) {
            let sum = s.values.reduce(0, +), mean = sum / Double(s.values.count)
            return ChartAnswer(topic: "자료의 평균", steps: [readStep, ("평균 = 합 ÷ 개수", "\(fmt(sum)) ÷ \(s.values.count) = \(fmt(mean))")],
                               answer: fmt(mean), label: nil, value: mean)
        }
        if has(["합", "총", "모두몇", "전체"]), !has(["가장"]) {
            let sum = s.values.reduce(0, +)
            return ChartAnswer(topic: "자료의 합", steps: [readStep, ("모두 더하면", s.values.map(fmt).joined(separator: " + ") + " = \(fmt(sum))")],
                               answer: fmt(sum), label: nil, value: sum)
        }
        let most = has(["가장많", "가장큰", "가장높", "가장길", "가장무거", "가장비싼", "최댓값", "최대", "제일많", "제일높"])
        let least = has(["가장적", "가장작", "가장낮", "가장짧", "가장가벼", "가장싼", "최솟값", "최소", "제일적", "제일낮"])
        if most != least, let target = most ? s.values.max() : s.values.min() {
            let idx = s.values.indices.filter { s.values[$0] == target }
            guard idx.count == 1 else { return nil }
            let label = s.labels[idx[0]]
            // "가장 많은 달은?" → 이름, "최댓값은?" → 값
            let asksValue = has(["최댓값", "최솟값"]) || compact.range(of: "가장(많|적|큰|작|높|낮)은(값|수|양)", options: .regularExpression) != nil
            return ChartAnswer(topic: most ? "가장 큰 값 찾기" : "가장 작은 값 찾기", steps: [readStep, (most ? "가장 큰 값" : "가장 작은 값", "\(label) \(fmt(target))")],
                               answer: asksValue ? fmt(target) : label, label: label, value: target)
        }
        if named.count == 1, has(["얼마", "몇", "값", "구하"]) {
            let v = s.values[named[0]]
            return ChartAnswer(topic: "자료 읽기", steps: [readStep, ("\(s.labels[named[0]])의 값", fmt(v))], answer: fmt(v), label: s.labels[named[0]], value: v)
        }
        return nil
    }

    // MARK: - 그래프 사실 → 식

    /// "지나는 점: (0, 1), (2, 5)", "꼭짓점 (1, -2)", "x절편 3", "y절편 1"에서 식을 구함 (정확히 맞는 식만)
    /// 직선: 점 두 개(절편 포함), 포물선: 꼭짓점 + 점 하나 또는 점 세 개
    /// hint: 문제 글 ("이차함수", "포물선"이 있으면 점 셋으로 포물선)
    static func graphEquation(_ facts: [String], hint: String = "") -> String? {
        let text = facts.joined(separator: "\n") + "\n" + hint
        var points: [(Double, Double)] = []
        func add(_ p: (Double, Double)) { if !points.contains(where: { abs($0.0 - p.0) < 1e-9 && abs($0.1 - p.1) < 1e-9 }) { points.append(p) } }
        var vertex: (Double, Double)?
        let pointPattern = #"\(\s*(-?\d+(?:\.\d+)?)\s*,\s*(-?\d+(?:\.\d+)?)\s*\)"#
        for line in facts {
            let l = line.replacingOccurrences(of: "−", with: "-")
            let found = matchAll(l, pointPattern).compactMap { m -> (Double, Double)? in
                guard let x = Double(m[1]), let y = Double(m[2]) else { return nil }
                return (x, y)
            }
            if l.contains("꼭짓점"), let v = found.first { vertex = v; continue }
            if l.contains("지나") || l.contains("점") || l.contains("좌표") { found.forEach(add) }
            if let m = matchAll(l, #"x\s*절편\s*[:=은는]?\s*(-?\d+(?:\.\d+)?)"#).first, let x = Double(m[1]) { add((x, 0)) }
            if let m = matchAll(l, #"y\s*절편\s*[:=은는]?\s*(-?\d+(?:\.\d+)?)"#).first, let y = Double(m[1]) { add((0, y)) }
        }
        let parabola = text.contains("포물선") || text.contains("이차함수") || vertex != nil
        if parabola {
            if let v = vertex, let p = points.first(where: { abs($0.0 - v.0) > 1e-9 }) {
                let a = (p.1 - v.1) / ((p.0 - v.0) * (p.0 - v.0))
                guard a != 0 else { return nil }
                return "y = " + poly(a: a, b: -2 * a * v.0, c: a * v.0 * v.0 + v.1)
            }
            guard points.count >= 3 else { return nil }
            let (x1, y1) = points[0], (x2, y2) = points[1], (x3, y3) = points[2]
            let den = (x1 - x2) * (x1 - x3) * (x2 - x3)
            guard abs(den) > 1e-9 else { return nil }
            let a = (x3 * (y2 - y1) + x2 * (y1 - y3) + x1 * (y3 - y2)) / den
            let b = (x3 * x3 * (y1 - y2) + x2 * x2 * (y3 - y1) + x1 * x1 * (y2 - y3)) / den
            let c = (x2 * x3 * (x2 - x3) * y1 + x3 * x1 * (x3 - x1) * y2 + x1 * x2 * (x1 - x2) * y3) / den
            guard a != 0 else { return nil }
            return "y = " + poly(a: a, b: b, c: c)
        }
        guard points.count >= 2 else { return nil }
        let (x1, y1) = points[0], (x2, y2) = points[1]
        if abs(x1 - x2) < 1e-9 { return "x = \(fmt(x1))" }
        let m = (y2 - y1) / (x2 - x1)
        // 점이 셋 이상이면 모두 한 직선 위에 있어야 함 (읽기가 틀렸을 수 있음)
        for p in points.dropFirst(2) where abs(y1 + m * (p.0 - x1) - p.1) > 1e-6 { return nil }
        return "y = " + poly(a: 0, b: m, c: y1 - m * x1)
    }

    private static func coefficient(_ v: Double) -> String {
        if abs(v - v.rounded()) < 1e-9 { return String(Int(v.rounded())) }
        for den in 2...12 {
            let n = v * Double(den)
            if abs(n - n.rounded()) < 1e-9 { return "\(Int(n.rounded()))/\(den)" }
        }
        return fmt(v)
    }

    /// ax² + bx + c 글 (0인 항은 뺌, 계수 1은 생략)
    static func poly(a: Double, b: Double, c: Double) -> String {
        var out = ""
        func term(_ v: Double, _ x: String) {
            guard abs(v) > 1e-12 else { return }
            let sign = v < 0 ? (out.isEmpty ? "-" : " - ") : (out.isEmpty ? "" : " + ")
            var mag = coefficient(abs(v))
            if !x.isEmpty, mag == "1" { mag = "" }
            if !x.isEmpty, mag.contains("/") { mag = "(\(mag))" }
            out += sign + mag + x
        }
        term(a, "x²"); term(b, "x"); term(c, "")
        return out.isEmpty ? "0" : out
    }

    private static func matchAll(_ t: String, _ pattern: String) -> [[String]] {
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return [] }
        let ns = t as NSString
        return regex.matches(in: t, range: NSRange(location: 0, length: ns.length)).map { m in
            (0..<m.numberOfRanges).map { m.range(at: $0).location == NSNotFound ? "" : ns.substring(with: m.range(at: $0)) }
        }
    }

    // MARK: - 풀이에 넘길 글

    /// 확인한 블록을 풀이 엔진이 읽는 글로: 머리말은 빼고, 그래프 사실로 식을 구할 수 있으면 "그래프의 식은 y = …" 문장을 더함
    /// 그림 사실은 선택지 앞에 넣음 (선택지 ⑤ 뒤에 붙으면 ⑤의 글로 읽혀서)
    static func solverText(_ text: String) -> String {
        let (problem, facts) = split(text)
        guard !facts.isEmpty else { return text }
        var lines = facts.filter { !($0.hasPrefix("[") && $0.contains("]")) && !$0.contains(" | ") }
        if !lines.contains(where: { $0.hasPrefix("그래프의 식") }), let eq = graphEquation(facts, hint: problem) { lines.append("그래프의 식은 \(eq)") }
        let parts = stemAndChoices(problem)
        return ([parts.stem] + lines + (parts.choices.isEmpty ? [] : [parts.choices])).joined(separator: "\n")
    }

    /// 문제 글 → (선택지 앞 글, 선택지 줄부터 끝까지)
    static func stemAndChoices(_ problem: String) -> (stem: String, choices: String) {
        guard let first = problem.firstIndex(where: { "①②③④⑤".contains($0) }), problem.contains("②") else { return (problem, "") }
        // 선택지 표시가 있는 줄의 처음부터
        let lineStart = problem[..<first].lastIndex(of: "\n").map { problem.index(after: $0) } ?? problem.startIndex
        let before = problem[lineStart..<first].trimmingCharacters(in: .whitespaces)
        let cut = before.isEmpty ? lineStart : first
        return (String(problem[..<cut]).trimmingCharacters(in: .whitespacesAndNewlines), String(problem[cut...]))
    }

    // MARK: - 두잇 2 그림 읽기 지시문과 답 읽기

    /// 두잇 2(사진을 보는 모델)에게 주는 지시: 보이는 사실만, 정해진 줄 모양으로 (답·풀이 금지)
    static let visionPrompt = """
    이 문제 사진의 그림·그래프·표에 실제로 보이는 것만 아래 줄 모양으로 적으세요.
    문제를 풀거나 답을 쓰지 마세요. 그림에 적혀 있지 않은 값은 계산하거나 짐작하지 말고 빼세요.
    한 줄에 하나씩, 해당하는 줄만 쓰세요.
    종류: 도형 / 그래프 / 막대그래프 / 꺾은선그래프 / 원그래프 / 표 / 없음
    점: <그림에 적힌 점 이름들, 쉼표로>
    길이: <선분 이름> = <그림에 적힌 숫자>
    각: <각 이름> = <그림에 적힌 도>
    직각: <직각 표시가 있는 각 이름>
    평행: <선분>, <선분>
    원: <중심 이름>, 반지름 = <숫자>
    지나는 점: (<x>, <y>), (<x>, <y>)
    꼭짓점: (<x>, <y>)
    x절편: <숫자>
    y절편: <숫자>
    값: <항목 이름> = <숫자>
    """

    /// "1월 = 30, 2월 = 45" / "A=20, B=35" / "가 1,200, 나 950" → 이름-값 쌍 (천 단위 쉼표는 나누지 않음)
    /// needsSign: 항목마다 "="가 있어야 함 (머리말 없는 줄에서 아무 글이나 값으로 읽지 않게)
    static func valuePairs(_ text: String, needsSign: Bool) -> [(String, String)] {
        let items = text.replacingOccurrences(of: #",(?!\d)"#, with: "\u{1F}", options: .regularExpression).components(separatedBy: "\u{1F}")
        var out: [(String, String)] = []
        for item in items.map({ $0.trimmingCharacters(in: .whitespaces) }) {
            if needsSign, !item.contains("=") { continue }
            guard let m = matchAll(item, #"^(.+?)\s*[=:]?\s*(-?\d{1,3}(?:,\d{3})+(?:\.\d+)?|-?\d+(?:\.\d+)?)\s*(%?)$"#).first else { continue }
            let label = m[1].trimmingCharacters(in: .whitespaces)
            guard !label.isEmpty, label.count <= 12 else { continue }
            out.append((label, m[2].replacingOccurrences(of: ",", with: "") + m[3]))
        }
        return out
    }

    /// 두잇 2가 낸 글 → 앱 표기 줄 (모양이 맞는 줄만 씀: 모르는 줄·답 같은 줄은 버림)
    static func parseVision(_ raw: String) -> Reading? {
        var kind: Reading.Kind = .geometry
        var chart: ChartKind?
        var lines: [String] = []
        var values: [(String, String)] = []
        var graphPoints: [String] = []
        func add(_ s: String) { if !s.isEmpty, !lines.contains(s) { lines.append(s) } }
        func addValue(_ pair: (String, String)) {
            guard !pair.0.isEmpty, !values.contains(where: { $0.0 == pair.0 }) else { return }
            values.append(pair)
        }
        let seg = #"(?<![A-Za-z])([A-Z])\x{0305}?\s*([A-Z])\x{0305}?(?![A-Za-z])"#
        // 같은 말을 되풀이한 답("도형, 도형, 도형, …")은 버림
        if raw.range(of: #"([^\s,]{1,6})(?:\s*,\s*\1){5,}"#, options: .regularExpression) != nil, !raw.contains(":") { return nil }
        for rawLine in raw.replacingOccurrences(of: "\r", with: "").components(separatedBy: "\n") {
            var line = rawLine.trimmingCharacters(in: .whitespaces)
            line = line.replacingOccurrences(of: #"^[-*•·]\s*|^\d+[.)]\s+"#, with: "", options: .regularExpression)
                .replacingOccurrences(of: "**", with: "").replacingOccurrences(of: "：", with: ":")
                .replacingOccurrences(of: "−", with: "-")
            guard let colon = line.firstIndex(of: ":") else {
                // "막대그래프, A=20, B=35"처럼 머리말 없이 값만 쓴 줄, "1월, 30"처럼 이름-값 한 쌍인 줄
                // 차트·표라고 밝힌 답에서만 (도형 답이 되풀이되며 "AB = 1, AC = 1"처럼 낸 것을 값으로 읽지 않게)
                let chartWords = ["그래프", "표", "자료"]
                let pairs = kind == .chart || kind == .table || chartWords.contains(where: { line.contains($0) }) ? valuePairs(line, needsSign: true) : []
                if pairs.count >= 2 { pairs.forEach(addValue) }
                else if let m = matchAll(line, #"^([^,=:]{1,12}?)\s*[,=]\s*(-?\d{1,3}(?:,\d{3})+(?:\.\d+)?|-?\d+(?:\.\d+)?)\s*(%?)$"#).first {
                    addValue((m[1].trimmingCharacters(in: .whitespaces), m[2].replacingOccurrences(of: ",", with: "") + m[3]))
                } else if ["표", "막대그래프", "꺾은선그래프", "원그래프"].contains(line) {
                    if line == "표" { kind = .table; chart = .table } else { kind = .chart; chart = line == "막대그래프" ? .bar : line == "꺾은선그래프" ? .line : .pie }
                }
                continue
            }
            let key = line[..<colon].trimmingCharacters(in: .whitespaces).lowercased()
            let value = line[line.index(after: colon)...].trimmingCharacters(in: .whitespaces)
            guard !value.isEmpty, !["없음", "없다", "none", "-", "?", "모름"].contains(value) else { continue }
            // 자리표시(<숫자>)를 그대로 따라 쓴 줄은 버림
            guard !value.contains("<"), !value.contains("숫자") else { continue }
            switch key {
            case "종류", "type", "kind":
                if value.contains("막대") { kind = .chart; chart = .bar }
                else if value.contains("꺾은선") { kind = .chart; chart = .line }
                else if value.contains("원그래프") || value.contains("원 그래프") { kind = .chart; chart = .pie }
                else if value.contains("표") { kind = .table; chart = .table }
                else if value.contains("그래프") { kind = .graph }
                else if value.contains("도형") { kind = .geometry }
            case "점", "points":
                let names = value.components(separatedBy: CharacterSet(charactersIn: ", ")).filter { $0.count == 1 && $0.first!.isUppercase }
                if names.count == 3 { add("△" + names.joined()) } else if names.count == 4 { add("사각형 " + names.joined()) }
            case "길이", "변", "선분", "length", "side":
                for m in matchAll(value, seg + #"\s*=\s*(\d+(?:\.\d+)?(?:\s*cm)?)"#) {
                    add(GeometryText.segment(m[1] + m[2]) + " = " + m[3].replacingOccurrences(of: " ", with: ""))
                }
            case "각", "angle":
                let named = matchAll(value, #"∠?\s*([A-Z]{1,3}|[a-z])\s*=\s*(\d+(?:\.\d+)?)\s*(?:°|도)?"#)
                for m in named { add("∠\(m[1]) = \(m[2])°") }
                // 이름 없이 그림에 적힌 각도 ("65°"): 어느 각인지는 학생이 확인
                if named.isEmpty {
                    for m in matchAll(value, #"(?<![\d.])(\d+(?:\.\d+)?)\s*°"#) where Double(m[1]).map({ $0 > 0 && $0 < 360 }) == true {
                        add("그림에 적힌 각 \(m[1])°")
                    }
                }
            case "직각", "right angle":
                for m in matchAll(value, #"∠?\s*([A-Z]{3}|[A-Z])(?![A-Za-z])"#) {
                    add("∠\(m[1]) = 90°")
                }
            case "평행", "parallel":
                let segs = matchAll(value, seg).map { GeometryText.segment($0[1] + $0[2]) }
                let named = matchAll(value, #"(?<![A-Za-z])([a-z])(?![A-Za-z])"#).map { $0[1] }
                if segs.count == 2 { add("\(segs[0]) ∥ \(segs[1])") } else if named.count == 2 { add("\(named[0]) ∥ \(named[1])") }
            case "수직", "perpendicular":
                let segs = matchAll(value, seg).map { GeometryText.segment($0[1] + $0[2]) }
                if segs.count == 2 { add("\(segs[0]) ⊥ \(segs[1])") }
            case "원", "circle":
                let center = matchAll(value, #"^([A-Z])(?![A-Za-z])"#).first?[1] ?? "O"
                if let r = matchAll(value, #"반지름\s*=?\s*(\d+(?:\.\d+)?)"#).first?[1] { add("원 \(center)의 반지름 = \(r)") }
                else { add("원 \(center)") }
            case "중심각":
                if let m = matchAll(value, #"∠?\s*([A-Z]{3})\s*=\s*(\d+(?:\.\d+)?)"#).first { add("중심각 ∠\(m[1]) = \(m[2])°") }
            case "지나는 점", "점의 좌표", "좌표", "passes":
                let pts = matchAll(value, #"\(\s*-?\d+(?:\.\d+)?\s*,\s*-?\d+(?:\.\d+)?\s*\)"#).map { $0[0].replacingOccurrences(of: " ", with: "").replacingOccurrences(of: ",", with: ", ") }
                for p in pts where !graphPoints.contains(p) { graphPoints.append(p) }
                if kind == .geometry { kind = .graph }
            case "꼭짓점", "vertex":
                if let p = matchAll(value, #"\(\s*-?\d+(?:\.\d+)?\s*,\s*-?\d+(?:\.\d+)?\s*\)"#).first?[0] {
                    add("꼭짓점 " + p.replacingOccurrences(of: " ", with: "").replacingOccurrences(of: ",", with: ", "))
                    kind = .graph
                }
            case "x절편", "x 절편", "x-intercept":
                if let n = matchAll(value, #"-?\d+(?:\.\d+)?"#).first?[0] { add("x절편 \(n)"); kind = .graph }
            case "y절편", "y 절편", "y-intercept":
                if let n = matchAll(value, #"-?\d+(?:\.\d+)?"#).first?[0] { add("y절편 \(n)"); kind = .graph }
            case "값", "value", "자료":
                // "1월 = 30" 한 줄에 하나, 또는 "1월 30, 2월 45"처럼 쉼표로 여러 개
                valuePairs(value, needsSign: false).forEach(addValue)
            default:
                continue
            }
        }
        if !graphPoints.isEmpty { lines.insert("지나는 점 " + graphPoints.joined(separator: ", "), at: 0) }
        if values.count >= 2 {
            if kind != .chart && kind != .table { kind = .chart }
            lines.append("[\((chart ?? .bar).rawValue)] " + values.map { "\($0.0) \($0.1)" }.joined(separator: ", "))
        }
        guard !lines.isEmpty else { return nil }
        return Reading(kind: kind, lines: lines, source: "두잇 2")
    }
}
