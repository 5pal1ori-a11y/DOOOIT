import Foundation

// MARK: - 풀이 배터리: 중1~고2 시험 문제 모양으로 풀이 엔진의 정답률 재기
// - 앱처럼 DoitAutoSolve.engine 으로 풂 (사진 글 → 본문·선지 나누기 → 여러 모양으로 풀기)
// - 틀린 답은 실패 (틀린 답은 안 푸는 것보다 나빠요), 못 푼 문제는 목록만 보여 줌
// - 정답: "|"로 여러 모양, "~"로 시작하면 답 글에 그 말이 들어 있으면 정답, 객관식은 선지 번호

struct BatteryCase {
    let text: String
    let answer: String
    init(_ text: String, _ answer: String) { self.text = text; self.answer = answer }
}

let solverBattery: [BatteryCase] = [
    // 일차방정식
    BatteryCase("일차방정식 3x - 5 = 2x + 4 의 해를 구하시오.", "9"),
    BatteryCase("방정식 2(x - 3) = x + 1 을 풀어라.", "7"),
    BatteryCase("일차방정식 (x+1)/2 - (x-1)/3 = 1 의 해는?", "1"),
    BatteryCase("0.3x + 1.2 = 0.5x - 0.4 를 푸시오.", "8"),
    BatteryCase("x에 대한 방정식 ax + 3 = 2x - 1 의 해가 x = -2일 때, 상수 a의 값을 구하시오.", "4"),
    BatteryCase("3. 5x-7=3x+9의 해는?\n① 6 ② 7 ③ 8 ④ 9 ⑤ 10", "3"),
    BatteryCase("4(x - 1) - 3(2x + 1) = -9 를 풀면?", "1"),
    BatteryCase("어떤 수의 3배에 5를 더하면 그 수의 5배보다 7만큼 작다. 어떤 수를 구하시오.", "6"),

    // 이차방정식
    BatteryCase("이차방정식 x² - 7x + 12 = 0 의 해를 구하시오.", "3, 4"),
    BatteryCase("x^2 + 2x - 15 = 0 을 풀어라", "3, -5"),
    BatteryCase("이차방정식 2x² - 5x - 3 = 0 의 해는?", "3, -1/2"),
    BatteryCase("x² - 6x + 4 = 0 의 해를 구하시오.", "3+√5, 3-√5"),
    BatteryCase("이차방정식 x² + 4x + 4 = 0 의 해는?", "-2"),
    BatteryCase("이차방정식 x² - 3x + k = 0 의 한 근이 1일 때, 상수 k의 값은?", "2"),
    BatteryCase("이차방정식 x² + 5x + 3 = 0 의 두 근을 α, β라 할 때, α + β 의 값은?", "-5"),
    BatteryCase("x² - 4x + 2 = 0 의 두 근을 α, β라 할 때 α² + β² 의 값을 구하시오.", "12"),
    BatteryCase("이차방정식 x² - 2x + k = 0 이 중근을 가질 때, 상수 k의 값은?", "1"),
    BatteryCase("이차방정식 x² + 3x - 1 = 0 의 판별식 D의 값은?", "13"),
    BatteryCase("x에 대한 이차방정식 x² + 2(k-1)x + k² = 0 이 서로 다른 두 실근을 갖도록 하는 실수 k의 값의 범위는?", "k < 1/2"),
    BatteryCase("7. x2-5x+6=0의 두 근의 곱은?\n① 1 ② 2 ③ 5 ④ 6 ⑤ -6", "4"),
    BatteryCase("(x - 2)² = 9 를 풀어라.", "5, -1"),
    BatteryCase("이차방정식 3x² = 12 의 해는?", "2, -2"),
    BatteryCase("두 근이 2, -3이고 x²의 계수가 1인 이차방정식은?", "x^2+x-6=0"),
    BatteryCase("이차방정식 x² - 6x + 9 = 0 의 근의 종류를 판별하시오.", "~중근"),
    BatteryCase("이차방정식 x² + 2x + 5 = 0 의 해를 구하시오.", "-1+2i, -1-2i|-1±2i"),

    // 연립방정식
    BatteryCase("연립방정식 x + y = 7, x - y = 1 을 풀어라.", "x=4, y=3"),
    BatteryCase("연립방정식 { 2x + 3y = 12, x - y = 1 } 의 해를 구하시오.", "x=3, y=2"),
    BatteryCase("연립방정식\n3x + 2y = 8\n2x - y = 3\n을 푸시오.", "x=2, y=1"),
    BatteryCase("연립방정식 x + 2y = 5, 3x - y = 1 의 해가 x = a, y = b일 때, a + b 의 값은?", "3"),
    BatteryCase("사과 3개와 배 2개의 값은 3400원이고, 사과 1개와 배 2개의 값은 2200원이다. 사과 한 개의 값은?", "600"),
    BatteryCase("닭과 토끼가 모두 10마리이고 다리의 수의 합이 32개일 때, 토끼는 몇 마리인가?", "6"),
    BatteryCase("연립방정식 y = 2x - 1, y = -x + 5 의 해는?", "x=2, y=3"),
    BatteryCase("연립방정식 0.2x + 0.3y = 1.3, x + y = 5 를 풀어라", "x=2, y=3"),
    BatteryCase("11. 연립방정식 2x+y=7, x-y=2의 해를 x=a, y=b라 할 때, ab의 값은?\n① 1 ② 2 ③ 3 ④ 4 ⑤ 5", "3"),

    // 부등식
    BatteryCase("일차부등식 3x - 2 > 7 의 해를 구하시오.", "x > 3"),
    BatteryCase("부등식 2(x + 1) ≤ 5x - 4 를 풀어라.", "x >= 2"),
    BatteryCase("부등식 -2x + 3 < 9 의 해는?", "x > -3"),
    BatteryCase("연립부등식 2x - 1 > 3, x + 4 ≤ 10 의 해를 구하시오.", "2 < x <= 6"),
    BatteryCase("부등식 |x - 2| < 3 의 해는?", "-1 < x < 5"),
    BatteryCase("부등식 |2x + 1| ≥ 5 를 풀어라.", "x <= -3 또는 x >= 2"),
    BatteryCase("이차부등식 x² - x - 6 < 0 의 해는?", "-2 < x < 3"),
    BatteryCase("이차부등식 x² - 4x + 3 ≥ 0 을 풀어라.", "x <= 1 또는 x >= 3"),
    BatteryCase("부등식 3x - 5 ≤ x + 3 을 만족시키는 자연수 x의 개수는?", "4"),
    BatteryCase("5. x^2-2x-8<=0 의 해는?", "-2 <= x <= 4"),
    BatteryCase("부등식 x + 3 > 2x - 1 을 만족하는 가장 큰 정수 x는?", "3"),

    // 인수분해
    BatteryCase("x² - 5x + 6 을 인수분해하시오.", "(x-2)(x-3)"),
    BatteryCase("x^2 - 9 를 인수분해하면?", "(x+3)(x-3)"),
    BatteryCase("2x² + 7x + 3 을 인수분해하시오.", "(2x+1)(x+3)"),
    BatteryCase("x² + 6x + 9 를 인수분해하시오.", "(x+3)^2"),
    BatteryCase("x³ - 8 을 인수분해하시오.", "(x-2)(x^2+2x+4)"),
    BatteryCase("4x² - 12x + 9 를 인수분해하시오.", "(2x-3)^2"),
    BatteryCase("x² - 2x - 15 를 인수분해하면 (x + a)(x + b)일 때, a + b 의 값은?", "-2"),
    BatteryCase("3x² - 12 를 인수분해하시오.", "3(x+2)(x-2)"),
    BatteryCase("x⁴ - 5x² + 4 를 인수분해하시오.", "(x+1)(x-1)(x+2)(x-2)"),

    // 식의 값 · 곱셈 공식
    BatteryCase("x = 3일 때, 2x² - 5x + 1 의 값은?", "4"),
    BatteryCase("a = -2, b = 3일 때, a² - ab + b² 의 값을 구하시오.", "19"),
    BatteryCase("x + y = 5, xy = 3일 때, x² + y² 의 값은?", "19"),
    BatteryCase("x - y = 3, xy = 2일 때, x² + y² 의 값은?", "13"),
    BatteryCase("x + 1/x = 4일 때, x² + 1/x² 의 값은?", "14"),
    BatteryCase("a + b = 4, ab = 1일 때, a³ + b³ 의 값을 구하시오.", "52"),
    BatteryCase("x + y = 6, xy = 7일 때, (x - y)² 의 값은?", "8"),
    BatteryCase("(x + 3)(x - 5) 를 전개하시오.", "x^2-2x-15"),
    BatteryCase("(2x - 1)² 을 전개하면?", "4x^2-4x+1"),
    BatteryCase("(a + 2b)(a - 2b) 를 전개하시오.", "a^2-4b^2"),
    BatteryCase("x = 1 + √2 일 때, x² - 2x 의 값은?", "1"),
    BatteryCase("9. x=-1일 때 x^2+3x-2의 값은?\n① -4 ② -2 ③ 0 ④ 2 ⑤ 4", "1"),

    // 지수법칙 · 단항식
    BatteryCase("2³ × 2⁴ 의 값은?", "128"),
    BatteryCase("(x²)³ × x⁴ 을 간단히 하시오.", "x^10"),
    BatteryCase("(-2x³)² 을 간단히 하면?", "4x^6"),
    BatteryCase("6x⁴ ÷ 2x² 을 계산하시오.", "3x^2"),
    BatteryCase("(3a²b)² × 2ab³ 을 간단히 하시오.", "18a^5b^5"),
    BatteryCase("2^5 ÷ 2^3 × 2^2 의 값은?", "16"),
    BatteryCase("3^x = 81 일 때, x의 값은?", "4"),
    BatteryCase("2^(x+1) = 32 를 만족하는 x의 값은?", "4"),
    BatteryCase("12a³b² ÷ 4ab 를 간단히 하시오.", "3a^2b"),

    // 근호
    BatteryCase("√12 + √27 을 간단히 하시오.", "5√3"),
    BatteryCase("√50 - √18 을 계산하면?", "2√2"),
    BatteryCase("√3 × √12 의 값은?", "6"),
    BatteryCase("2√3 × 3√2 를 계산하시오.", "6√6"),
    BatteryCase("6/√3 의 분모를 유리화하시오.", "2√3"),
    BatteryCase("1/(√3 - √2) 의 분모를 유리화하면?", "√3+√2"),
    BatteryCase("(√5 + 2)(√5 - 2) 의 값은?", "1"),
    BatteryCase("(√3 + 1)² 을 계산하시오.", "4+2√3"),
    BatteryCase("√72 를 a√b 꼴로 나타내시오. (단, b는 가장 작은 자연수)", "6√2"),
    BatteryCase("√48 ÷ √3 의 값은?", "4"),
    BatteryCase("8. √8+√32-√2 를 간단히 하면?\n① 3√2 ② 4√2 ③ 5√2 ④ 6√2 ⑤ 7√2", "3"),
    BatteryCase("√(-3)² + √16 의 값은?", "7"),

    // 이차함수
    BatteryCase("이차함수 y = x² - 4x + 7 의 꼭짓점의 좌표를 구하시오.", "(2, 3)"),
    BatteryCase("이차함수 y = -2x² + 8x - 3 의 최댓값은?", "5"),
    BatteryCase("이차함수 y = 2x² + 4x + 5 의 최솟값을 구하시오.", "3"),
    BatteryCase("이차함수 y = x² - 6x + 5 의 그래프의 축의 방정식은?", "x = 3"),
    BatteryCase("이차함수 y = 2x² 의 그래프를 x축의 방향으로 3만큼, y축의 방향으로 -1만큼 평행이동한 그래프의 식은?", "y=2x^2-12x+17"),
    BatteryCase("이차함수 y = x² + ax + 3 의 그래프가 점 (1, 6)을 지날 때, 상수 a의 값은?", "2"),
    BatteryCase("이차함수 y = -x² + 2x + 3 (0 ≤ x ≤ 3) 의 최솟값은?", "0"),
    BatteryCase("꼭짓점의 좌표가 (1, 2)이고 점 (2, 5)를 지나는 이차함수의 식을 y = ax² + bx + c 라 할 때, a + b + c 의 값은?", "2"),
    BatteryCase("이차함수 y = x² - 2x - 3 의 그래프가 x축과 만나는 두 점의 x좌표를 구하시오.", "-1, 3"),
    BatteryCase("이차함수 y = x² + 4x + k 의 최솟값이 3일 때, 상수 k의 값은?", "7"),
    BatteryCase("이차함수 y = (x - 1)² + 4 의 꼭짓점의 좌표는?", "(1, 4)"),
    BatteryCase("이차함수 y = -3(x + 2)² + 5 의 최댓값은?", "5"),
    BatteryCase("13. y=x^2-8x+10의 꼭짓점의 좌표는?\n① (4, -6) ② (4, 6) ③ (-4, -6) ④ (8, 10) ⑤ (-4, 6)", "1"),
    BatteryCase("이차함수 y = x² - 2x + 5 의 그래프가 y축과 만나는 점의 y좌표는?", "5"),

    // 일차함수 · 직선
    BatteryCase("두 점 (1, 3), (3, 7)을 지나는 직선의 기울기는?", "2"),
    BatteryCase("두 점 (1, 2), (3, 8)을 지나는 직선의 방정식을 구하시오.", "y=3x-1"),
    BatteryCase("일차함수 y = 2x - 6 의 그래프의 x절편은?", "3"),
    BatteryCase("일차함수 y = -3x + 4 의 그래프의 y절편은?", "4"),
    BatteryCase("기울기가 2이고 점 (1, 5)를 지나는 직선의 방정식은?", "y=2x+3"),
    BatteryCase("직선 y = 3x + 1 에 평행하고 점 (2, 1)을 지나는 직선의 방정식은?", "y=3x-5"),
    BatteryCase("직선 y = 2x + 1 에 수직이고 점 (2, 3)을 지나는 직선의 방정식은?", "y=-1/2x+4"),
    BatteryCase("일차함수 y = ax + 3 의 그래프가 점 (2, 7)을 지날 때, 상수 a의 값은?", "2"),
    BatteryCase("일차함수 y = 2x + 4 의 그래프와 x축, y축으로 둘러싸인 삼각형의 넓이는?", "4"),
    BatteryCase("두 직선 y = 2x - 1, y = -x + 8 의 교점의 좌표는?", "(3, 5)"),
    BatteryCase("일차함수 y = 3x - 2 의 그래프를 y축의 방향으로 5만큼 평행이동한 그래프의 식은?", "y=3x+3"),
    BatteryCase("15. 일차함수 y=-2x+6의 그래프의 기울기와 y절편의 합은?\n① 2 ② 4 ③ 6 ④ 8 ⑤ -8", "2"),

    // 복소수
    BatteryCase("(3 + 2i) + (1 - 5i) 를 계산하시오.", "4-3i"),
    BatteryCase("(2 + i)(3 - i) 를 계산하면?", "7+i"),
    BatteryCase("i² + i³ + i⁴ 의 값은?", "-i"),
    BatteryCase("(1 + i)/(1 - i) 를 계산하시오.", "i"),
    BatteryCase("복소수 3 - 4i 의 켤레복소수는?", "3+4i"),
    BatteryCase("(1 + i)² 의 값은?", "2i"),
    BatteryCase("(x + 2) + (y - 1)i = 5 + 3i 를 만족하는 실수 x, y에 대하여 x + y 의 값은?", "7"),
    BatteryCase("(2 - 3i) - (4 + i) 를 계산하시오.", "-2-4i"),
    BatteryCase("(3 + i)(3 - i) 의 값은?", "10"),

    // 나머지정리 · 인수정리 · 항등식 · 다항식의 나눗셈
    BatteryCase("다항식 x³ - 2x² + 3x - 4 를 x - 2 로 나누었을 때의 나머지는?", "2"),
    BatteryCase("다항식 f(x) = x³ + ax² - 5x + 6 이 x - 1 로 나누어떨어질 때, 상수 a의 값은?", "-2"),
    BatteryCase("다항식 2x³ + x² - 3x + 1 을 x + 1 로 나누었을 때의 나머지를 구하시오.", "3"),
    BatteryCase("다항식 x³ + 2x² - x + 3 을 x² + 1 로 나누었을 때의 나머지는?", "-2x+1"),
    BatteryCase("등식 a(x - 1) + b(x + 1) = 4x + 2 가 x에 대한 항등식일 때, 상수 a, b 에 대하여 ab 의 값은?", "3"),
    BatteryCase("등식 x² + ax + 3 = (x + 1)(x + b) 가 x에 대한 항등식일 때, a + b 의 값은?", "7"),
    BatteryCase("다항식 f(x)를 x - 1 로 나눈 나머지가 3, x + 2 로 나눈 나머지가 -3 일 때, f(x)를 (x - 1)(x + 2) 로 나눈 나머지를 구하시오.", "2x+1"),
    BatteryCase("다항식 x³ - 3x² + 4 를 x - 2 로 나누었을 때의 몫을 구하시오.", "x^2-x-2"),
    BatteryCase("다항식 x³ + ax + 2 가 x + 2 를 인수로 가질 때, 상수 a의 값은?", "-3"),
    BatteryCase("17. 다항식 x^3+2x-1을 x-1로 나눈 나머지는?\n① -1 ② 0 ③ 1 ④ 2 ⑤ 3", "4"),

    // 경우의 수 · 순열 · 조합
    BatteryCase("서로 다른 주사위 2개를 던질 때, 나오는 눈의 수의 합이 7인 경우의 수는?", "6"),
    BatteryCase("5명 중에서 회장 1명, 부회장 1명을 뽑는 경우의 수는?", "20"),
    BatteryCase("6명 중에서 대표 2명을 뽑는 경우의 수는?", "15"),
    BatteryCase("5P2 의 값은?", "20"),
    BatteryCase("₇C₃ 의 값을 구하시오.", "35"),
    BatteryCase("A, B, C, D 4명을 한 줄로 세우는 경우의 수는?", "24"),
    BatteryCase("0, 1, 2, 3 의 숫자가 각각 적힌 4장의 카드 중 2장을 뽑아 만들 수 있는 두 자리 정수의 개수는?", "9"),
    BatteryCase("남학생 3명, 여학생 2명 중에서 남학생 1명과 여학생 1명을 뽑는 경우의 수는?", "6"),
    BatteryCase("동전 3개를 동시에 던질 때 일어나는 모든 경우의 수는?", "8"),
    BatteryCase("5명이 원탁에 둘러앉는 경우의 수는?", "24"),
    BatteryCase("1부터 20까지의 자연수 중에서 3의 배수 또는 5의 배수의 개수는?", "9"),
    BatteryCase("nC2 = 10 을 만족하는 자연수 n의 값은?", "5"),
    BatteryCase("4! 의 값은?", "24"),

    // 확률
    BatteryCase("주사위 한 개를 던질 때, 짝수의 눈이 나올 확률은?", "1/2"),
    BatteryCase("동전 2개를 동시에 던질 때, 모두 앞면이 나올 확률은?", "1/4"),
    BatteryCase("흰 공 3개, 검은 공 2개가 들어 있는 주머니에서 공 1개를 꺼낼 때, 흰 공이 나올 확률은?", "3/5"),
    BatteryCase("서로 다른 주사위 2개를 동시에 던질 때, 나오는 눈의 수의 합이 5일 확률은?", "1/9"),
    BatteryCase("1부터 10까지의 자연수가 각각 적힌 10장의 카드 중 한 장을 뽑을 때, 3의 배수가 나올 확률은?", "3/10"),
    BatteryCase("사건 A가 일어날 확률이 1/3 일 때, 사건 A가 일어나지 않을 확률은?", "2/3"),
    BatteryCase("빨간 공 4개, 파란 공 6개가 들어 있는 주머니에서 동시에 2개를 꺼낼 때, 2개 모두 빨간 공일 확률은?", "2/15"),
    BatteryCase("명중률이 0.8인 선수가 두 번 쏠 때, 두 번 모두 명중할 확률은?", "0.64"),

    // 집합
    BatteryCase("두 집합 A = {1, 2, 3, 4}, B = {3, 4, 5, 6} 에 대하여 n(A ∪ B) 의 값은?", "6"),
    BatteryCase("두 집합 A = {1, 2, 3, 4, 5}, B = {2, 4, 6} 에 대하여 A ∩ B 를 구하시오.", "{2, 4}"),
    BatteryCase("n(A) = 10, n(B) = 8, n(A ∩ B) = 3 일 때, n(A ∪ B) 의 값은?", "15"),
    BatteryCase("집합 A = {1, 2, 3} 의 부분집합의 개수는?", "8"),
    BatteryCase("집합 A = {x | x는 10 이하의 소수} 일 때, n(A) 의 값은?", "4"),
    BatteryCase("전체집합 U = {1, 2, 3, 4, 5, 6} 의 부분집합 A = {1, 3, 5} 에 대하여 A의 여집합을 구하시오.", "{2, 4, 6}"),
    BatteryCase("두 집합 A = {1, 2, 3, 4}, B = {1, 3} 에 대하여 A - B 를 구하시오.", "{2, 4}"),

    // 명제
    BatteryCase("두 조건 p: x > 2, q: x > a 에 대하여 p가 q이기 위한 충분조건이 되도록 하는 실수 a의 최댓값은?", "2"),

    // 함수 (합성 · 역함수 · 함숫값)
    BatteryCase("두 함수 f(x) = 2x + 1, g(x) = x² 에 대하여 (g ∘ f)(1) 의 값은?", "9"),
    BatteryCase("함수 f(x) = 3x - 2 에 대하여 f(2) 의 값은?", "4"),
    BatteryCase("함수 f(x) = 2x - 4 의 역함수를 구하시오.", "y=1/2x+2"),
    BatteryCase("함수 f(x) = 3x + 1 에 대하여 f⁻¹(7) 의 값은?", "2"),
    BatteryCase("두 함수 f(x) = x + 2, g(x) = 2x - 1 에 대하여 (f ∘ g)(x) 를 구하시오.", "2x+1"),
    BatteryCase("두 함수 f(x) = x² - 1, g(x) = x + 3 에 대하여 f(g(-1)) 의 값은?", "3"),

    // 유리함수 · 무리함수
    BatteryCase("유리함수 y = 2/(x - 1) + 3 의 그래프의 점근선의 방정식을 구하시오.", "x=1, y=3"),
    BatteryCase("유리함수 y = (2x + 1)/(x - 1) 의 그래프의 두 점근선의 교점의 좌표는?", "(1, 2)"),
    BatteryCase("무리함수 y = √(x - 2) + 1 의 정의역은?", "x >= 2"),
    BatteryCase("무리함수 y = √(2x + 4) 의 그래프가 점 (a, 4)를 지날 때, a의 값은?", "6"),
    BatteryCase("함수 y = 3/x 의 그래프를 x축의 방향으로 2만큼, y축의 방향으로 -1만큼 평행이동한 그래프의 점근선의 방정식은?", "x=2, y=-1"),

    // 수열
    BatteryCase("첫째항이 3, 공차가 4인 등차수열의 제10항은?", "39"),
    BatteryCase("등차수열 2, 5, 8, 11, … 의 제20항을 구하시오.", "59"),
    BatteryCase("첫째항이 2, 공비가 3인 등비수열의 제5항은?", "162"),
    BatteryCase("등비수열 1, 2, 4, 8, … 의 첫째항부터 제10항까지의 합은?", "1023"),
    BatteryCase("첫째항이 1, 공차가 2인 등차수열의 첫째항부터 제10항까지의 합은?", "100"),
    BatteryCase("등차수열 {an}에서 a3 = 7, a7 = 19 일 때, a10 의 값은?", "28"),
    BatteryCase("등비수열 {an}에서 a2 = 6, a5 = 162 일 때, 공비 r 의 값은? (단, r는 실수)", "3"),
    BatteryCase("1 + 2 + 3 + … + 100 의 값은?", "5050"),
    BatteryCase("∑_{k=1}^{10} (2k + 1) 의 값은?", "120"),
    BatteryCase("세 수 2, x, 18 이 이 순서대로 등비수열을 이룰 때, 양수 x의 값은?", "6"),
    BatteryCase("세 수 3, x, 11 이 이 순서대로 등차수열을 이룰 때, x의 값은?", "7"),

    // 지수 · 로그
    BatteryCase("log₂ 32 의 값은?", "5"),
    BatteryCase("log 100 + log 10 의 값은?", "3"),
    BatteryCase("log₃ 6 + log₃ (3/2) 의 값을 구하시오.", "2"),
    BatteryCase("log₂ 12 - log₂ 3 의 값은?", "2"),
    BatteryCase("8^(2/3) 의 값은?", "4"),
    BatteryCase("27^(1/3) × 4^(1/2) 의 값은?", "6"),
    BatteryCase("log₂ x = 3 일 때, x의 값은?", "8"),
    BatteryCase("2^x = 16 을 만족시키는 x의 값은?", "4"),
    BatteryCase("방정식 (1/2)^x = 8 의 해는?", "-3"),
    BatteryCase("log₄ 8 의 값은?", "3/2"),
    BatteryCase("log₂ 3 × log₃ 8 의 값은?", "3"),
    BatteryCase("4. log2 8 + log3 9 의 값은?\n① 3 ② 4 ③ 5 ④ 6 ⑤ 7", "3"),

    // 삼각함수
    BatteryCase("sin 30° + cos 60° 의 값은?", "1"),
    BatteryCase("tan 45° 의 값은?", "1"),
    BatteryCase("sin² 30° + cos² 30° 의 값은?", "1"),
    BatteryCase("cos 120° 의 값은?", "-1/2"),
    BatteryCase("sin(π/6) 의 값은?", "1/2"),
    BatteryCase("θ가 제2사분면의 각이고 sin θ = 3/5 일 때, cos θ 의 값은?", "-4/5"),
    BatteryCase("sin 60° × cos 30° 의 값은?", "3/4"),
    BatteryCase("sin 210° 의 값은?", "-1/2"),
    BatteryCase("∠C = 90°인 직각삼각형 ABC에서 AB = 10, BC = 6 일 때, sin A 의 값은?", "3/5"),

    // 극한
    BatteryCase("lim_{x→2} (x² - 4)/(x - 2) 의 값은?", "4"),
    BatteryCase("lim_{x→1} (x² + 2x + 3) 의 값을 구하시오.", "6"),
    BatteryCase("lim_{x→∞} (2x² + 1)/(x² - 3) 의 값은?", "2"),
    BatteryCase("lim x→3 (x^2-9)/(x-3) 의 값은?", "6"),
    BatteryCase("lim_{x→0} (x² + 3x)/x 의 값은?", "3"),
    BatteryCase("lim_{x→∞} (3x + 1)/(x² + 2) 의 값은?", "0"),

    // 미분
    BatteryCase("함수 f(x) = x³ - 2x² + 5 에 대하여 f'(2) 의 값은?", "4"),
    BatteryCase("함수 f(x) = 2x² + 3x - 1 의 도함수 f'(x) 를 구하시오.", "4x+3"),
    BatteryCase("곡선 y = x² - 3x + 2 위의 점 (3, 2) 에서의 접선의 방정식은?", "y=3x-7"),
    BatteryCase("함수 f(x) = x³ - 3x + 1 의 극댓값은?", "3"),
    BatteryCase("함수 f(x) = x³ - 3x + 1 의 극솟값을 구하시오.", "-1"),
    BatteryCase("함수 f(x) = x² + 4x 의 x = 1 에서의 미분계수는?", "6"),
    BatteryCase("곡선 y = x³ 위의 x = 1 인 점에서의 접선의 기울기는?", "3"),
    BatteryCase("함수 f(x) = x³ + ax² + 3x 가 x = 1 에서 극값을 가질 때, 상수 a의 값은?", "-3"),
    BatteryCase("함수 f(x) = x² - 5x 에 대하여 lim_{h→0} {f(1 + h) - f(1)}/h 의 값은?", "-3"),
    BatteryCase("21. f(x)=x^3-6x^2+9x+1의 극댓값은?\n① 1 ② 3 ③ 5 ④ 7 ⑤ 9", "3"),

    // 적분
    BatteryCase("정적분 ∫₀² (3x² + 2x) dx 의 값은?", "12"),
    BatteryCase("∫_1^3 (2x - 1) dx 의 값을 구하시오.", "6"),
    BatteryCase("∫_{-1}^{1} (x³ + 3x²) dx 의 값은?", "2"),
    BatteryCase("곡선 y = x² 과 x축 및 두 직선 x = 0, x = 3 으로 둘러싸인 부분의 넓이는?", "9"),
    BatteryCase("곡선 y = x² - 2x 와 x축으로 둘러싸인 부분의 넓이는?", "4/3"),
    BatteryCase("곡선 y = x² 과 직선 y = x 로 둘러싸인 부분의 넓이는?", "1/6"),
    BatteryCase("∫_0^1 (x + 1)² dx 의 값은?", "7/3"),

    // 통계
    BatteryCase("다음 자료의 평균을 구하시오.\n3, 5, 7, 9, 11", "7"),
    BatteryCase("자료 4, 8, 6, 2, 10 의 분산은?", "8"),
    BatteryCase("자료 2, 4, 6, 8, 10 의 표준편차는?", "2√2"),
    BatteryCase("다음 자료의 중앙값은?\n7, 3, 9, 5, 1, 8", "6"),
    BatteryCase("자료 2, 3, 3, 5, 7, 3, 5 의 최빈값은?", "3"),
    BatteryCase("5개의 변량 3, 7, x, 5, 9 의 평균이 6일 때, x의 값은?", "6"),
    BatteryCase("학생 4명의 수학 점수가 80점, 90점, 70점, 100점일 때, 평균은?", "85"),
    BatteryCase("자료 10, 20, 30, 40 의 중앙값은?", "25"),

    // 비례식 · 백분율 · 문장제
    BatteryCase("비례식 3 : 5 = x : 20 에서 x의 값은?", "12"),
    BatteryCase("x : 4 = 9 : 6 일 때, x의 값을 구하시오.", "6"),
    BatteryCase("8%의 소금물 200g에 들어 있는 소금의 양은 몇 g인가?", "16"),
    BatteryCase("10%의 소금물 300g에 물 100g을 더 넣으면 몇 %의 소금물이 되는가?", "7.5"),
    BatteryCase("6%의 소금물 200g과 10%의 소금물 300g을 섞으면 몇 %의 소금물이 되는가?", "8.4"),
    BatteryCase("시속 60km로 2시간 30분 동안 달린 거리는 몇 km인가?", "150"),
    BatteryCase("집에서 3km 떨어진 도서관까지 시속 4km로 걸어가면 몇 분이 걸리는가?", "45"),
    BatteryCase("정가가 20000원인 옷을 15% 할인하여 팔 때, 판매 가격은?", "17000"),
    BatteryCase("원가가 5000원인 물건에 20%의 이익을 붙여 정가를 정하면 정가는 얼마인가?", "6000"),
    BatteryCase("어떤 일을 A는 6일, B는 3일 만에 끝낸다. 두 사람이 함께 하면 며칠 만에 끝낼 수 있는가?", "2"),
    BatteryCase("현재 아버지의 나이는 42세, 아들의 나이는 12세이다. 아버지의 나이가 아들의 나이의 3배가 되는 것은 몇 년 후인가?", "3"),
    BatteryCase("연속하는 세 자연수의 합이 48일 때, 가장 큰 수는?", "17"),
    BatteryCase("가로의 길이가 세로의 길이보다 3cm 긴 직사각형의 둘레의 길이가 26cm일 때, 가로의 길이는?", "8"),
    BatteryCase("120의 25%는?", "30"),
    BatteryCase("500원은 2000원의 몇 %인가?", "25"),
    BatteryCase("두 지점 A, B 사이를 갈 때는 시속 4km, 올 때는 시속 6km로 걸어서 모두 5시간이 걸렸다. 두 지점 사이의 거리는 몇 km인가?", "12"),

    // 도형
    BatteryCase("직각삼각형에서 직각을 낀 두 변의 길이가 6, 8 일 때, 빗변의 길이는?", "10"),
    BatteryCase("빗변의 길이가 13이고 다른 한 변의 길이가 5인 직각삼각형의 나머지 한 변의 길이는?", "12"),
    BatteryCase("한 변의 길이가 4인 정삼각형의 넓이는?", "4√3"),
    BatteryCase("반지름의 길이가 3인 원의 넓이는?", "9π"),
    BatteryCase("반지름의 길이가 5cm인 원의 둘레의 길이는?", "10π"),
    BatteryCase("삼각형의 세 내각의 크기가 x°, 2x°, 3x° 일 때, x의 값은?", "30"),
    BatteryCase("정육각형의 한 내각의 크기는?", "120"),
    BatteryCase("오각형의 내각의 크기의 합은?", "540"),
    BatteryCase("밑변의 길이가 8cm, 높이가 5cm인 삼각형의 넓이는?", "20"),
    BatteryCase("윗변의 길이가 4, 아랫변의 길이가 8, 높이가 5인 사다리꼴의 넓이는?", "30"),
    BatteryCase("한 변의 길이가 6인 정사각형의 대각선의 길이는?", "6√2"),
    BatteryCase("반지름의 길이가 3인 구의 부피는?", "36π"),
    BatteryCase("가로의 길이가 3, 세로의 길이가 4, 높이가 12인 직육면체의 대각선의 길이는?", "13"),
    BatteryCase("정팔각형의 대각선의 개수는?", "20"),
    BatteryCase("두 점 A(1, 2), B(4, 6) 사이의 거리는?", "5"),
    BatteryCase("두 점 A(2, 3), B(6, 7)을 이은 선분의 중점의 좌표는?", "(4, 5)"),
    BatteryCase("원 x² + y² - 4x + 6y - 3 = 0 의 반지름의 길이는?", "4"),
    BatteryCase("점 (1, 2)와 직선 3x + 4y - 1 = 0 사이의 거리는?", "2"),
    BatteryCase("두 닮은 삼각형의 닮음비가 2 : 3 일 때, 넓이의 비는?", "4:9|~4 : 9"),

    // 수와 연산
    BatteryCase("-3² + (-2)³ ÷ 4 의 값은?", "-11"),
    BatteryCase("(-1/2) × 4 - 3 ÷ (-1/3) 의 값을 구하시오.", "7"),
    BatteryCase("2/3 + 3/4 의 값은?", "17/12"),
    BatteryCase("다음 중 가장 큰 수는?\n① -3 ② 2.5 ③ 7/3 ④ √5 ⑤ 1.9", "2"),
    BatteryCase("24와 36의 최대공약수는?", "12"),
    BatteryCase("12와 18의 최소공배수는?", "36"),
    BatteryCase("|-5| + |3 - 7| 의 값은?", "9"),
    BatteryCase("360을 소인수분해하시오.", "2^3×3^2×5"),
    BatteryCase("순환소수 0.444… 를 기약분수로 나타내면?", "4/9"),

    // 사진 글 모양 (번호·선지 줄·기호가 다르게 읽힌 것)
    BatteryCase("12. 2x+5=3x-2 의 해를 구하시오.", "7"),
    BatteryCase("6. 이차방정식 x^2-x-12=0의 두 근 중 큰 근은?\n① 2 ② 3 ③ 4 ④ 6 ⑤ 12", "3"),
    BatteryCase("2. 3x-1<=2x+4 를 만족하는 x의 값의 범위는?", "x <= 5"),
    BatteryCase("14. y=-x^2+4x+1의 최댓값은?\n① 1 ② 3 ③ 4 ④ 5 ⑤ 7", "4"),
    BatteryCase("10. x^2+8x+16을 인수분해하시오.", "(x+4)^2"),
    BatteryCase("19. 두 점 (-1, 4), (2, -2)를 지나는 직선의 기울기는?\n① -3 ② -2 ③ -1 ④ 1 ⑤ 2", "2"),
    BatteryCase("16. 연립방정식 x+y=10, 2x-y=5 를 풀면?", "x=5, y=5"),
    BatteryCase("1. (2+3i)(1-i)를 계산하면?\n① 5+i ② 5-i ③ -1+i ④ 1+5i ⑤ 5+5i", "1"),
    BatteryCase("20. 첫째항이 5, 공차가 -2인 등차수열의 제8항은?\n① -11 ② -9 ③ -7 ④ 7 ⑤ 9", "2"),
    BatteryCase("18. lim x→1 (x^2-1)/(x-1)의 값은?\n① 0 ② 1 ③ 2 ④ 3 ⑤ 4", "3"),
    BatteryCase("22. ∫_0^3 (x^2-2x) dx 의 값은?\n① -1 ② 0 ③ 1 ④ 2 ⑤ 3", "2"),
    BatteryCase("3. 서로 다른 5권의 책 중에서 3권을 고르는 경우의 수는?\n① 6 ② 10 ③ 15 ④ 20 ⑤ 60", "2"),
    BatteryCase("23. f(x)=2x^3-x+3일 때, f'(1)의 값은?\n① 1 ② 3 ③ 5 ④ 6 ⑤ 7", "3"),
    BatteryCase("8. 이차방정식 2x^2-3x-5=0 의 두 근의 합은?\n① -5/2 ② -3/2 ③ 3/2 ④ 5/2 ⑤ 3", "3"),
    BatteryCase("5. x=2, y=-1일 때 3x-2y의 값은?\n① 4 ② 6 ③ 8 ④ 10 ⑤ 12", "3"),
    BatteryCase("9. 자료 5, 7, 8, 8, 12 의 평균은?\n① 7 ② 7.5 ③ 8 ④ 8.5 ⑤ 9", "3"),
    BatteryCase("11. √18×√2 의 값은?\n① 3 ② 4 ③ 6 ④ 9 ⑤ 12", "3"),
    BatteryCase("7. log3 27 - log2 4 의 값은?", "1"),
    BatteryCase("4. 부등식 |x+1|<=2 의 해는?", "-3 <= x <= 1"),
    BatteryCase("13. 다항식 x^3+x^2-4x+5 를 x+2로 나눈 나머지를 구하시오.", "9"),
    BatteryCase("2. 6명 중에서 반장 1명, 부반장 1명을 뽑는 경우의 수는?\n① 15 ② 20 ③ 30 ④ 36 ⑤ 60", "3"),
    BatteryCase("15. 이차함수 y=x^2+2x-3의 꼭짓점의 좌표는?", "(-1, -4)"),
]

/// 엔진 답 글 다듬기: 끝에 붙은 단위·말 ("8 cm", "45분", "(중근)")
private func batteryTidy(_ s: String) -> String {
    var t = s.trimmingCharacters(in: .whitespaces)
    t = t.replacingOccurrences(of: #"\s*\((중근|서로 같은 두 실근)\)\s*$"#, with: "", options: .regularExpression)
    t = t.replacingOccurrences(of: #"(?<=[0-9π√)])\s*(cm²|cm³|cm|km|m²|m|kg|g|원|분|시간|초|%|개|마리|명|가지|°|도|세|년 후|년|일|권|번|배|점|L|mL)$"#, with: "", options: .regularExpression)
    return t
}

/// "y = 3x − 1"과 "y = 3x - 1"처럼 직선·함수식이 같은지 (오른쪽 식에 여러 x를 넣어 비교)
private func batterySameFunction(_ a: String, _ b: String) -> Bool {
    func rhs(_ s: String) -> String? {
        let t = DoitGrader.cleanMath(s)
        for prefix in ["y=", "f^-1(x)=", "f⁻¹(x)=", "(f∘g)(x)=", "f'(x)=", "g(x)=", "f(x)="] where t.hasPrefix(prefix) { return String(t.dropFirst(prefix.count)) }
        return nil
    }
    let x = rhs(a) ?? DoitGrader.cleanMath(a), y = rhs(b) ?? DoitGrader.cleanMath(b)
    guard x.contains("x"), y.contains("x") else { return false }
    var compared = 0
    for v in [-2.3, -0.7, 0.4, 1.9, 3.1] {
        guard let p = Expression.evaluate(x, x: v), let q = Expression.evaluate(y, x: v) else { return false }
        if abs(p - q) > 1e-6 * max(1, abs(p)) { return false }
        compared += 1
    }
    return compared >= 3
}

/// 엔진 답이 정답과 같은지
func batteryMatches(_ answer: String, expected: String) -> Bool {
    let mine = batteryTidy(answer)
    for key in DoitGrader.alternatives(expected, splitOr: false) {
        if key.hasPrefix("~") {
            if DoitGrader.normalizeText(mine).contains(DoitGrader.normalizeText(String(key.dropFirst()))) { return true }
            continue
        }
        if DoitGrader.normalizeText(mine) == DoitGrader.normalizeText(key) { return true }
        if DoitGrader.equivalentMath(mine, key) == true { return true }
        if batterySameFunction(mine, key) { return true }
    }
    return false
}

func runSolverBatteryCases() {
    var correct = 0, unsolved: [String] = [], wrong: [String] = []
    for item in solverBattery {
        let scan = DoitProblemScan.scan(item.text)
        let choices = scan.choices
        let isChoice = choices.count >= 2
        let label = item.text.replacingOccurrences(of: "\n", with: " / ")
        guard let solution = DoitAutoSolve.engine(text: item.text, choices: choices, isChoice: isChoice, body: scan.body) else {
            unsolved.append(label)
            continue
        }
        let answer = solution.finalAnswer
        var right: Bool
        if isChoice {
            if answer.hasPrefix("계산한 값") {
                // 선지와 못 맞춘 값: 정답 선지와 같은 값이면 못 푼 것으로 (번호를 못 골랐을 뿐), 다르면 오답
                let value = answer.replacingOccurrences(of: "계산한 값:", with: "").trimmingCharacters(in: .whitespaces)
                let n = Int(item.answer) ?? 0
                if choices.indices.contains(n - 1), batteryMatches(value, expected: choices[n - 1]) { unsolved.append(label + " (선지 못 맞춤: \(answer))"); continue }
                right = false
            } else {
                right = DoitGrader.choiceNumber(answer, choices: choices).map { "\($0)" == item.answer } ?? false
            }
        } else {
            right = batteryMatches(answer, expected: item.answer)
        }
        if right { correct += 1 } else { wrong.append("\(label) → 엔진 답 '\(answer)', 정답 '\(item.answer)'") }
        check("풀이 배터리 오답 없음: \(label)", right, "엔진 답 '\(answer)', 정답 '\(item.answer)'")
    }
    print("풀이 배터리: 정답 \(correct) / 전체 \(solverBattery.count), 못 풂 \(unsolved.count), 오답 \(wrong.count)")
    for w in wrong { print("  ✗ 오답: " + w) }
    for u in unsolved { print("  · 못 풂: " + u) }
}
