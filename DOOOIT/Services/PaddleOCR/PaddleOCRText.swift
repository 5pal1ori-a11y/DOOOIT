import Foundation

// 정밀 인식(PaddleOCR-VL)이 낸 글 → 앱이 쓰는 글 모양
//   모델은 수식을 LaTeX(\frac{1}{2}, \sqrt{3}, x^{2}, \(…\))로, 표는 마크다운·HTML로 내놓아서
//   Vision 인식과 같은 글 모양(1/2, √3, x², 보기 ①~⑤)으로 바꾼 뒤 같은 교정(MathOCRFixer)을 거침
//   (비교 실험 Tests/OCRImages/Paddle/Latex.swift 를 옮김: 141장 실험에서 이 변환 + 교정으로 129장 통과)

enum PaddleOCRText {
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
        // 미적분: \sum_{k=1}^{n} → ∑_{k=1}^{n}, \int_a^b → ∫_a^b, \lim_{x \to a} → lim_{x→a} (첨자는 parse 에서 붙임)
        "sum": "∑", "int": "∫", "prod": "∏", "oint": "∮", "partial": "∂", "nabla": "∇", "lim": "lim",
        // 도형 기호 (앱 표기는 GeometryText): 합동 \cong → ≡, 닮음 \backsim → ∽, 평행 \| → ∥
        "cong": "≡", "backsim": "∽", "thicksim": "∽", "frown": "⌒", "smallfrown": "⌒", "bot": "⊥", "measuredangle": "∠",
        "bigtriangleup": "△", "vartriangle": "△", "triangleup": "△", "|": "∥", "shortparallel": "∥", "varpi": "π",
        "%": "%", "{": "{", "}": "}", "_": "_", "&": "&", "#": "#", "$": "$",
        "quad": " ", "qquad": " ", ",": " ", ";": " ", ":": " ", ">": " ", "!": "", " ": " ", "enspace": " ", "thinspace": " ",
        "lbrace": "{", "rbrace": "}", "langle": "⟨", "rangle": "⟩", "vert": "|", "mid": "|", "lvert": "|", "rvert": "|",
        "\\": "\n", "newline": "\n", "colon": ":",
    ]
    /// 글자만 남기는 명령 (\text{…} → …)
    static let keepArgument: Set<String> = ["text", "mathrm", "mathbf", "textbf", "mathit", "textit", "operatorname", "boldsymbol",
                                            "mbox", "textrm", "mathsf", "mathtt", "texttt", "bm", "mathbb", "mathcal", "hbox", "textnormal",
                                            "widehat", "hat", "vec", "overrightarrow", "displaylines"]
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
        // 수식 구분 기호 (지움: "2\\(\\sqrt{2}\\)" → "2√2")
        for d in ["$$", "\\[", "\\]", "\\(", "\\)"] { s = s.replacingOccurrences(of: d, with: "") }
        s = s.replacingOccurrences(of: #"(?<!\\)\$"#, with: "", options: .regularExpression)
        // HTML 위·아래 첨자: 2<sup>5</sup> → 2^5
        s = s.replacingOccurrences(of: #"<sup>\s*2\s*</sup>"#, with: "²", options: .regularExpression)
        s = s.replacingOccurrences(of: #"<sup>\s*3\s*</sup>"#, with: "³", options: .regularExpression)
        s = s.replacingOccurrences(of: #"<sup>\s*([^<]*?)\s*</sup>"#, with: "^$1", options: .regularExpression)
        s = s.replacingOccurrences(of: #"</?sub>"#, with: "", options: .regularExpression)
        s = s.replacingOccurrences(of: #"\\begin\{[a-z*]+\}(\{[^}]*\})?|\\end\{[a-z*]+\}"#, with: " ", options: .regularExpression)
        var chars = Array(s)
        var i = 0
        let result = parse(&chars, &i, stopAtBrace: false)
        let flat = result.replacingOccurrences(of: #"[ \t]{2,}"#, with: " ", options: .regularExpression)
            .replacingOccurrences(of: "&", with: " ")
            .trimmingCharacters(in: .whitespaces)
        // 도형 기호를 앱 표기로 (△ ABC → △ABC, △ABC ~ △DEF → ∽, 호 호 AB → 호 AB)
        return GeometryText.canonical(flat).replacingOccurrences(of: #"호\s+호\s+"#, with: "호 ", options: .regularExpression)
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
                // 큰 기호 ∑ ∫ ∏ lim 의 위끝·아래끝은 식 모양을 그대로: ∑_{k=1}^{n}, ∫_a^b, lim_{x→a}
                let operatorTail = out.range(of: #"(?:∑|∫|∏|∮|lim)(?:_(?:\{[^}]*\}|[^{}\s]))?$"#, options: .regularExpression) != nil
                if operatorTail {
                    let a = arg.trimmingCharacters(in: .whitespaces).replacingOccurrences(of: " ", with: "")
                    if !a.isEmpty {
                        out += (ch == "^" ? "^" : "_") + (a.count <= 1 ? a : "{\(a)}")
                        continue
                    }
                }
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
        // 선분 \overline{AB} → A̅B̅ (꼭짓점 두 글자일 때만, 순환소수·켤레 같은 다른 윗줄은 글자만)
        case "overline", "bar", "widebar", "overbar":
            let a = argument(&c, &i)
            let letters = a.filter { !$0.isWhitespace }
            return letters.count == 2 && letters.allSatisfy({ $0.isASCII && $0.isUppercase }) && Set(letters).count == 2 ? GeometryText.segment(letters) : a
        // 호 \overset{\frown}{AB}, \wideparen{AB} → 호 AB
        case "overset", "stackrel", "overunderset":
            let top = argument(&c, &i), bottom = argument(&c, &i)
            return top.contains("⌒") || top.contains("frown") || top.contains("smile") ? "호 " + bottom.trimmingCharacters(in: .whitespaces) : bottom
        case "wideparen", "overarc", "arc", "overparen", "overgroup":
            return "호 " + argument(&c, &i).trimmingCharacters(in: .whitespaces)
        // 사각형 \square ABCD → 사각형 ABCD (□ 뒤에 꼭짓점 넷이 없으면 빈칸 □)
        case "square", "Box", "Square":
            var j = i
            while j < c.count, c[j] == " " { j += 1 }
            let next = c[j..<min(c.count, j + 5)]
            if next.count >= 4, next.prefix(4).allSatisfy({ $0.isASCII && $0.isUppercase }), next.count == 4 || !next.last!.isLetter {
                i = j
                return "사각형 "
            }
            return "□"
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

    // MARK: 앱에 넘길 글 (비교 실험의 "app" 방법과 같은 단계)

    /// 수학 문제: LaTeX → 앱 글 모양 → 수식 글자 교정 (Vision 경로와 같은 MathOCRFixer.fix)
    static func mathText(_ raw: String) -> String {
        MathOCRFixer.fix(toApp(raw)).trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// 수학이 아닌 과목: LaTeX → 앱 글 모양 → 보기 번호만 정리 (Vision 경로의 subjectText와 같은 단계)
    static func subjectText(_ raw: String) -> String {
        MathOCRFixer.cleanChoiceMarks(MathOCRFixer.normalizeChoices(toApp(raw))).trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// 쓸 만한 결과인지 (비었거나 글자·숫자가 거의 없으면 Vision으로 다시 읽음)
    static func isUsable(_ text: String) -> Bool {
        text.filter { $0.isLetter || $0.isNumber }.count >= 2
    }
}
