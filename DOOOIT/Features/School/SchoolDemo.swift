#if DEBUG
import Foundation

/// 화면 사진용 가짜 학교 자료 (Debug 빌드에서만 · 네트워크 없음 · 실제 학교와 상관없는 이름)
enum SchoolDemo {
    static let school = School(officeCode: "B10", schoolCode: "9999999", name: "한빛중학교", kindName: "중학교",
                               region: "서울특별시", address: "서울특별시 한빛구 한빛로 1")
    static let selection = SchoolSelection(school: school, grade: 2, classNum: 3)

    static let searchResults: [School] = [
        school,
        School(officeCode: "B10", schoolCode: "9999998", name: "한빛초등학교", kindName: "초등학교", region: "서울특별시", address: ""),
        School(officeCode: "J10", schoolCode: "9999997", name: "한빛여자중학교", kindName: "중학교", region: "경기도", address: ""),
        School(officeCode: "D10", schoolCode: "9999996", name: "한빛고등학교", kindName: "고등학교", region: "대구광역시", address: "", highSchoolType: "일반고")
    ]

    static var isOn: Bool { UIShot.matches(.school, .schoolMeal, .schoolSetup, .homeSchool) }

    // 월~금 시간표 (교시 1…7)
    private static let table: [[String]] = [
        ["국어", "수학", "영어", "과학", "사회", "체육", "창의적 체험활동"],
        ["수학", "영어", "국어", "음악", "미술", "과학", "도덕"],
        ["영어", "과학", "수학", "국어", "체육", "체육", ""],
        ["사회", "국어", "수학", "영어", "기술·가정", "기술·가정", "과학"],
        ["과학", "영어", "국어", "수학", "도덕", "창의적 체험활동", "창의적 체험활동"]
    ]

    static func timetable(selection: SchoolSelection, weekStart: String) -> TimetableWeek? {
        guard isOn else { return nil }
        var cells: [TimetableCell] = []
        for (d, day) in table.enumerated() {
            guard let ymd = NeisDate.addDays(weekStart, d) else { continue }
            for (p, subject) in day.enumerated() where !subject.isEmpty {
                cells.append(TimetableCell(ymd: ymd, period: p + 1, subject: subject))
            }
        }
        return TimetableWeek(weekStart: weekStart, cells: cells)
    }

    private static let lunch: [[String]] = [
        ["흑미밥", "미역국 (5.6.16)", "제육볶음 (5.6.10.13)", "시금치나물 (5.6)", "배추김치 (9)", "우유 (2)"],
        ["잡곡밥", "닭곰탕 (5.6.15)", "새우볶음밥 (5.6.9.18)", "콩나물무침 (5)", "깍두기 (9)", "사과"],
        ["쌀밥", "된장찌개 (5.6.13)", "함박스테이크 (1.2.5.6.10.16)", "브로콜리 샐러드 (1.5.13)", "배추김치 (9)"],
        ["카레라이스 (5.6.10.13)", "계란국 (1.5)", "치킨너겟 (1.2.5.6.15)", "단무지무침", "배추김치 (9)", "요구르트 (2)"],
        ["보리밥", "순두부찌개 (5.9.10)", "고등어구이 (7)", "도토리묵무침 (5.6.13)", "깍두기 (9)", "귤"]
    ]

    static func meals(school: School, weekStart: String) -> MealRange? {
        guard isOn else { return nil }
        var rows: [NeisParser.Row] = []
        for (d, dishes) in lunch.enumerated() {
            guard let ymd = NeisDate.addDays(weekStart, d) else { continue }
            rows.append([
                "MLSV_YMD": ymd, "MMEAL_SC_CODE": "2", "MMEAL_SC_NM": "중식",
                "DDISH_NM": dishes.joined(separator: "<br/>"),
                "CAL_INFO": ["696.8", "646.8", "712.4", "688.1", "654.3"][d] + " Kcal",
                "NTR_INFO": "탄수화물(g) : 95.3<br/>단백질(g) : 29.0<br/>지방(g) : 20.7<br/>칼슘(mg) : 251.9"
            ])
            if d < 4 {
                rows.append([
                    "MLSV_YMD": ymd, "MMEAL_SC_CODE": "3", "MMEAL_SC_NM": "석식",
                    "DDISH_NM": "쌀밥<br/>어묵국 (1.5.6.13)<br/>떡갈비 (1.5.6.10.16)<br/>김치볶음 (5.6.9)<br/>배추김치 (9)",
                    "CAL_INFO": "803.2 Kcal",
                    "NTR_INFO": "탄수화물(g) : 120.4<br/>단백질(g) : 35.2<br/>지방(g) : 22.0"
                ])
            }
        }
        let range = NeisDate.mealRange(weekStart: weekStart)
        return MealRange(fromYMD: range.from, toYMD: range.to, days: NeisParser.mealDays(rows))
    }
}
#endif
