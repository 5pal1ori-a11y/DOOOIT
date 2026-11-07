import Foundation

/// 받은 시간표·급식을 기기에 JSON으로 두는 규칙 (파일 읽기·쓰기는 SchoolStore, 여기는 순수 계산)
enum NeisCache {
    /// 시간표는 6시간, 급식은 12시간 지나면 다시 받음 (그 전에는 저장한 것을 바로 보여 줌)
    static let timetableTTL: TimeInterval = 6 * 3600
    static let mealTTL: TimeInterval = 12 * 3600
    /// 이 숫자가 바뀌면 예전 파일은 버림
    static let version = 1

    struct Envelope<Payload: Codable>: Codable {
        var version: Int
        var savedAt: Date
        var payload: Payload
    }

    static func encode<Payload: Codable>(_ payload: Payload, savedAt: Date) -> Data? {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .secondsSince1970
        return try? encoder.encode(Envelope(version: version, savedAt: savedAt, payload: payload))
    }

    static func decode<Payload: Codable>(_ type: Payload.Type, from data: Data) -> (payload: Payload, savedAt: Date)? {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .secondsSince1970
        guard let envelope = try? decoder.decode(Envelope<Payload>.self, from: data), envelope.version == version else { return nil }
        return (envelope.payload, envelope.savedAt)
    }

    /// 아직 새로운지 (시계가 거꾸로 간 경우도 새롭지 않다고 봄)
    static func isFresh(savedAt: Date, now: Date, ttl: TimeInterval) -> Bool {
        let age = now.timeIntervalSince(savedAt)
        return age >= 0 && age < ttl
    }

    /// 너무 오래된 파일 (30일) — 정리할 때 지움
    static func isStale(savedAt: Date, now: Date) -> Bool {
        now.timeIntervalSince(savedAt) > 30 * 86_400
    }

    // MARK: 파일 이름

    static func timetableFile(_ selection: SchoolSelection, weekStart: String) -> String {
        let s = selection
        let dept = s.department.isEmpty ? "" : "-" + safe(s.department)
        return "tt-\(safe(s.school.officeCode))-\(safe(s.school.schoolCode))-\(s.grade)-\(s.classNum)\(dept)-\(weekStart).json"
    }

    static func mealFile(_ school: School, weekStart: String) -> String {
        "meal-\(safe(school.officeCode))-\(safe(school.schoolCode))-\(weekStart).json"
    }

    /// 파일 이름에 쓸 수 있는 글자만 (영문·숫자는 그대로, 그 밖의 글자는 _와 코드 번호: 한글 학과 이름끼리 겹치지 않게)
    static func safe(_ text: String) -> String {
        var result = ""
        for scalar in text.unicodeScalars {
            if scalar.isASCII, CharacterSet.alphanumerics.contains(scalar) {
                result.unicodeScalars.append(scalar)
            } else {
                result += "_" + String(scalar.value, radix: 16)
            }
        }
        return result
    }

    // MARK: "마지막 업데이트" 글자 (번역 키가 아니라 숫자 조각)

    enum Age: Equatable {
        case justNow
        case minutes(Int)
        case hours(Int)
        case days(Int)
    }

    static func age(savedAt: Date, now: Date) -> Age {
        let seconds = max(0, now.timeIntervalSince(savedAt))
        if seconds < 60 { return .justNow }
        if seconds < 3600 { return .minutes(Int(seconds / 60)) }
        if seconds < 86_400 { return .hours(Int(seconds / 3600)) }
        return .days(Int(seconds / 86_400))
    }
}
