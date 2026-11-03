import Foundation

// MARK: - 그림·그래프·차트·표에서 읽은 것 (DoitFigureFacts): 표 읽기, 두잇 2 답 읽기, 블록, 풀이에 쓰기

func runFigureCases() {
    let ab = GeometryText.segment("AB"), ac = GeometryText.segment("AC"), cd = GeometryText.segment("CD"), bc = GeometryText.segment("BC")

    // 1) 정밀 인식 표·차트 결과 → 칸
    let otsl = "<fcel>월<fcel>판매량<nl><fcel>1월<fcel>30<nl><fcel>2월<fcel>45<nl><fcel>3월<fcel>25<nl>"
    check("표 읽기: OTSL", DoitFigureFacts.parseTable(otsl) == [["월", "판매량"], ["1월", "30"], ["2월", "45"], ["3월", "25"]], "\(DoitFigureFacts.parseTable(otsl))")
    let otslEmpty = "<fcel>구분<fcel>A<fcel>B<nl><fcel>2020<ecel><fcel>7<nl>"
    check("표 읽기: OTSL 빈칸", DoitFigureFacts.parseTable(otslEmpty) == [["구분", "A", "B"], ["2020", "", "7"]], "\(DoitFigureFacts.parseTable(otslEmpty))")
    let markdown = "| 연도 | 인구(만 명) |\n|---|---:|\n| 2010 | 120 |\n| 2020 | 150 |"
    check("표 읽기: 마크다운", DoitFigureFacts.parseTable(markdown) == [["연도", "인구(만 명)"], ["2010", "120"], ["2020", "150"]], "\(DoitFigureFacts.parseTable(markdown))")
    let html = "<table><tr><td>과일</td><td>사과</td><td>배</td></tr><tr><td>개수</td><td>12</td><td>8</td></tr></table>"
    check("표 읽기: HTML", DoitFigureFacts.parseTable(html) == [["과일", "사과", "배"], ["개수", "12", "8"]], "\(DoitFigureFacts.parseTable(html))")
    let chartPipe = "지역 | 강수량\nA | 1,200\nB | 950\nC | 1,430"
    check("표 읽기: 차트 결과 (| 나눔)", DoitFigureFacts.parseTable(chartPipe).count == 4)
    check("표 읽기: 표가 아닌 글", DoitFigureFacts.parseTable("다음 그림에서 x의 값은?").isEmpty)

    // 2) 표 → 줄
    let monthly = DoitFigureFacts.parseTable(otsl)
    let barLines = DoitFigureFacts.tableLines(monthly, kind: .bar)
    check("자료 줄: 이름-값 두 칸", barLines == ["[막대그래프] 1월 30, 2월 45, 3월 25"], "\(barLines)")
    let wide = DoitFigureFacts.tableLines(DoitFigureFacts.parseTable(html), kind: .table)
    check("자료 줄: 가로 두 줄 표", wide == ["[표] (개수) 사과 12, 배 8"], "\(wide)")
    let grid = DoitFigureFacts.tableLines([["연도", "A", "B"], ["2010", "3", "4"], ["2020", "5", "9"]], kind: .table)
    check("자료 줄: 칸이 많은 표", grid == ["[표]", "연도 | A | B", "2010 | 3 | 4", "2020 | 5 | 9"], "\(grid)")

    // 3) 자료로 답하기
    func chart(_ q: String, _ facts: [String]) -> String? { DoitFigureFacts.solveChart(question: q, facts: facts)?.answer }
    check("자료: 가장 많은 달", chart("판매량이 가장 많은 달은?", barLines) == "2월", chart("판매량이 가장 많은 달은?", barLines) ?? "nil")
    check("자료: 가장 적은 달", chart("판매량이 가장 적은 달을 쓰시오.", barLines) == "3월")
    check("자료: 평균", chart("세 달 판매량의 평균을 구하시오.", barLines) == "33.33", chart("세 달 판매량의 평균을 구하시오.", barLines) ?? "nil")
    check("자료: 합", chart("판매량의 합은?", barLines) == "100")
    check("자료: 차", chart("2월과 3월 판매량의 차는?", barLines) == "20")
    check("자료: 증가율", chart("1월에 대한 2월의 증가율은 몇 %인가?", barLines) == "50%", chart("1월에 대한 2월의 증가율은 몇 %인가?", barLines) ?? "nil")
    check("자료: 한 값", chart("1월의 판매량은 몇 개인가?", barLines) == "30")
    let longLabels = ["[꺾은선그래프] 1월 3, 10월 9, 11월 4"]
    check("자료: 10월이 1월로 잡히지 않음", chart("10월의 값은 얼마인가?", longLabels) == "9", chart("10월의 값은 얼마인가?", longLabels) ?? "nil")
    check("자료: 같은 최댓값 둘이면 안 풂", chart("가장 많은 것은?", ["[막대그래프] A 5, B 5, C 2"]) == nil)
    check("자료: 합계 줄은 자료가 아님", chart("가장 많은 반은?", ["[표] 1반 20, 2반 25, 합계 45"]) == "2반", chart("가장 많은 반은?", ["[표] 1반 20, 2반 25, 합계 45"]) ?? "nil")
    let nested = DoitFigureFacts.series(in: ["[표] (인구(만 명)) 2010 120, 2015 135, 2020 150"])
    check("자료: 괄호 속 괄호 이름", nested.first?.name == "인구(만 명)" && nested.first?.labels == ["2010", "2015", "2020"], "\(nested)")
    let gridSeries = DoitFigureFacts.series(in: grid)
    check("자료: 칸 표의 열마다 자료", gridSeries.contains { $0.name == "B" && $0.values == [4, 9] }, "\(gridSeries)")
    check("자료: 열 이름으로 고름", chart("B의 2010과 2020의 차는?", grid) == "5", chart("B의 2010과 2020의 차는?", grid) ?? "nil")
    check("자료: 질문과 상관없는 자료는 안 풂", chart("이 그래프를 보고 알 수 있는 사실을 서술하시오.", barLines) == nil)

    // 4) 그래프 사실 → 식
    check("그래프 식: 두 점 직선", DoitFigureFacts.graphEquation(["지나는 점 (0, 1), (2, 5)"]) == "y = 2x + 1", DoitFigureFacts.graphEquation(["지나는 점 (0, 1), (2, 5)"]) ?? "nil")
    check("그래프 식: 절편", DoitFigureFacts.graphEquation(["x절편 3", "y절편 6"]) == "y = -2x + 6", DoitFigureFacts.graphEquation(["x절편 3", "y절편 6"]) ?? "nil")
    check("그래프 식: 꼭짓점 + 점", DoitFigureFacts.graphEquation(["꼭짓점 (1, -2)", "지나는 점 (0, 1)"]) == "y = 3x² - 6x + 1",
          DoitFigureFacts.graphEquation(["꼭짓점 (1, -2)", "지나는 점 (0, 1)"]) ?? "nil")
    check("그래프 식: 세 점 포물선", DoitFigureFacts.graphEquation(["포물선", "지나는 점 (-1, 0), (3, 0), (0, -3)"]) == "y = x² - 2x - 3")
    check("그래프 식: 한 직선 위에 없으면 안 냄", DoitFigureFacts.graphEquation(["지나는 점 (0, 0), (1, 1), (2, 5)"]) == nil)
    check("그래프 식: 분수 기울기", DoitFigureFacts.graphEquation(["지나는 점 (0, 2), (3, 0)"]) == "y = -(2/3)x + 2", DoitFigureFacts.graphEquation(["지나는 점 (0, 2), (3, 0)"]) ?? "nil")

    // 5) 두잇 2 답 읽기
    let geo = DoitFigureFacts.parseVision("""
    종류: 도형
    점: A, B, C
    길이: AB = 10
    길이: AC = 6
    직각: C
    각: x = <그림에 적힌 도>
    평행: 없음
    정답: 8
    """)
    check("두잇 2 읽기: 도형", geo?.lines == ["△ABC", "\(ab) = 10", "\(ac) = 6", "∠C = 90°"], "\(geo?.lines ?? [])")
    check("두잇 2 읽기: 종류", geo?.kind == .geometry)
    let par = DoitFigureFacts.parseVision("- 평행: AB, CD\n- 각: ∠x = 65°\n- 수직: AB, BC")
    check("두잇 2 읽기: 평행·각·수직", par?.lines == ["\(ab) ∥ \(cd)", "∠x = 65°", "\(ab) ⊥ \(bc)"], "\(par?.lines ?? [])")
    let graph = DoitFigureFacts.parseVision("종류: 그래프\n지나는 점: (0,1), (2, 5)\ny절편: 1")
    check("두잇 2 읽기: 그래프", graph?.lines == ["지나는 점 (0, 1), (2, 5)", "y절편 1"] && graph?.kind == .graph, "\(graph?.lines ?? [])")
    let bars = DoitFigureFacts.parseVision("종류: 막대그래프\n값: 1월 = 30\n값: 2월 = 45\n값: 3월 = 25")
    check("두잇 2 읽기: 막대그래프", bars?.lines == ["[막대그래프] 1월 30, 2월 45, 3월 25"] && bars?.kind == .chart, "\(bars?.lines ?? [])")
    let circle = DoitFigureFacts.parseVision("원: O, 반지름 = 5\n중심각: AOB = 80")
    check("두잇 2 읽기: 원", circle?.lines == ["원 O의 반지름 = 5", "중심각 ∠AOB = 80°"], "\(circle?.lines ?? [])")
    check("두잇 2 읽기: 줄 모양이 아니면 없음", DoitFigureFacts.parseVision("이 문제의 답은 8입니다. 피타고라스 정리를 쓰면 돼요.") == nil)
    check("두잇 2 읽기: 자리표시만 따라 쓴 답", DoitFigureFacts.parseVision(DoitFigureFacts.visionPrompt) == nil)

    let lm = DoitFigureFacts.parseVision("평행: l, m\n각: 65")
    check("두잇 2 읽기: 직선 이름 평행", lm?.lines.first == "l ∥ m", "\(lm?.lines ?? [])")

    // 어떤 그림인지 (문제 글로)
    let routes: [(String, DoitFigureFacts.Route)] = [
        ("다음 막대그래프는 월별 판매량이다. 가장 많은 달은?", .chart),
        ("다음은 지역별 인구를 나타낸 그래프이다. 인구가 가장 많은 지역은?", .chart),
        ("다음 표는 월별 판매량이다. 평균을 구하시오.", .table),
        ("다음 도수분포표에서 A의 값은?", .table),
        ("그림은 일차함수의 그래프이다. 이 그래프의 식을 구하시오.", .graph),
        ("이차함수 y = x² - 2x의 그래프의 꼭짓점은?", .graph),
        ("그림의 직각삼각형 ABC에서 BC의 길이를 구하시오.", .geometry),
        ("그림에서 l ∥ m일 때, ∠x의 크기는?", .geometry),
        ("자료 3, 5, 7의 표준편차를 구하시오.", .none),
        ("2x + 3 = 7을 푸시오.", .none),
    ]
    for (text, expected) in routes {
        check("그림 종류: \(text)", DoitFigureFacts.route(text) == expected, DoitFigureFacts.route(text).rawValue)
    }
    check("그림 있음: 그래프", DoitFigureFacts.mentionsFigure("다음 그래프에서 x절편은?"))
    check("그림 없음: 식만", !DoitFigureFacts.mentionsFigure("x² - 5x + 6 = 0을 푸시오."))
    let chatShown = DoitFigureFacts.chatBlock("문제\n" + DoitFigureFacts.block(["\(ab) = 10", "∠C = 90°"]))
    check("대화: 그림에서 읽은 것 먼저", chatShown?.contains("그림에서 읽은 것") == true && chatShown?.contains("· ∠C = 90°") == true, chatShown ?? "nil")
    check("대화: 블록 없으면 없음", DoitFigureFacts.chatBlock("문제만") == nil)
    let stated = DoitFigureFacts.solverText("식은?\n" + DoitFigureFacts.block(["그래프의 식은 y = 2x + 1", "y절편 1", "x절편 -0.5"]))
    check("풀이 글: 이미 식이 있으면 또 붙이지 않음", stated.components(separatedBy: "그래프의 식").count == 2, stated)
    let ordered = DoitFigureFacts.solverText("값은?\n① 1 ② 2 ③ 3 ④ 4 ⑤ 5\n" + DoitFigureFacts.block(["∠A = 50°"]))
    check("풀이 글: 그림 사실은 선택지 앞에", ordered == "값은?\n∠A = 50°\n① 1 ② 2 ③ 3 ④ 4 ⑤ 5", ordered)

    // 6) 블록
    let problem = "그림의 직각삼각형 ABC에서 BC의 길이를 구하시오."
    let withBlock = DoitFigureFacts.attach(geo, to: problem)
    check("블록: 붙이기", withBlock.hasPrefix(problem + "\n" + DoitFigureFacts.header), withBlock)
    check("블록: 나누기", DoitFigureFacts.split(withBlock).problem == problem && DoitFigureFacts.split(withBlock).facts.count == 4)
    check("블록: 바꾸기", DoitFigureFacts.replacing(withBlock, with: ["△ABC"]) == problem + "\n" + DoitFigureFacts.header + "\n△ABC")
    check("블록: 다 지우면 블록도 없음", DoitFigureFacts.replacing(withBlock, with: []) == problem)
    check("블록: 다시 붙이면 하나만", DoitFigureFacts.attach(geo, to: withBlock).components(separatedBy: DoitFigureFacts.header).count == 2)

    // 7) 문제 나누기: 블록은 따로, 질문·수식은 문제 글에서만
    let scan = DoitProblemScan.scan(withBlock)
    check("나누기: 그림 줄", scan.figureLines == ["△ABC", "\(ab) = 10", "\(ac) = 6", "∠C = 90°"], "\(scan.figureLines ?? [])")
    check("나누기: 질문은 문제 글", scan.question == problem, scan.question)
    check("나누기: 그림 줄은 수식 칩이 아님", !scan.formulas.contains { $0.contains("10") }, "\(scan.formulas)")
    check("나누기: 그림을 읽었으면 '못 읽음' 표시 없음", !scan.doubts.contains { $0.text == "그래프·그림" }, "\(scan.doubts)")
    check("나누기: 본문에 블록이 남음 (풀이용)", scan.body.contains(DoitFigureFacts.header))
    let noBlock = DoitProblemScan.scan(problem)
    check("나누기: 블록 없으면 nil", noBlock.figureLines == nil && noBlock.doubts.contains { $0.text == "그래프·그림" })
    let choiceScan = DoitProblemScan.scan("판매량이 가장 많은 달은?\n① 1월 ② 2월 ③ 3월 ④ 4월 ⑤ 5월\n" + DoitFigureFacts.block(barLines))
    check("나누기: 선택지는 블록과 안 섞임", choiceScan.choices == ["1월", "2월", "3월", "4월", "5월"], "\(choiceScan.choices)")

    // 8) 수학 풀이: 확인한 그림 사실로 풂
    let solvedTri = MathSolver.solve(withBlock)
    check("풀이: 직각삼각형 (그림에서 읽은 길이)", solvedTri?.answer == "8", solvedTri?.answer ?? "nil")
    check("풀이: 그림 없이는 못 풂", MathSolver.solve(problem)?.answer != "8")
    let lineProblem = "그림은 일차함수의 그래프이다. 이 그래프가 나타내는 직선의 방정식을 구하시오.\n" + DoitFigureFacts.block(["지나는 점 (0, 1), (2, 5)"])
    let solvedLine = MathSolver.solve(lineProblem)
    check("풀이: 그래프 식", solvedLine?.answer.contains("2x + 1") == true, solvedLine?.answer ?? "nil")
    let xIntercept = MathSolver.solve("그림과 같은 일차함수의 그래프의 x절편을 구하시오.\n" + DoitFigureFacts.block(["지나는 점 (0, 4), (1, 2)"]))
    check("풀이: 그래프 사실 → 다른 질문 (x절편)", xIntercept?.answer.contains("2") == true, xIntercept?.answer ?? "nil")
    let chartChoice = MathSolver.solve("다음 막대그래프에서 판매량이 가장 많은 달은?\n① 1월 ② 2월 ③ 3월 ④ 4월 ⑤ 5월\n" + DoitFigureFacts.block(barLines))
    check("풀이: 자료 + 선택지", chartChoice?.answer == "② 2월", chartChoice?.answer ?? "nil")
    let chartMean = MathSolver.solve("다음 그래프는 세 달 동안의 판매량이다. 판매량의 평균은?\n" + DoitFigureFacts.block(["[막대그래프] 1월 30, 2월 45, 3월 60"]))
    check("풀이: 자료 평균", chartMean?.answer == "45", chartMean?.answer ?? "nil")
    let angleProblem = "그림에서 삼각형 ABC의 ∠C의 크기를 구하시오.\n" + DoitFigureFacts.block(["△ABC", "∠A = 50°", "∠B = 60°"])
    check("풀이: 그림에서 읽은 두 각", MathSolver.solve(angleProblem)?.answer.contains("70") == true, MathSolver.solve(angleProblem)?.answer ?? "nil")

    // 9) 다른 과목: 자료로 고르기
    let social = "다음은 지역별 인구를 나타낸 그래프이다. 인구가 가장 많은 지역은?\n① A ② B ③ C ④ D ⑤ E\n" + DoitFigureFacts.block(["[막대그래프] A 120, B 340, C 90, D 210, E 150"])
    let socialScan = DoitProblemScan.scan(social, math: false)
    let socialSolved = DoitSubjectSolve.solve(text: social, choices: socialScan.choices, subjectBroad: "사회", body: socialScan.body)
    check("과목 풀이: 가장 많은 지역", socialSolved?.finalAnswer == "2", socialSolved?.finalAnswer ?? "nil")
    let science = "표는 물질의 온도 변화이다. 2분일 때와 6분일 때 온도의 차는 몇 ℃인가?\n① 10 ② 20 ③ 30 ④ 40 ⑤ 50\n" + DoitFigureFacts.block(["[꺾은선그래프] 0분 20, 2분 35, 4분 50, 6分 65".replacingOccurrences(of: "分", with: "분")])
    let sciScan = DoitProblemScan.scan(science, math: false)
    let sciSolved = DoitSubjectSolve.solve(text: science, choices: sciScan.choices, subjectBroad: "과학", body: sciScan.body)
    check("과목 풀이: 두 값의 차 → 선지", sciSolved?.finalAnswer == "3", sciSolved?.finalAnswer ?? "nil")
    let noData = DoitSubjectSolve.solve(text: "인구가 가장 많은 지역은?\n① A ② B ③ C ④ D ⑤ E", choices: ["A", "B", "C", "D", "E"], subjectBroad: "사회")
    check("과목 풀이: 자료가 없으면 안 풂", noData == nil)
}
