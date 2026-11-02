import Foundation

// MARK: - 한 사진에 문제 여러 개 자동 나누기 (ProblemSplitter)
// 테스트에서는 위에서부터 잰 top(원점 왼쪽 위)으로 적고, Vision 좌표(원점 왼쪽 아래)로 바꿔 넣음

/// 글자 상자 한 줄: x·top·너비는 페이지 비율
private func psLine(_ text: String, x: Double, top: Double, width: Double = 0.8, height: Double = 0.022) -> OCRLine {
    OCRLine(text: text, box: CGRect(x: x, y: 1 - top - height, width: width, height: height))
}

/// 문제 하나: 번호 줄 + 본문 줄들 (번호 줄 아래로 0.035씩)
private func psProblem(_ head: String, body: [String], x: Double, top: Double, width: Double, indent: Double = 0.03) -> [OCRLine] {
    var lines = [psLine(head, x: x, top: top, width: width)]
    for (i, text) in body.enumerated() {
        lines.append(psLine(text, x: x + indent, top: top + 0.035 * Double(i + 1), width: width - indent))
    }
    return lines
}

private func psNumbers(_ regions: [ProblemSplitter.Region]) -> [Int] { regions.map(\.number) }

private func psDescribe(_ regions: [ProblemSplitter.Region]) -> String {
    regions.map { r in
        let t = r.topLeftRect
        return String(format: "%d번 x %.3f~%.3f y %.3f~%.3f", r.number, Double(t.minX), Double(t.maxX), Double(t.minY), Double(t.maxY))
    }.joined(separator: " | ")
}

private func psNear(_ a: CGFloat, _ b: Double, _ tolerance: Double = 0.02) -> Bool { abs(Double(a) - b) <= tolerance }

func runProblemSplitCases() {
    let choices = "① 1   ② 2   ③ 3   ④ 4   ⑤ 5"

    // 1) 한 단 페이지에 문제 3개 (머리글 · 쪽 번호 포함)
    do {
        var lines = [psLine("Ⅰ. 다항식의 연산", x: 0.06, top: 0.03, width: 0.4)]
        lines += psProblem("1. 다음 식을 간단히 하시오.", body: ["(2x + 3) − (x − 1)", choices], x: 0.06, top: 0.10, width: 0.86)
        lines += psProblem("2. 다항식 A = x² + 1 일 때 2A를 구하시오.", body: ["2A = 2x² + 2", choices], x: 0.06, top: 0.40, width: 0.86)
        lines += psProblem("3. 다음 중 옳은 것은?", body: ["x³ · x² = x⁵", choices], x: 0.06, top: 0.70, width: 0.86)
        lines.append(psLine("23", x: 0.48, top: 0.96, width: 0.04))
        let regions = ProblemSplitter.regions(lines: lines)
        let d = psDescribe(regions)
        check("문제 나누기: 한 단 3문제", psNumbers(regions) == [1, 2, 3], d)
        if regions.count == 3 {
            let r = regions.map(\.topLeftRect)
            check("문제 나누기: 한 단 · 1번은 번호부터 2번 위까지", psNear(r[0].minY, 0.10) && psNear(r[0].maxY, 0.40), d)
            check("문제 나누기: 한 단 · 머리글은 빼고", r[0].minY > 0.06, d)
            check("문제 나누기: 한 단 · 단 너비 전체", r.allSatisfy { $0.minX <= 0.06 && $0.maxX >= 0.92 }, d)
            check("문제 나누기: 한 단 · 마지막 문제는 끝 글자까지 (쪽 번호 제외)",
                  r[2].maxY >= 0.70 + 0.035 * 2 + 0.022 && r[2].maxY < 0.92, d)
            check("문제 나누기: 한 단 · 영역끼리 거의 안 겹침", zip(r, r.dropFirst()).allSatisfy { $0.maxY <= $1.minY + 0.02 }, d)
            check("문제 나누기: Vision 좌표(아래 원점) ↔ 위 원점 변환",
                  regions.allSatisfy { psNear($0.box.maxY, 1 - Double($0.topLeftRect.minY), 0.0001) }, d)
        }
    }

    // 2) 두 단 페이지에 문제 4개 (왼쪽 단 01·02 → 오른쪽 단 03·04)
    do {
        var lines = [psLine("단원 마무리 문제", x: 0.05, top: 0.03, width: 0.9)]
        lines += psProblem("01 다음 중 일차방정식인 것은?", body: ["x + 1 = 3", choices], x: 0.06, top: 0.10, width: 0.40)
        lines += psProblem("02 방정식 3x − 2 = 7의 해는?", body: ["3x = 9", choices], x: 0.06, top: 0.50, width: 0.40)
        lines += psProblem("03 다음 그림에서 x의 값은?", body: ["2x + 10 = 40", choices], x: 0.54, top: 0.10, width: 0.40)
        lines += psProblem("04 어떤 수의 3배에서 5를 빼면", body: ["10이 된다. 어떤 수는?", choices], x: 0.54, top: 0.50, width: 0.40)
        lines.append(psLine("- 23 -", x: 0.47, top: 0.96, width: 0.06))
        let regions = ProblemSplitter.regions(lines: lines)
        let d = psDescribe(regions)
        check("문제 나누기: 두 단 4문제 (왼쪽 단 먼저)", psNumbers(regions) == [1, 2, 3, 4], d)
        if regions.count == 4 {
            let r = regions.map(\.topLeftRect)
            check("문제 나누기: 두 단 · 왼쪽 단은 가운데 넘지 않음", r[0].maxX <= 0.53 && r[1].maxX <= 0.53 && r[0].minX <= 0.06, d)
            check("문제 나누기: 두 단 · 오른쪽 단은 가운데부터 끝까지", r[2].minX >= 0.47 && r[2].minX <= 0.54 && r[3].maxX >= 0.94, d)
            check("문제 나누기: 두 단 · 01은 02 위까지", psNear(r[0].minY, 0.10) && psNear(r[0].maxY, 0.50), d)
            check("문제 나누기: 두 단 · 03은 04 위까지", psNear(r[2].minY, 0.10) && psNear(r[2].maxY, 0.50), d)
            check("문제 나누기: 두 단 · 아래 문제는 단 끝까지", r[1].maxY > 0.58 && r[3].maxY > 0.58 && r[3].maxY < 0.94, d)
        }
    }

    // 3) 두 단 · 왼쪽 3문제 / 오른쪽 2문제, 번호가 "1." 모양
    do {
        var lines: [OCRLine] = []
        lines += psProblem("1. 이차방정식 x² − 4 = 0의 해", body: [choices], x: 0.05, top: 0.06, width: 0.41)
        lines += psProblem("2. 근의 공식을 이용하여 푸시오.", body: ["x² + 3x + 1 = 0"], x: 0.05, top: 0.36, width: 0.41)
        lines += psProblem("3. 다음 이차방정식의 두 근의 합", body: [choices], x: 0.05, top: 0.66, width: 0.41)
        lines += psProblem("4. 판별식 D의 값은?", body: ["D = b² − 4ac"], x: 0.53, top: 0.06, width: 0.42)
        lines += psProblem("5. 서로 다른 두 실근을 가질 조건", body: [choices], x: 0.53, top: 0.46, width: 0.42)
        let regions = ProblemSplitter.regions(lines: lines)
        check("문제 나누기: 두 단 3+2문제", psNumbers(regions) == [1, 2, 3, 4, 5], psDescribe(regions))
    }

    // 4) 선택지 ①~⑤, 소문항 (1)(2), 1) 2)는 문제가 아님 (번호와 같은 왼쪽 끝에 있어도)
    do {
        var lines: [OCRLine] = []
        lines += psProblem("5. 다음 물음에 답하시오.", body: [], x: 0.06, top: 0.10, width: 0.86)
        lines.append(psLine("(1) x = 2일 때 식의 값", x: 0.06, top: 0.15, width: 0.6))
        lines.append(psLine("(2) x = −1일 때 식의 값", x: 0.06, top: 0.20, width: 0.6))
        lines.append(psLine("① 1", x: 0.06, top: 0.26, width: 0.1))
        lines.append(psLine("② 2", x: 0.06, top: 0.30, width: 0.1))
        lines.append(psLine("③ 3", x: 0.06, top: 0.34, width: 0.1))
        lines += psProblem("6. 다음을 계산하시오.", body: [], x: 0.06, top: 0.45, width: 0.86)
        lines.append(psLine("(1) 3 + 4 × 2", x: 0.06, top: 0.50, width: 0.4))
        lines.append(psLine("(2) (3 + 4) × 2", x: 0.06, top: 0.55, width: 0.4))
        lines.append(psLine("1) 11  2) 14", x: 0.06, top: 0.60, width: 0.4))
        lines.append(psLine("④ 4    ⑤ 5", x: 0.06, top: 0.65, width: 0.3))
        let regions = ProblemSplitter.regions(lines: lines)
        check("문제 나누기: 선택지·소문항은 문제 아님", psNumbers(regions) == [5, 6], psDescribe(regions))
        if regions.count == 2 {
            check("문제 나누기: 소문항은 앞 문제 영역 안", regions[0].topLeftRect.maxY >= 0.36 && regions[1].topLeftRect.maxY >= 0.67, psDescribe(regions))
        }
    }

    // 5) 문제가 하나뿐인 사진 → 빈 배열 (기존 직접 자르기)
    do {
        var lines = psProblem("7. 다음 식을 인수분해하시오.", body: ["x² − 5x + 6"], x: 0.06, top: 0.15, width: 0.86)
        lines.append(psLine("(1) (x − 2)(x − 3)", x: 0.06, top: 0.30, width: 0.5))
        lines.append(psLine("(2) (x + 2)(x + 3)", x: 0.06, top: 0.35, width: 0.5))
        lines.append(psLine(choices, x: 0.06, top: 0.42, width: 0.8))
        lines.append(psLine("23", x: 0.48, top: 0.96, width: 0.04))
        check("문제 나누기: 한 문제 사진은 나누지 않음", ProblemSplitter.regions(lines: lines).isEmpty)
        check("문제 나누기: 글자 없는 사진", ProblemSplitter.regions(lines: []).isEmpty)
        // 손으로 크게 찍은 한 문제 (번호 없음)
        let plain = [psLine("다음 식을 간단히 하시오.", x: 0.1, top: 0.2), psLine("3(x + 2) − 2x", x: 0.1, top: 0.3)]
        check("문제 나누기: 번호 없는 사진", ProblemSplitter.regions(lines: plain).isEmpty)
    }

    // 6) 잡음: 쪽 번호, 식 속 숫자, 들여 쓴 "2.", 줄 중간 "2.", 페이지 가운데 "3.", 순서 안 맞는 번호
    do {
        var lines = [psLine("12", x: 0.06, top: 0.02, width: 0.04)]  // 위쪽 쪽 번호
        lines += psProblem("4. 일차방정식 2x + 1 = 5를 푸시오.", body: [], x: 0.06, top: 0.08, width: 0.86)
        lines.append(psLine("2x + 1 = 5", x: 0.06, top: 0.13, width: 0.3))          // 식 맨 앞 숫자
        lines.append(psLine("2.5 × 4 = 10", x: 0.06, top: 0.17, width: 0.3))        // 소수
        lines.append(psLine("2. 따라서 x = 2", x: 0.20, top: 0.21, width: 0.4))     // 들여 쓴 줄
        lines += psProblem("5. 다음 표를 보고 답하시오.", body: ["표에서 가장 큰 값은 무엇인가?"], x: 0.06, top: 0.30, width: 0.86)
        lines.append(psLine("x =", x: 0.06, top: 0.40, width: 0.05))               // Vision이 한 줄을 둘로 자른 경우
        lines.append(psLine("2. 이므로 답은 2", x: 0.115, top: 0.40, width: 0.3))
        lines.append(psLine("2. 위의 값을 이용하면", x: 0.06, top: 0.45, width: 0.6)) // 왼쪽 끝이지만 순서가 거꾸로
        lines.append(psLine("3. x = 1", x: 0.45, top: 0.50, width: 0.15))          // 페이지 가운데 숫자
        lines.append(psLine("오른쪽 그림과 같이 직선 l이 두 점을 지날 때", x: 0.08, top: 0.53, width: 0.84))
        lines += psProblem("6. 연립방정식을 푸시오.", body: ["x + y = 3", "x − y = 1", choices], x: 0.06, top: 0.62, width: 0.86)
        lines.append(psLine("19. 참고", x: 0.06, top: 0.80, width: 0.3))           // 너무 건너뛴 번호
        lines.append(psLine("23", x: 0.48, top: 0.96, width: 0.04))
        lines.append(psLine("- 24 -", x: 0.47, top: 0.93, width: 0.06))
        let regions = ProblemSplitter.regions(lines: lines)
        let d = psDescribe(regions)
        check("문제 나누기: 잡음 번호 무시", psNumbers(regions) == [4, 5, 6], d)
        if regions.count == 3 {
            check("문제 나누기: 잡음 · 한 단 너비 그대로", regions.allSatisfy { $0.topLeftRect.maxX >= 0.92 && $0.topLeftRect.minX <= 0.06 }, d)
            check("문제 나누기: 잡음 · 5번은 6번 위까지", psNear(regions[1].topLeftRect.maxY, 0.62), d)
        }
    }

    // 7) 다른 번호 모양: [1] · 문제 1 · Q1
    do {
        var bracket: [OCRLine] = []
        bracket += psProblem("[1] 다음 수를 소인수분해하시오.", body: ["84"], x: 0.06, top: 0.1, width: 0.86)
        bracket += psProblem("[2] 최대공약수를 구하시오.", body: ["12, 18"], x: 0.06, top: 0.5, width: 0.86)
        check("문제 나누기: [1] [2] 모양", psNumbers(ProblemSplitter.regions(lines: bracket)) == [1, 2])

        var labeled: [OCRLine] = []
        labeled += psProblem("문제 3 다음 그래프를 보고", body: ["y = 2x + 1"], x: 0.06, top: 0.1, width: 0.86)
        labeled += psProblem("문제 4 기울기를 구하시오.", body: [choices], x: 0.06, top: 0.4, width: 0.86)
        labeled += psProblem("Q5. 절편을 구하시오.", body: [], x: 0.06, top: 0.7, width: 0.86)
        check("문제 나누기: 문제 3 · 문제 4 · Q5 모양", psNumbers(ProblemSplitter.regions(lines: labeled)) == [3, 4, 5])

        var q: [OCRLine] = []
        q += psProblem("Q1 다음 중 소수는?", body: [choices], x: 0.06, top: 0.1, width: 0.86)
        q += psProblem("Q2 다음 중 합성수는?", body: [choices], x: 0.06, top: 0.5, width: 0.86)
        check("문제 나누기: Q1 Q2 모양", psNumbers(ProblemSplitter.regions(lines: q)) == [1, 2])

        // "유형 1 · 유형 2"는 문제 묶음 제목이라 나누지 않음
        let types = [psLine("유형 1 일차함수의 그래프", x: 0.06, top: 0.1), psLine("유형 2 기울기", x: 0.06, top: 0.5)]
        check("문제 나누기: 유형 N은 문제 아님", ProblemSplitter.regions(lines: types).isEmpty)
    }

    // 8) 번호 읽기 단위 검사
    check("번호 읽기: 1.", ProblemSplitter.anchor(in: "1. 다음")?.number == 1)
    check("번호 읽기: 12.", ProblemSplitter.anchor(in: "12.다음")?.number == 12)
    check("번호 읽기: 03", ProblemSplitter.anchor(in: "03 다음 중")?.number == 3)
    check("번호 읽기: 01 (번호만 따로)", ProblemSplitter.anchor(in: "01")?.number == 1)
    check("번호 읽기: 소수 1.5 아님", ProblemSplitter.anchor(in: "1.5 + 2") == nil)
    check("번호 읽기: 그냥 23 아님", ProblemSplitter.anchor(in: "23") == nil)
    check("번호 읽기: 2x 아님", ProblemSplitter.anchor(in: "2x + 1 = 5") == nil)
    check("번호 읽기: ① 아님", ProblemSplitter.anchor(in: "① 3") == nil)
    check("번호 읽기: (1) 아님", ProblemSplitter.anchor(in: "(1) 3") == nil)
    check("번호 읽기: 1) 아님", ProblemSplitter.anchor(in: "1) 3") == nil)
    check("번호 읽기: 0 아님", ProblemSplitter.anchor(in: "0. 영") == nil)
    check("번호 읽기: 시각 03:20 아님", ProblemSplitter.anchor(in: "03:20") == nil)
}
