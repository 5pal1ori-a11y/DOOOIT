import SwiftUI

/// 문제 텍스트를 고칠 때 쓰는 수식 기호 바
struct MathSymbolBar: View {
    struct Symbol: Identifiable {
        let label: String
        let insert: String
        /// 넣은 뒤 커서를 둘 위치 (insert 기준 글자 수)
        let caretOffset: Int
        var id: String { label }

        init(_ label: String, _ insert: String? = nil, caret: Int? = nil) {
            self.label = label
            self.insert = insert ?? label
            self.caretOffset = caret ?? (insert ?? label).count
        }
    }

    var onInsert: (Symbol) -> Void

    static let symbols: [Symbol] = [
        Symbol("√", "√()", caret: 2),
        Symbol(L("분수"), "()/()", caret: 1),
        Symbol("x²", "²"),
        Symbol("x³", "³"),
        Symbol("xⁿ", "^()", caret: 2),
        Symbol("π"), Symbol("±"), Symbol("×"), Symbol("÷"),
        Symbol("≤"), Symbol("≥"), Symbol("≠"), Symbol("∞"),
        Symbol("|x|", "||", caret: 1),
        Symbol("θ"),
        // 도형 기호 (앱 표기는 GeometryText): 선분 윗줄은 앞에 쓴 두 글자 위에 붙음 (AB → A̅B̅)
        Symbol("°"), Symbol("∠"), Symbol("△"), Symbol("A̅B̅", GeometryText.overlineMark, caret: 0),
        Symbol("⊥"), Symbol("∥"), Symbol("≡"), Symbol("∽"), Symbol("호", "호 "), Symbol("□"),
        Symbol("①"), Symbol("②"), Symbol("③"), Symbol("④"), Symbol("⑤")
    ]

    /// 기호를 넣은 뒤 글 정리: 선분 윗줄을 두 글자 모두에 펼침 ("AB̅" → "A̅B̅", 글자 수는 그대로)
    static func tidy(_ text: String, after symbol: Symbol) -> String {
        symbol.insert == GeometryText.overlineMark ? GeometryText.spreadOverlines(text) : text
    }

    var body: some View {
        ScrollView(.horizontal) {
            HStack(spacing: 6) {
                ForEach(Self.symbols) { symbol in
                    Button { onInsert(symbol) } label: {
                        Text(symbol.label)
                            .font(.body.weight(.semibold))
                            .frame(minWidth: 40, minHeight: 36)
                            .padding(.horizontal, 4)
                            .background(Color.primary.opacity(0.06), in: .rect(cornerRadius: 10))
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(symbol.label)
                }
            }
            .padding(.vertical, 2)
        }
        .scrollIndicators(.hidden)
    }

    /// ^2 → ², sqrt( → √( 처럼 읽기 쉽게 바꿔서 보여주기
    static func pretty(_ text: String) -> String {
        let superscripts: [Character: Character] = ["0": "⁰", "1": "¹", "2": "²", "3": "³", "4": "⁴", "5": "⁵",
                                                    "6": "⁶", "7": "⁷", "8": "⁸", "9": "⁹", "n": "ⁿ", "-": "⁻", "+": "⁺"]
        // 도형 기호는 앱 표기로 (AB̅ → A̅B̅, △ ABC → △ABC, □ABCD → 사각형 ABCD, 선 이름 사이 // → ∥)
        var result = GeometryText.canonical(text).replacingOccurrences(of: "sqrt(", with: "√(")
        var output = ""
        var index = result.startIndex
        while index < result.endIndex {
            let ch = result[index]
            if ch == "^" {
                var next = result.index(after: index)
                if next < result.endIndex, result[next] == "(" {
                    var inner = ""
                    var cursor = result.index(after: next)
                    while cursor < result.endIndex, result[cursor] != ")" { inner.append(result[cursor]); cursor = result.index(after: cursor) }
                    if cursor < result.endIndex, inner.allSatisfy({ superscripts[$0] != nil }) {
                        output += String(inner.compactMap { superscripts[$0] })
                        index = result.index(after: cursor)
                        continue
                    }
                }
                var digits = ""
                while next < result.endIndex, let sup = superscripts[result[next]] {
                    digits.append(sup)
                    next = result.index(after: next)
                }
                if !digits.isEmpty {
                    output += digits
                    index = next
                    continue
                }
            }
            output.append(ch)
            index = result.index(after: index)
        }
        result = output
        return result
    }
}
