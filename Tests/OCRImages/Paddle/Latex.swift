import Foundation

// PaddleOCR-VL 비교 실험 전용 (앱에는 없음): 모델이 낸 LaTeX·마크다운을 앱이 쓰는 글 모양으로 바꿈
//   \frac{a}{b} → a/b (여러 글자면 (a)/(b)), \sqrt{x} → √x, ^{2} → ², \times → ×, \le → ≤, \square → □ …
//   마크다운 표·HTML 표는 칸을 나눈 줄로 (단어장은 칸마다 상자를 따로 줌)

enum PaddleText {
    /// 수식 기호 바꾸기 표
    static let symbols: [String: String] = [
        "times": "×", "div": "÷", "cdot": "·", "pm": "±", "mp": "∓", "ast": "*",
        "le": "≤", "leq": "≤", "leqslant": "≤", "ge": "≥", "geq": "≥", "geqslant": "≥",
        "ne": "≠", "neq": "≠", "lt": "<", "gt": ">", "approx": "≈", "sim": "~", "equiv": "≡",
        "square": "□", "Box": "□", "boxempty": "□", "blacksquare": "■", "Square": "□",
        "circ": "°", "degree": "°", "angle": "∠", "triangle": "△", "perp": "⊥", "parallel": "∥",
        "therefore": "∴", "because": "∵", "infty": "∞", "cdots": "…", "ldots": "…", "dots": "…", "cdotp": "·",
        "rightarrow": "→", "to": "→", "Rightarrow": "⇒", "leftarrow": "←", "leftrightarrow": "↔", "Leftrightarrow": "⇔",
        "in": "∈", "notin": "∉", "cup": "∪", "cap": "∩", "subset": "⊂", "subseteq": "⊆", "supset": "⊃", "emptyset": "∅",
        "pi": "π", "alpha": "α", "beta": "β", "gamma": "γ", "delta": "δ", "theta": "θ", "lambda": "λ", "mu": "μ",
        "sigma": "σ", "omega": "ω", "Delta": "Δ", "Omega": "Ω", "prime": "′",
        "%": "%", "{": "{", "}": "}", "_": "_", "&": "&", "#": "#", "$": "$",
        "quad": " ", "qquad": " ", ",": " ", ";": " ", ":": " ", ">": " ", "!": "", " ": " ", "enspace": " ", "thinspace": " ",
        "lbrace": "{", "rbrace": "}", "langle": "⟨", "rangle": "⟩", "vert": "|", "mid": "|", "lvert": "|", "rvert": "|",
        "\\": "\n", "newline": "\n", "colon": ":",
    ]
    /// 글자만 남기는 명령 (\text{…} → …)
    static let keepArgument: Set<String> = ["text", "mathrm", "mathbf", "textbf", "mathit", "textit", "operatorname", "boldsymbol",
                                            "mbox", "textrm", "mathsf", "mathtt", "texttt", "bm", "mathbb", "mathcal", "hbox", "textnormal",
                                            "overline", "widehat", "hat", "bar", "vec", "overrightarrow", "displaylines"]
    /// 지우는 명령 (글자 없이 꾸미기만)
    static let drop: Set<String> = ["left", "right", "big", "Big", "bigg", "Bigg", "bigl", "bigr", "Bigl", "Bigr", "biggl", "biggr",
                                    "displaystyle", "textstyle", "scriptstyle", "limits", "nolimits", "middle", "nonumber", "notag",
                                    "hline", "cline", "toprule", "midrule", "bottomrule", "centering", "noindent"]
    static let circled: [String: String] = ["1": "①", "2": "②", "3": "③", "4": "④", "5": "⑤", "6": "⑥", "7": "⑦", "8": "⑧", "9": "⑨"]

    /// 모델이 낸 글 전체 → 앱 글 모양 (줄 단위, 표는 칸을 3칸 띄어 이음)
    static func toApp(_ raw: String) -> String {
        rows(raw).map { $0.joined(separator: "   ") }.joined(separator: "\n")
    }

    /// 줄마다 칸 목록 (표가 아니면 칸 하나)
    static func rows(_ raw: String) -> [[String]] {
        var text = raw.replacingOccurrences(of: "\r", with: "")
        text = text.replacingOccurrences(of: "```[a-zA-Z]*", with: "", options: .regularExpression)
        text = htmlTables(text)
        var out: [[String]] = []
        for line in text.components(separatedBy: "\n") {
            var l = line.trimmingCharacters(in: .whitespaces)
            // 마크다운 꾸밈: 제목 #, 굵게 **, 목록 -
            l = l.replacingOccurrences(of: #"^#{1,6}\s+"#, with: "", options: .regularExpression)
            l = l.replacingOccurrences(of: "**", with: "")
            if l.isEmpty { continue }
            // 마크다운 표의 구분 줄 |---|---|
            if l.range(of: #"^\|?\s*:?-{2,}:?\s*(\|\s*:?-{2,}:?\s*)*\|?$"#, options: .regularExpression) != nil { continue }
            var cells: [String]
            if l.hasPrefix("|") || l.contains("\t") {
                cells = l.split(separator: l.contains("\t") && !l.hasPrefix("|") ? "\t" : "|", omittingEmptySubsequences: false).map(String.init)
            } else {
                cells = [l]
            }
            cells = cells.map { latex($0).trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty }
            // 한 칸 안에 \\ 로 줄바꿈한 수식은 여러 줄로
            if cells.count == 1 {
                for part in cells[0].components(separatedBy: "\n") where !part.trimmingCharacters(in: .whitespaces).isEmpty {
                    out.append([part.trimmingCharacters(in: .whitespaces)])
                }
            } else if !cells.isEmpty {
                out.append(cells.map { $0.replacingOccurrences(of: "\n", with: " ") })
            }
        }
        return out
    }

    /// <table><tr><td>a</td>… → 칸을 탭으로 나눈 줄
    static func htmlTables(_ text: String) -> String {
        guard text.contains("<t") else { return text }
        var t = text
        t = t.replacingOccurrences(of: #"</t[dh]>\s*"#, with: "\t", options: .regularExpression)
        t = t.replacingOccurrences(of: #"</tr>\s*"#, with: "\n", options: .regularExpression)
        t = t.replacingOccurrences(of: #"<br\s*/?>"#, with: " ", options: .regularExpression)
        t = t.replacingOccurrences(of: #"<[^>]+>"#, with: "", options: .regularExpression)
        t = t.replacingOccurrences(of: #"\t+\n"#, with: "\n", options: .regularExpression)
        return t
    }

    /// LaTeX 한 조각 → 앱 글 모양
    static func latex(_ input: String) -> String {
        var s = input
        // 수식 구분 기호
        for d in ["$$", "\\[", "\\]", "\\(", "\\)"] { s = s.replacingOccurrences(of: d, with: " ") }
        s = s.replacingOccurrences(of: #"(?<!\\)\$"#, with: " ", options: .regularExpression)
        s = s.replacingOccurrences(of: #"\\begin\{[a-z*]+\}(\{[^}]*\})?|\\end\{[a-z*]+\}"#, with: " ", options: .regularExpression)
        var chars = Array(s)
        var i = 0
        let result = parse(&chars, &i, stopAtBrace: false)
        return result.replacingOccurrences(of: #"[ \t]{2,}"#, with: " ", options: .regularExpression)
            .replacingOccurrences(of: "&", with: " ")
            .trimmingCharacters(in: .whitespaces)
    }

    private static func parse(_ c: inout [Character], _ i: inout Int, stopAtBrace: Bool) -> String {
        var out = ""
        while i < c.count {
            let ch = c[i]
            if ch == "}" {
                if stopAtBrace { i += 1; return out }
                i += 1; continue
            }
            if ch == "{" {
                i += 1
                out += parse(&c, &i, stopAtBrace: true)
                continue
            }
            if ch == "^" || ch == "_" {
                i += 1
                let arg = argument(&c, &i)
                if ch == "^" {
                    let a = arg.trimmingCharacters(in: .whitespaces)
                    if a == "2" { out += "²" } else if a == "3" { out += "³" }
                    else if a == "°" || a == "∘" { out += "°" }
                    else if a == "′" { out += "′" }
                    else { out += "^" + (a.count <= 1 || a.allSatisfy(\.isNumber) ? a : "(\(a))") }
                } else {
                    // 아래 첨자: 밑줄 ___ 은 빈칸이라 그대로, 아니면 글자만 (log_2 → log2)
                    out += arg.isEmpty ? "_" : arg
                }
                continue
            }
            if ch == "\\" {
                i += 1
                guard i < c.count else { break }
                var name = ""
                if c[i].isLetter {
                    while i < c.count, c[i].isLetter { name.append(c[i]); i += 1 }
                } else {
                    name = String(c[i]); i += 1
                }
                out += command(name, &c, &i)
                continue
            }
            if ch == "~" { out += " "; i += 1; continue }
            out.append(ch)
            i += 1
        }
        return out
    }

    /// 명령 뒤의 인자 하나: {…} 또는 글자 하나 또는 \명령
    private static func argument(_ c: inout [Character], _ i: inout Int) -> String {
        while i < c.count, c[i] == " " { i += 1 }
        guard i < c.count else { return "" }
        if c[i] == "{" {
            i += 1
            return parse(&c, &i, stopAtBrace: true)
        }
        if c[i] == "\\" {
            i += 1
            guard i < c.count else { return "" }
            var name = ""
            if c[i].isLetter { while i < c.count, c[i].isLetter { name.append(c[i]); i += 1 } } else { name = String(c[i]); i += 1 }
            return command(name, &c, &i)
        }
        let ch = c[i]
        i += 1
        return String(ch)
    }

    private static func wrap(_ t: String) -> String {
        let t = t.trimmingCharacters(in: .whitespaces)
        return t.count <= 1 || t.allSatisfy(\.isNumber) || (t.hasPrefix("(") && t.hasSuffix(")")) || t.hasPrefix("√") && !t.contains(" ") ? t : "(\(t))"
    }

    private static func command(_ name: String, _ c: inout [Character], _ i: inout Int) -> String {
        switch name {
        case "frac", "dfrac", "tfrac", "cfrac":
            let a = argument(&c, &i), b = argument(&c, &i)
            return wrap(a) + "/" + wrap(b)
        case "sqrt":
            var index = ""
            while i < c.count, c[i] == " " { i += 1 }
            if i < c.count, c[i] == "[" {
                i += 1
                while i < c.count, c[i] != "]" { index.append(c[i]); i += 1 }
                i += 1
            }
            let a = argument(&c, &i).trimmingCharacters(in: .whitespaces)
            let body = a.count <= 1 || a.allSatisfy(\.isNumber) ? a : "(\(a))"
            return (index.isEmpty ? "" : index) + "√" + body
        case "textcircled", "circled", "enclosed":
            let a = argument(&c, &i).trimmingCharacters(in: .whitespaces)
            return circled[a] ?? a
        case "boxed", "fbox", "framebox":
            let a = argument(&c, &i).trimmingCharacters(in: .whitespaces)
            return a.isEmpty || a.allSatisfy({ $0 == " " || $0 == "_" }) ? "□" : a
        case "underline", "underbar", "uline":
            let a = argument(&c, &i)
            return a.trimmingCharacters(in: .whitespaces).isEmpty ? "___" : a
        case "phantom", "hphantom", "vphantom", "label", "tag":
            _ = argument(&c, &i)
            return name == "phantom" || name == "hphantom" ? " " : ""
        case "hspace", "vspace", "kern", "mkern":
            _ = argument(&c, &i)
            return " "
        default:
            if keepArgument.contains(name) { return argument(&c, &i) }
            if drop.contains(name) { return "" }
            if let symbol = symbols[name] { return symbol }
            // 모르는 명령은 이름만 (sin, log, cos …)
            return name
        }
    }

    /// 단어장용: 줄 → OCRLine (줄마다 위에서 아래로, 표의 칸마다 왼쪽에서 오른쪽으로 상자를 나눠 줌; Vision 좌표처럼 아래가 0)
    static func lines(_ rows: [[String]]) -> [OCRLine] {
        let n = max(rows.count, 1)
        var out: [OCRLine] = []
        for (r, cells) in rows.enumerated() {
            let midY = 1 - (Double(r) + 0.5) / Double(n)
            let h = 0.6 / Double(n)
            let w = 1 / Double(cells.count)
            for (k, cell) in cells.enumerated() {
                let box = CGRect(x: Double(k) * w + 0.01, y: midY - h / 2, width: w - 0.02, height: h)
                out.append(OCRLine(text: cell, confidence: 0.9, box: box))
            }
        }
        return out
    }
}
