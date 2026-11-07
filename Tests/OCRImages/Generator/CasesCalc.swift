import CoreGraphics
import Foundation

// 미적분·고등 수학 기호 문제: ∑(위끝·아래끝 쌓음), ∫(위끝·아래끝), lim(아래 x→a), f′(x), d/dx, √, e^x, ln, sin·cos, |x|, ≤ ≥ ≠, π, ∞, →, aₙ, ₙCᵣ
// 기대하는 글은 앱 표기: ∑_{k=1}^{n}, ∫_a^b, lim_{x→a}, f′(x), aₙ → a_n (띄어쓰기·중괄호는 무시, ";"는 같은 뜻의 다른 표기)

func K(_ cls: String, _ text: String) -> CalcToken { CalcToken(cls: cls, text: text) }

func sigma(_ below: String, _ above: String, stacked: Bool = true) -> Seg { .bigOp("∑", below: below, above: above, stacked: stacked) }
func integral(_ below: String, _ above: String) -> Seg { .bigOp("∫", below: below, above: above, stacked: false) }
/// 함수 이름 (바른 글꼴)
func fn(_ s: String) -> Seg { .e(s) }

func calcProblem(_ id: String, number: String?, body: [[Seg]], choices: [[Seg]] = [], layout: ChoiceLayout = .row5,
                 calc: [CalcToken], phrases: [String] = []) -> Content {
    var c = problem(id, "math-calc", number: number, body: body, choices: choices, layout: layout, phrases: phrases, checkChoices: true)
    c.expect.calc = calc
    return c
}

let calculusContents: [Content] = [
    // ---- ∑ (시그마) ----
    calcProblem("calc-sig-disp", number: "1.", body: [[.t("다음 값을 구하시오.")], [sigma("k=1", "10"), .m(" (2k + 1)")]],
                calc: [K("∑", "∑"), K("∑범위", "∑_{k=1}^{10}"), K("식", "∑_{k=1}^{10}(2k+1)")], phrases: ["값을구하시오"]),
    calcProblem("calc-sig-sq", number: "2.", body: [[.t("자연수 "), .m("n"), .t("에 대하여 "), sigma("k=1", "n"), .m(" k"), .sup("2"), .t("의 값은?")]],
                choices: [[.frac("n(n + 1)", "2")], [.frac("n(n + 1)(2n + 1)", "6")], [.frac("n(n + 1)", "6")], [.m("n"), .sup("2")], [.m("2n + 1")]],
                calc: [K("∑", "∑"), K("∑범위", "∑_{k=1}^{n}"), K("식", "∑_{k=1}^{n}k^2")], phrases: ["자연수n에대하여"]),
    calcProblem("calc-sig-seq", number: "3.", body: [[.t("수열 "), .m("{a"), .subm("n"), .m("}"), .t("의 일반항이 "), .m("a"), .subm("n"), .m(" = 2n − 1"), .t("일 때,")],
                                                  [sigma("k=1", "10"), .m(" a"), .subm("k"), .t("의 값을 구하시오.")]],
                calc: [K("∑", "∑"), K("∑범위", "∑_{k=1}^{10}"), K("_", "a_n=2n-1"), K("식", "∑_{k=1}^{10}a_k")], phrases: ["값을구하시오"]),
    calcProblem("calc-sig-frac", number: "4.", body: [[sigma("k=1", "9"), .frac("1", "k(k + 1)"), .t("의 값은?")]],
                choices: [[.frac("8", "9")], [.frac("9", "10")], [.frac("10", "11")], [.frac("1", "10")], [.m("1")]],
                calc: [K("∑", "∑"), K("∑범위", "∑_{k=1}^{9}"), K("분수", "1/(k(k+1))")]),
    calcProblem("calc-sig-two", number: "5.", body: [[sigma("k=1", "5"), .m(" (3k − 1) − "), sigma("k=1", "5"), .m(" k"), .t("의 값을 구하시오.")]],
                calc: [K("∑", "∑"), K("∑", "∑"), K("∑범위", "∑_{k=1}^{5}"), K("∑범위", "∑_{k=1}^{5}"), K("식", "∑_{k=1}^{5}(3k-1)-∑_{k=1}^{5}k")]),
    calcProblem("calc-sig-side", number: "6.", body: [[.t("다음 합을 구하시오.")], [sigma("k=1", "n", stacked: false), .m(" (2k − 1)")]],
                calc: [K("∑", "∑"), K("∑범위", "∑_{k=1}^{n}"), K("식", "∑_{k=1}^{n}(2k-1)")]),
    calcProblem("calc-sig-inf", number: "7.", body: [[.t("무한급수 "), sigma("n=1", "∞"), .m(" 1"), .t("/"), .m("2"), .sup("n"), .t("의 합은?")]],
                choices: ints(["1/2", "1", "2", "3", "∞"]),
                calc: [K("∑", "∑"), K("∑범위", "∑_{n=1}^{∞}"), K("∞", "∞")]),
    calcProblem("calc-sig-an", number: "8.", body: [[.t("수열 "), .m("{a"), .subm("n"), .m("}"), .t("에서 "), .m("a"), .subm("n+1"), .m(" = 2a"), .subm("n"), .m(" + 1, a"), .subm("1"), .m(" = 1"), .t("일 때, "), .m("a"), .subm("4"), .t("의 값은?")]],
                choices: ints(["7", "11", "15", "23", "31"]),
                calc: [K("_", "a_{n+1}=2a_n+1"), K("_", "a_1=1"), K("_", "a_4")]),
    calcProblem("calc-sn", number: "9.", body: [[.t("수열 "), .m("{a"), .subm("n"), .m("}"), .t("의 첫째항부터 제 "), .m("n"), .t("항까지의 합이 "), .m("S"), .subm("n"), .m(" = n"), .sup("2"), .m(" + 2n"), .t("일 때, "), .m("a"), .subm("5"), .t("의 값은?")]],
                choices: ints(["9", "11", "13", "15", "35"]),
                calc: [K("_", "S_n=n^2+2n"), K("_", "a_5"), K("^", "n^2")]),

    // ---- lim (극한) ----
    calcProblem("calc-lim-rat", number: "10.", body: [[.lim("x→2"), .frac("x² − 4", "x − 2"), .t("의 값을 구하시오.")]],
                calc: [K("lim", "lim"), K("lim아래", "lim_{x→2}"), K("→", "→"), K("식", "lim_{x→2}(x²-4)/(x-2)")], phrases: ["값을구하시오"]),
    calcProblem("calc-lim-inf", number: "11.", body: [[.lim("x→∞"), .frac("2x² + 1", "x² − 3"), .t("의 값은?")]],
                choices: ints(["0", "1", "2", "3", "∞"]),
                calc: [K("lim", "lim"), K("lim아래", "lim_{x→∞}"), K("∞", "∞"), K("→", "→"), K("식", "lim_{x→∞}(2x²+1)/(x²-3)")]),
    calcProblem("calc-lim-sin", number: "12.", body: [[.lim("x→0"), .frac("sin 3x", "x"), .t("의 값은?")]],
                choices: ints(["1", "2", "3", "4", "5"]),
                calc: [K("lim", "lim"), K("lim아래", "lim_{x→0}"), K("삼각", "sin3x"), K("식", "lim_{x→0}(sin3x)/x")]),
    calcProblem("calc-lim-n", number: "13.", body: [[.lim("n→∞"), .frac("3n + 1", "n + 2"), .t("의 값을 구하시오.")]],
                calc: [K("lim", "lim"), K("lim아래", "lim_{n→∞}"), K("∞", "∞"), K("식", "lim_{n→∞}(3n+1)/(n+2)")]),
    calcProblem("calc-lim-inline", number: "14.", body: [[.t("함수 "), .m("f(x)"), .t("가 "), .lim("x→1"), .m(" f(x) = 3"), .t("일 때, "), .lim("x→1"), .m(" 2f(x)"), .t("의 값은?")]],
                choices: ints(["1", "3", "4", "6", "9"]),
                calc: [K("lim", "lim"), K("lim", "lim"), K("lim아래", "lim_{x→1}"), K("lim아래", "lim_{x→1}"), K("식", "lim_{x→1}f(x)=3")]),
    calcProblem("calc-lim-right", number: "15.", body: [[.lim("x→0+"), .m(" f(x) = 2"), .t("이고 "), .lim("x→0−"), .m(" f(x) = −1"), .t("일 때,")], [.t("옳은 것은?")]],
                choices: [[.t("극한값이 존재한다.")], [.t("극한값이 존재하지 않는다.")], [.t("연속이다.")], [.t("미분가능하다.")], [.t("알 수 없다.")]], layout: .stack,
                calc: [K("lim", "lim"), K("lim", "lim"), K("lim아래", "lim_{x→0+}"), K("lim아래", "lim_{x→0-}")]),
    calcProblem("calc-lim-sqrt", number: "16.", body: [[.lim("x→0"), .frac("√(x + 4) − 2", "x"), .t("의 값을 구하시오.")]],
                calc: [K("lim", "lim"), K("lim아래", "lim_{x→0}"), K("√", "√(x+4)"), K("식", "lim_{x→0}(√(x+4)-2)/x")]),

    // ---- 미분: f′(x), d/dx ----
    calcProblem("calc-d-prime", number: "17.", body: [[.m("f(x) = x"), .sup("3"), .m(" − 3x"), .sup("2"), .m(" + 2"), .t("일 때, "), .m("f′(2)"), .t("의 값은?")]],
                choices: ints(["0", "2", "4", "6", "8"]),
                calc: [K("′", "f′(2)"), K("^", "x^3"), K("^", "x^2")]),
    calcProblem("calc-d-prime2", number: "18.", body: [[.t("함수 "), .m("f(x) = x"), .sup("2"), .m("e"), .sup("x"), .t("에 대하여 "), .m("f′(0)"), .t("의 값을 구하시오.")]],
                calc: [K("′", "f′(0)"), K("e^x", "e^x"), K("^", "x^2")]),
    calcProblem("calc-d-def", number: "19.", body: [[.m("f′(a) = "), .lim("h→0"), .frac("f(a + h) − f(a)", "h")], [.t("를 이용하여 "), .m("f(x) = x"), .sup("2"), .t("의 "), .m("x = 1"), .t("에서의 미분계수를 구하시오.")]],
                calc: [K("′", "f′(a)"), K("lim", "lim"), K("lim아래", "lim_{h→0}"), K("→", "→"), K("식", "f′(a)=lim_{h→0}(f(a+h)-f(a))/h")]),
    calcProblem("calc-d-ddx", number: "20.", body: [[.frac("d", "dx"), .m(" (x"), .sup("3"), .m(" + 3x) ="), .t("  ?")]],
                choices: [[.m("3x"), .sup("2"), .m(" + 3")], [.m("x"), .sup("2"), .m(" + 3")], [.m("3x + 3")], [.m("x"), .sup("3"), .m(" + 3")], [.m("3x"), .sup("2")]],
                calc: [K("d/dx", "d/dx;d/(dx);(d)/(dx)"), K("^", "x^3")]),
    calcProblem("calc-d-dydx", number: "21.", body: [[.m("y = x"), .sup("2"), .m(" ln x"), .t("일 때, "), .frac("dy", "dx"), .t("를 구하시오.")]],
                calc: [K("d/dx", "dy/dx;(dy)/(dx)"), K("ln", "ln"), K("^", "x^2")]),
    calcProblem("calc-d-tan", number: "22.", body: [[.t("곡선 "), .m("y = x"), .sup("3"), .m(" − 2x"), .t("위의 점 "), .m("(1, −1)"), .t("에서의 접선의 기울기는? ("), .m("y′"), .t("을 이용)")]],
                choices: ints(["−2", "−1", "0", "1", "2"]),
                calc: [K("′", "y′"), K("^", "x^3")]),

    // ---- ∫ (적분) ----
    calcProblem("calc-i-def", number: "23.", body: [[.t("정적분 "), integral("0", "1"), .m(" x"), .sup("2"), .m(" dx"), .t("의 값은?")]],
                choices: [[.frac("1", "3")], [.frac("1", "2")], [.frac("2", "3")], [.m("1")], [.frac("4", "3")]],
                calc: [K("∫", "∫"), K("∫범위", "∫_0^1"), K("식", "∫_0^1x^2dx"), K("^", "x^2")]),
    calcProblem("calc-i-e", number: "24.", body: [[integral("1", "e"), .frac("1", "x"), .m(" dx"), .t("의 값을 구하시오.")]],
                calc: [K("∫", "∫"), K("∫범위", "∫_1^e"), K("식", "∫_1^e1/xdx")]),
    calcProblem("calc-i-neg", number: "25.", body: [[integral("−1", "2"), .m(" (3x"), .sup("2"), .m(" + 2x) dx"), .t("의 값은?")]],
                choices: ints(["6", "8", "10", "12", "14"]),
                calc: [K("∫", "∫"), K("∫범위", "∫_{-1}^2"), K("식", "∫_{-1}^2(3x^2+2x)dx")]),
    calcProblem("calc-i-pi", number: "26.", body: [[integral("0", "π"), .e(" sin"), .m(" x dx"), .t("의 값을 구하시오.")]],
                calc: [K("∫", "∫"), K("∫범위", "∫_0^π"), K("π", "π"), K("삼각", "sin"), K("식", "∫_0^π sin x dx")]),
    calcProblem("calc-i-indef", number: "27.", body: [[.t("부정적분 "), .bigOp("∫", below: "", above: "", stacked: false), .m(" (2x + 1) dx"), .t("를 구하시오.")]],
                calc: [K("∫", "∫"), K("식", "∫(2x+1)dx")]),
    calcProblem("calc-i-fun", number: "28.", body: [[.m("f(x) = "), integral("0", "x"), .m(" (t"), .sup("2"), .m(" + 1) dt"), .t("일 때, "), .m("f′(1)"), .t("의 값은?")]],
                choices: ints(["0", "1", "2", "3", "4"]),
                calc: [K("∫", "∫"), K("∫범위", "∫_0^x"), K("′", "f′(1)"), K("식", "f(x)=∫_0^x(t^2+1)dt")]),
    calcProblem("calc-i-abs", number: "29.", body: [[integral("−2", "2"), .m(" |x| dx"), .t("의 값은?")]],
                choices: ints(["0", "2", "4", "6", "8"]),
                calc: [K("∫", "∫"), K("∫범위", "∫_{-2}^2"), K("|x|", "|x|"), K("식", "∫_{-2}^2|x|dx")]),
    calcProblem("calc-i-exp", number: "30.", body: [[.t("곡선 "), .m("y = e"), .sup("x"), .t("과 "), .m("x"), .t("축, "), .m("x = 0, x = 1"), .t("로 둘러싸인 넓이를")], [.t("정적분으로 나타내면 "), integral("0", "1"), .m(" e"), .sup("x"), .m(" dx"), .t("이다. 그 값은?")]],
                choices: [[.m("e")], [.m("e − 1")], [.m("e + 1")], [.m("1")], [.m("2e")]],
                calc: [K("e^x", "e^x"), K("∫", "∫"), K("∫범위", "∫_0^1"), K("식", "∫_0^1e^xdx")]),

    // ---- √ · 로그 · 삼각 · 절댓값 · 부등호 · 조합 ----
    calcProblem("calc-sqrt", number: "31.", body: [[.t("함수 "), .m("f(x) = "), .sqrt("x + 1"), .t("의 "), .m("x = 3"), .t("에서의 미분계수는?")]],
                choices: [[.frac("1", "4")], [.frac("1", "2")], [.m("1")], [.sqrt("2")], [.m("2")]],
                calc: [K("√", "√x+1;√(x+1)")]),
    calcProblem("calc-log", number: "32.", body: [[.e("log"), .subm("2"), .m(" 8 + ln e"), .sup("2"), .t("의 값을 구하시오.")]],
                calc: [K("ln", "ln"), K("log", "log_2;log₂"), K("^", "e^2")]),
    calcProblem("calc-trig", number: "33.", body: [[.e("sin"), .sup("2"), .m("θ + "), .e("cos"), .sup("2"), .m("θ = 1"), .t("이고 "), .e("sin"), .m(" θ = "), .frac("3", "5"), .t("일 때, "), .e("cos"), .m(" θ"), .t("의 값을 구하시오. (단, "), .m("0 < θ < π/2"), .t(")")]],
                calc: [K("삼각", "sin"), K("삼각", "cos"), K("θ", "θ"), K("π", "π"), K("^", "sin^2θ+cos^2θ=1")]),
    calcProblem("calc-abs", number: "34.", body: [[.m("|x − 2| ≤ 3"), .t("을 만족하는 정수 "), .m("x"), .t("의 개수는?")]],
                choices: ints(["4", "5", "6", "7", "8"]),
                calc: [K("|x|", "|x-2|"), K("≤≥≠", "≤"), K("식", "|x-2|≤3")]),
    calcProblem("calc-neq", number: "35.", body: [[.m("f(x) = "), .frac("x² − 1", "x − 1"), .m(" (x ≠ 1)"), .t("가 "), .m("x = 1"), .t("에서 연속이 되도록 "), .m("f(1)"), .t("의 값을 정하시오.")]],
                calc: [K("≤≥≠", "≠"), K("분수", "(x²-1)/(x-1)"), K("식", "f(x)=(x²-1)/(x-1)")]),
    calcProblem("calc-ge", number: "36.", body: [[.t("모든 실수 "), .m("x"), .t("에 대하여 "), .m("x"), .sup("2"), .m(" − 2x + a ≥ 0"), .t("이 성립하도록 하는 "), .m("a"), .t("의 최솟값은?")]],
                choices: ints(["−1", "0", "1", "2", "3"]),
                calc: [K("≤≥≠", "≥"), K("^", "x^2")]),
    calcProblem("calc-comb", number: "37.", body: [[.sub("5"), .m("C"), .sub("2"), .m(" + "), .sub("4"), .m("C"), .sub("1"), .t("의 값은?")]],
                choices: ints(["10", "12", "14", "16", "18"]),
                calc: [K("nCr", "₅C₂;5C2;_5C_2"), K("nCr", "₄C₁;4C1;_4C_1")]),
    calcProblem("calc-delta", number: "38.", body: [[.t("함수 "), .m("f(x) = x"), .sup("2"), .t("에서 "), .m("x"), .t("의 값이 1에서 3까지 변할 때의 평균변화율은? ("), .m("Δy"), .t("/"), .m("Δx"), .t(")")]],
                choices: ints(["2", "3", "4", "5", "6"]),
                calc: [K("Δ", "Δy"), K("Δ", "Δx"), K("^", "x^2")]),
    calcProblem("calc-lim-mix", number: "39.", body: [[.t("수열 "), .m("{a"), .subm("n"), .m("}"), .t("에 대하여 "), .lim("n→∞"), .m(" a"), .subm("n"), .m(" = 2"), .t("일 때, "), .lim("n→∞"), .m(" 3a"), .subm("n"), .t("의 값은?")]],
                calc: [K("lim", "lim"), K("lim", "lim"), K("lim아래", "lim_{n→∞}"), K("lim아래", "lim_{n→∞}"), K("_", "a_n=2")]),
]
