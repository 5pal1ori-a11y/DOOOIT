import Foundation

/// 학교 시간표 · 급식을 불러오고 기기에 저장해 두는 곳
/// - 저장 위치: Application Support/School/*.json (SwiftData 저장소와는 상관없음)
/// - 시간표 6시간, 급식 12시간 안에는 저장한 것을 바로 쓰고, 지나면 다시 받아요
/// - 못 받으면(오프라인 등) 마지막으로 저장한 것을 "마지막 업데이트"와 함께 보여 줘요
@MainActor
final class SchoolStore {
    static let shared = SchoolStore()

    struct Loaded<Value> {
        var value: Value
        var savedAt: Date
        /// 새로 받지 못하고 저장해 둔 것을 보여 주는 중
        var offline: Bool
    }

    private let client: NeisClient
    private let directory: URL
    private var memory: [String: (savedAt: Date, data: Data)] = [:]

    init(client: NeisClient = NeisClient(), directory: URL? = nil) {
        self.client = client
        let base = directory ?? (FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? FileManager.default.temporaryDirectory).appendingPathComponent("School", isDirectory: true)
        self.directory = base
    }

    // MARK: 학교 찾기 · 학과

    func searchSchools(name: String, office: String) async throws -> (schools: [School], truncated: Bool) {
        let result = try await client.searchSchools(name: name, office: office)
        return (result.schools, result.truncated)
    }

    func departments(for school: School) async -> (names: [String], complete: Bool) {
        (try? await client.departments(for: school)) ?? ([], false)
    }

    // MARK: 시간표

    func timetable(for selection: SchoolSelection, weekStart: String, refresh: Bool = false) async throws -> Loaded<TimetableWeek> {
        #if DEBUG
        if let demo = SchoolDemo.timetable(selection: selection, weekStart: weekStart) { return Loaded(value: demo, savedAt: Date(), offline: false) }
        #endif
        let file = NeisCache.timetableFile(selection, weekStart: weekStart)
        let cached = read(TimetableWeek.self, file: file)
        let now = Date()
        if let cached, !refresh, NeisCache.isFresh(savedAt: cached.savedAt, now: now, ttl: NeisCache.timetableTTL) {
            return Loaded(value: cached.value, savedAt: cached.savedAt, offline: false)
        }
        do {
            let week = try await client.timetable(for: selection, weekStart: weekStart)
            // 일부만 받은 경우에는 저장해 둔 완전한 것이 있으면 그대로 둠
            if week.incomplete == true, let cached, cached.value.incomplete != true, !cached.value.isEmpty {
                return Loaded(value: cached.value, savedAt: cached.savedAt, offline: false)
            }
            write(week, file: file, at: now)
            return Loaded(value: week, savedAt: now, offline: false)
        } catch is CancellationError {
            throw CancellationError()
        } catch {
            if let cached { return Loaded(value: cached.value, savedAt: cached.savedAt, offline: true) }
            throw error
        }
    }

    // MARK: 급식

    func meals(for school: School, weekStart: String, refresh: Bool = false) async throws -> Loaded<MealRange> {
        #if DEBUG
        if let demo = SchoolDemo.meals(school: school, weekStart: weekStart) { return Loaded(value: demo, savedAt: Date(), offline: false) }
        #endif
        let file = NeisCache.mealFile(school, weekStart: weekStart)
        let cached = read(MealRange.self, file: file)
        let now = Date()
        if let cached, !refresh, NeisCache.isFresh(savedAt: cached.savedAt, now: now, ttl: NeisCache.mealTTL) {
            return Loaded(value: cached.value, savedAt: cached.savedAt, offline: false)
        }
        do {
            let range = try await client.meals(for: school, weekStart: weekStart)
            write(range, file: file, at: now)
            return Loaded(value: range, savedAt: now, offline: false)
        } catch is CancellationError {
            throw CancellationError()
        } catch {
            if let cached { return Loaded(value: cached.value, savedAt: cached.savedAt, offline: true) }
            throw error
        }
    }

    // MARK: 저장 · 정리

    private func read<Value: Codable>(_ type: Value.Type, file: String) -> (value: Value, savedAt: Date)? {
        if let hit = memory[file], let decoded = NeisCache.decode(type, from: hit.data) { return (decoded.payload, decoded.savedAt) }
        guard let data = try? Data(contentsOf: directory.appendingPathComponent(file)),
              let decoded = NeisCache.decode(type, from: data) else { return nil }
        memory[file] = (decoded.savedAt, data)
        return (decoded.payload, decoded.savedAt)
    }

    private func write<Value: Codable>(_ value: Value, file: String, at date: Date) {
        guard let data = NeisCache.encode(value, savedAt: date) else { return }
        memory[file] = (date, data)
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        try? data.write(to: directory.appendingPathComponent(file), options: .atomic)
    }

    /// 30일 넘은 파일 지우기 (앱을 켤 때 한 번)
    func cleanUp(now: Date = Date()) {
        let files = (try? FileManager.default.contentsOfDirectory(at: directory, includingPropertiesForKeys: [.contentModificationDateKey])) ?? []
        for url in files {
            let date = (try? url.resourceValues(forKeys: [.contentModificationDateKey]))?.contentModificationDate ?? now
            if NeisCache.isStale(savedAt: date, now: now) { try? FileManager.default.removeItem(at: url) }
        }
    }
}
