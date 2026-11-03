import Foundation

// MARK: - 도형 기호: 앱 표기(GeometryText), 정밀 인식 LaTeX 변환, 사진 글자 교정, 도형 문제 풀이

func runGeometryCases() {
    let ab = GeometryText.segment("AB"), bc = GeometryText.segment("BC"), ac = GeometryText.segment("AC")
    let de = GeometryText.segment("DE"), cd = GeometryText.segment("CD")

    // 앱 표기 맞추기
    let canonical: [(String, String)] = [
        ("AB\u{305} = 6", "\(ab) = 6"),                 // 윗줄 한 글자 → 두 글자
        ("A\u{305}B = 6", "\(ab) = 6"),
        ("A\u{304}B\u{304}의 길이", "\(ab)의 길이"),      // 마크론 → 윗줄
        ("z\u{304} = 3 - 4i", "z\u{304} = 3 - 4i"),      // 켤레복소수는 그대로
        ("ΔABC에서", "△ABC에서"),
        ("△ ABC ≅ △ DEF", "△ABC ≡ △DEF"),
        ("△ABC ~ △DEF", "△ABC ∽ △DEF"),
        ("∠ ABC = 90°", "∠ABC = 90°"),
        ("□ABCD는 평행사변형", "사각형 ABCD는 평행사변형"),
        ("3 + □ = 7", "3 + □ = 7"),                       // 빈칸 □는 그대로
        ("□ 안에 알맞은 수", "□ 안에 알맞은 수"),
        ("l // m", "l ∥ m"),
        ("\(de) // \(bc)", "\(de) ∥ \(bc)"),
        ("http://a.com", "http://a.com"),
        ("⌒AB에 대한 원주각", "호 AB에 대한 원주각"),
        ("x ~ y", "x ~ y"),
    ]
    for (input, expected) in canonical {
        let out = GeometryText.canonical(input)
        check("도형 표기: \(input)", out == expected, out)
    }
    check("도형 표기: 풀이용은 윗줄 지움", GeometryText.forSolver("\(ab) = 6, \(bc) = 8") == "AB = 6, BC = 8", GeometryText.forSolver("\(ab) = 6"))

    // 정밀 인식 LaTeX → 앱 표기
    let latex: [(String, String)] = [
        ("\\(\\overline{AB} = 6\\)", "\(ab) = 6"),
        ("\\(\\overline{\\mathrm{AB}}\\)의 길이", "\(ab)의 길이"),
        ("\\(\\bar{z}\\)", "z"),                                      // 켤레·순환소수 윗줄은 예전처럼 글자만
        ("\\(0.\\overline{3}\\)", "0.3"),
        ("\\(\\angle A = 50^{\\circ}\\)", "∠A = 50°"),
        ("\\(\\angle ABC=90^\\circ\\)", "∠ABC=90°"),
        ("\\(\\triangle ABC\\)에서", "△ABC에서"),
        ("\\(\\overline{AB} \\perp \\overline{CD}\\)", "\(ab) ⊥ \(cd)"),
        ("\\(l \\parallel m\\)", "l ∥ m"),
        ("\\(\\overline{DE} \\| \\overline{BC}\\)", "\(de) ∥ \(bc)"),
        ("\\(\\triangle ABC \\equiv \\triangle DEF\\)", "△ABC ≡ △DEF"),
        ("\\(\\triangle ABC \\cong \\triangle DEF\\)", "△ABC ≡ △DEF"),
        ("\\(\\triangle ABC \\sim \\triangle DEF\\)", "△ABC ∽ △DEF"),
        ("\\(\\triangle ABC \\backsim \\triangle DEF\\)", "△ABC ∽ △DEF"),
        ("\\(\\overset{\\frown}{AB}\\)에 대한 원주각", "호 AB에 대한 원주각"),
        ("호 \\(\\wideparen{AB}\\)의 길이", "호 AB의 길이"),
        ("\\(\\square ABCD\\)는 마름모", "사각형 ABCD는 마름모"),
        ("\\(3 + \\square = 7\\)", "3 + □ = 7"),
        ("\\(2\\pi r\\)", "2π r"),
        ("\\(x^{\\circ}\\)", "x°"),
    ]
    for (input, expected) in latex {
        let out = PaddleOCRText.toApp(input)
        check("도형 LaTeX: \(input)", out == expected, out)
    }
    let paddle = PaddleOCRText.mathText("1. \\(\\triangle ABC\\)에서 \\(\\angle A = 50^{\\circ}\\), \\(\\angle B = 60^{\\circ}\\)일 때, \\(\\angle C\\)의 크기는?")
    check("도형 LaTeX: 앱 글 (교정까지)", paddle == "1. △ABC에서 ∠A = 50°, ∠B = 60°일 때, ∠C의 크기는?", paddle)

    // 사진 글자 교정 (Vision이 다르게 읽은 도형 기호)
    let ocr: [(String, String)] = [
        ("LABC = 90°일 때", "∠ABC = 90°일 때"),
        ("삼각형 ABC에서 ZABC의 크기", "삼각형 ABC에서 ∠ABC의 크기"),
        ("<ABC = 35°", "∠ABC = 35°"),
        ("ZA = 50°, ZB = 60°일 때, ZC의 크기는?", "∠A = 50°, ∠B = 60°일 때, ∠C의 크기는?"),
        ("AABC에서 LA = 50°", "△ABC에서 ∠A = 50°"),
        ("4ABC에서 ∠A = 50°", "△ABC에서 ∠A = 50°"),
        ("ΔABC의 넓이", "△ABC의 넓이"),
        ("Zx의 크기를 구하시오. (단, l ∥ m)", "∠x의 크기를 구하시오. (단, l ∥ m)"),
        ("Lx + Ly = 130°", "∠x + ∠y = 130°"),
        ("∠A = 30o, ∠B = 70o일 때", "∠A = 30°, ∠B = 70°일 때"),
        ("세 내각의 크기가 x°, 2x°, 3x°일 때", "세 내각의 크기가 x°, 2x°, 3x°일 때"),
        ("l // m일 때, ∠x의 크기", "l ∥ m일 때, ∠x의 크기"),
        ("l ll m일 때, ∠x의 크기", "l ∥ m일 때, ∠x의 크기"),
        ("∠B = 90°, AB = 6, BC = 8일 때 AC의 길이", "∠B = 90°, \(ab) = 6, \(bc) = 8일 때 \(ac)의 길이"),
        ("AB = AC인 이등변삼각형 ABC", "\(ab) = \(ac)인 이등변삼각형 ABC"),
        ("△ABC에서 DE // BC이고", "△ABC에서 \(de) ∥ \(bc)이고"),
        ("선분 AB의 길이와 직선 CD", "선분 AB의 길이와 직선 CD"),     // "선분", "직선" 뒤는 그대로
        ("□ABCD는 평행사변형이다.", "사각형 ABCD는 평행사변형이다."),
    ]
    for (input, expected) in ocr {
        let out = MathOCRFixer.fix(input)
        check("도형 사진 교정: \(input)", out == expected, out)
    }
    // 도형이 아닌 글은 그대로 (지수 x°→x², 1O → 10, Zx → 2x 같은 기존 교정 유지)
    let plain: [(String, String)] = [
        ("x° + 3x + 2 = 0", "x² + 3x + 2 = 0"),
        ("Zx + 3 = 7", "2x + 3 = 7"),
        ("집합 A, B에서 AB", "집합 A, B에서 AB"),
        ("3 + □ = 7", "3 + □ = 7"),
        ("x = 1O + 2", "x = 10 + 2"),
    ]
    for (input, expected) in plain {
        let out = MathOCRFixer.fix(input)
        check("도형 아닌 글 그대로: \(input)", out == expected, out)
    }

    // 도형 문제 풀이 (앱 표기 그대로 넣음) — 틀린 답은 안 되고, 모르면 nil
    let solve: [(String, String)] = [
        ("△ABC에서 ∠A = 50°, ∠B = 60°일 때 ∠C의 크기를 구하시오.", "70°"),
        ("\(ab) = 6, \(bc) = 8, ∠B = 90°일 때 \(ac)의 길이를 구하시오.", "10"),
        ("∠C = 90°인 직각삼각형 ABC에서 \(ab) = 13, \(bc) = 5일 때, \(ac)의 길이는?", "12"),
        ("\(ab) = \(ac)인 이등변삼각형 ABC에서 ∠A = 40°일 때, ∠B의 크기는?", "70°"),
        ("△ABC에서 ∠A : ∠B : ∠C = 2 : 3 : 4일 때, ∠C의 크기는?", "80°"),
        ("△ABC에서 ∠A = 45°, ∠B = 70°일 때, ∠C의 외각의 크기는?", "115°"),
        ("원 O에서 중심각 ∠AOB = 100°일 때, 원주각 ∠APB의 크기는?", "50°"),
        ("육각형의 내각의 크기의 합은?", "720°"),
        ("△ABC ∽ △DEF이고 \(ab) = 4, \(de) = 6, \(bc) = 6일 때, \(GeometryText.segment("EF"))의 길이는?", "9"),
        ("△ABC에서 \(de) ∥ \(bc)이고 \(GeometryText.segment("AD")) = 4, \(GeometryText.segment("DB")) = 2, \(GeometryText.segment("AE")) = 6일 때, \(GeometryText.segment("EC"))의 길이는?", "3"),
        ("△ABC에서 \(ab) = 8, \(ac) = 6, ∠A = 30°일 때, △ABC의 넓이는?", "12"),
        ("닮음비가 2 : 3인 두 삼각형의 넓이의 비는?", "4 : 9"),
        ("삼각형의 세 내각의 크기가 x°, 2x°, 3x°일 때, x의 값은?", "30"),
        ("\(ab) ⊥ \(bc)인 삼각형 ABC에서 \(ab) = 3, \(bc) = 4일 때 \(ac)의 길이는?", "5"),
        ("이등변삼각형 ABC에서 \(ab) = \(ac)이고 ∠B = 65°일 때 ∠A의 크기는?", "50°"),
        ("△ABC ≡ △DEF이고 \(ab) = 5일 때 \(de)의 길이는?", "5"),
        ("△ABC ≡ △DEF이고 ∠A = 50°, ∠B = 60°일 때 ∠F의 크기는?", "70°"),
        ("□ABCD는 평행사변형이다. ∠A = 110°일 때, ∠B의 크기는?", "70°"),
        ("사각형 ABCD는 평행사변형이다. ∠A = 110°일 때, ∠C의 크기는?", "110°"),
        ("l ∥ m이고 ∠a와 ∠b는 동위각이다. ∠a = 65°일 때 ∠b의 크기는?", "65°"),
        ("∠x와 ∠y는 맞꼭지각이고 ∠x = 40°일 때, ∠y의 크기는?", "40°"),
        ("원 O에서 호 AB에 대한 원주각의 크기가 30°일 때, 중심각의 크기는?", "60°"),
        ("반지름의 길이가 3인 원의 넓이는?", "9π(≈28.2743)"),
        ("l ∥ m일 때 동위각 ∠a = 65°이면 ∠b의 크기는?", ""),       // 두 각의 관계를 글로 안 밝힘 → nil
        ("다음 그림에서 l ∥ m일 때, ∠x의 크기를 구하시오.", ""),       // 그림이 필요 → nil
        ("△ABC에서 ∠A = 50°, ∠B = 60°", ""),                           // 물음 없음 → nil
    ]
    for (input, expected) in solve {
        let answer = MathSolver.solve(input)?.answer
        if expected.isEmpty {
            check("도형 풀이 (모르면 안 풂): \(input)", answer == nil, answer ?? "nil")
        } else {
            let flat = answer.map { $0.replacingOccurrences(of: " ", with: "").replacingOccurrences(of: #"^[a-z]="#, with: "", options: .regularExpression) }
            check("도형 풀이: \(input)", flat == expected.replacingOccurrences(of: " ", with: ""), answer ?? "nil")
        }
    }
    // 객관식 (앱처럼 DoitAutoSolve로): 보기 번호
    let choiceProblems: [(String, String)] = [
        ("1. △ABC에서 ∠A = 50°, ∠B = 60°일 때, ∠C의 크기는?\n① 60° ② 70° ③ 80° ④ 90° ⑤ 100°", "2"),
        ("2. 직각삼각형 ABC에서 ∠B = 90°, \(ab) = 6, \(bc) = 8일 때, \(ac)의 길이는?\n① 8 ② 9 ③ 10 ④ 11 ⑤ 12", "3"),
        ("9. 원 O에서 중심각 ∠AOB = 100°일 때, 원주각 ∠APB의 크기는?\n① 40° ② 50° ③ 60° ④ 80° ⑤ 100°", "2"),
    ]
    for (text, expected) in choiceProblems {
        let scan = DoitProblemScan.scan(text)
        let solution = DoitAutoSolve.engine(text: text, choices: scan.choices, isChoice: scan.choices.count >= 2, body: scan.body)
        let n = solution.flatMap { DoitGrader.choiceNumber($0.finalAnswer, choices: scan.choices) }
        check("도형 객관식: \(text.prefix(30))", n.map(String.init) == expected, "\(solution?.finalAnswer ?? "nil") / 보기 \(scan.choices)")
    }
}
