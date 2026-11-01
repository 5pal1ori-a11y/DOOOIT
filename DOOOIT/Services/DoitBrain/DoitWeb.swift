import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

/// 두잇 AI 인터넷 검색: 위키백과(한국어 → 없으면 영어)에서 자료를 찾아 가져옴 (무료, 키 없음)
/// 가져온 글은 그대로 보여주지 않고, 두잇 AI 두뇌(언어 모델)가 읽고 자기 말로 정리하는 '재료'로만 써요.
enum DoitWeb {
    struct Source: Codable, Hashable {
        let title: String
        let url: String
        let text: String
        let language: String

        var label: String { "위키백과(\(language == "ko" ? "한국어" : "영어")) 「\(title)」" }
    }

    enum WebError: LocalizedError {
        case offline, notFound
        var errorDescription: String? {
            switch self {
            case .offline: return "인터넷에 연결할 수 없어요."
            case .notFound: return "인터넷에서 자료를 찾지 못했어요."
            }
        }
    }

    private actor Cache {
        var store: [String: [Source]] = [:]
        func get(_ key: String) -> [Source]? { store[key] }
        func set(_ key: String, _ value: [Source]) {
            if store.count > 60 { store.removeAll() }
            store[key] = value
        }
    }
    private static let cache = Cache()

    /// 질문과 관련된 자료 (최대 limit개, 글자 수 제한)
    static func research(_ question: String, limit: Int = 2, maxChars: Int = 900) async -> [Source] {
        let query = searchQuery(from: question)
        guard query.count >= 2 else { return [] }
        if let cached = await cache.get(query) { return cached }
        var sources: [Source] = []
        for language in ["ko", "en"] where sources.isEmpty {
            let q = language == "en" ? englishQuery(query) : query
            guard !q.isEmpty, let titles = try? await search(q, language: language), !titles.isEmpty else { continue }
            for title in titles.prefix(limit) {
                if let text = try? await extract(title, language: language), text.count >= 40 {
                    sources.append(Source(title: title, url: pageURL(title, language: language), text: String(text.prefix(maxChars)), language: language))
                }
            }
        }
        await cache.set(query, sources)
        return sources
    }

    // MARK: 검색어 만들기

    /// "광합성이 뭐야?" → "광합성", "임진왜란은 왜 일어났어" → "임진왜란 원인"
    static func searchQuery(from question: String) -> String {
        var t = question.components(separatedBy: "\n").first ?? question
        let tokens0 = t.split(separator: " ").map(String.init)
        let asksWhy = tokens0.contains { $0 == "왜" || $0.hasPrefix("이유") || $0.hasPrefix("원인") } || t.contains("왜 ")
        // 낱말 안에 들어 있지 않은 긴 표현은 글자째로 지움
        let phrases = ["에 대해서", "에 대해", "에대해", "설명해줘", "설명해 줘", "알려줘", "알려 줘", "가르쳐줘", "뭐야", "뭔가요", "뭐예요",
                       "무엇인가요", "궁금해", "찾아줘", "찾아봐", "검색해줘", "인터넷에서", "조사해줘", "일어났어", "됐어", "되는 거야", "하는 거야",
                       "인 거야", "해줘", "?", "!"]
        for word in phrases.sorted(by: { $0.count > $1.count }) { t = t.replacingOccurrences(of: word, with: " ") }
        // 짧은 말은 낱말 하나일 때만 지움 ("임진왜란" 속 "왜"는 그대로)
        let drops: Set<String> = ["왜", "이유", "원인", "무엇", "개념", "정의", "의미", "좀", "어떻게", "설명", "검색", "인터넷", "자세히", "이란", "뭐", "다시"]
        let particles = ["이란", "란", "은", "는", "이", "가", "을", "를", "의", "에", "이야", "야", "요", "로", "으로", "와", "과"]
        let words = t.split(separator: " ").map { word -> String in
            var w = String(word)
            for p in particles where w.count > p.count + 1 && w.hasSuffix(p) { w.removeLast(p.count); break }
            return w
        }.filter { !$0.isEmpty && !drops.contains($0) }
        var query = words.prefix(5).joined(separator: " ")
        if asksWhy && !query.isEmpty { query += " 원인" }
        return query.trimmingCharacters(in: .whitespaces)
    }

    /// 한국어 질문에 영어 낱말이 섞여 있으면 그것만 (영어 위키백과 검색용)
    private static func englishQuery(_ query: String) -> String {
        let latin = query.split(separator: " ").filter { $0.allSatisfy { $0.isASCII } }
        return latin.joined(separator: " ")
    }

    // MARK: 위키백과 API

    private static func pageURL(_ title: String, language: String) -> String {
        "https://\(language).wikipedia.org/wiki/" + (title.replacingOccurrences(of: " ", with: "_")
            .addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? "")
    }

    private static func search(_ query: String, language: String) async throws -> [String] {
        let json = try await request(language: language, params: [
            "action": "query", "list": "search", "srsearch": query, "srlimit": "4", "srprop": "", "format": "json", "utf8": "1"
        ])
        let results = ((json["query"] as? [String: Any])?["search"] as? [[String: Any]]) ?? []
        return results.compactMap { $0["title"] as? String }
            .filter { !$0.contains("(동음이의)") && !$0.hasSuffix("목록") && !$0.contains("disambiguation") }
    }

    private static func extract(_ title: String, language: String) async throws -> String {
        let json = try await request(language: language, params: [
            "action": "query", "prop": "extracts", "explaintext": "1", "exintro": "1", "redirects": "1",
            "titles": title, "format": "json", "utf8": "1"
        ])
        let pages = ((json["query"] as? [String: Any])?["pages"] as? [String: Any]) ?? [:]
        guard let page = pages.values.first as? [String: Any], let text = page["extract"] as? String, !text.isEmpty else {
            throw WebError.notFound
        }
        return clean(text)
    }

    private static func clean(_ text: String) -> String {
        var t = text
        t = t.replacingOccurrences(of: #"\((영어|라틴어|독일어|프랑스어|그리스어|일본어|중국어|한자|문화어)[^)]*\)"#, with: "", options: .regularExpression)
        t = t.replacingOccurrences(of: #"\[\d+\]"#, with: "", options: .regularExpression)
        t = t.replacingOccurrences(of: #"\{\\displaystyle[^}]*\}"#, with: "", options: .regularExpression)
        t = t.replacingOccurrences(of: #"[ \t]{2,}"#, with: " ", options: .regularExpression)
        t = t.replacingOccurrences(of: #"\n{2,}"#, with: "\n", options: .regularExpression)
        return t.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static func request(language: String, params: [String: String]) async throws -> [String: Any] {
        guard ["ko", "en"].contains(language), var components = URLComponents(string: "https://\(language).wikipedia.org/w/api.php") else {
            throw WebError.offline
        }
        components.queryItems = params.map { URLQueryItem(name: $0.key, value: $0.value) }
        guard let url = components.url else { throw WebError.offline }
        var request = URLRequest(url: url)
        request.timeoutInterval = 12
        // 위키미디어 정책: 앱 이름이 드러나는 User-Agent
        request.setValue("DOOOIT/1.0 (iOS study planner)", forHTTPHeaderField: "User-Agent")
        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            guard (response as? HTTPURLResponse)?.statusCode == 200 else { throw WebError.offline }
            return (try JSONSerialization.jsonObject(with: data) as? [String: Any]) ?? [:]
        } catch let error as WebError {
            throw error
        } catch {
            throw WebError.offline
        }
    }
}
