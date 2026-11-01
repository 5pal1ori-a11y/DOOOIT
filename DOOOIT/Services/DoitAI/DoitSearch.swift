import Foundation

/// 두잇 AI 검색: 한국어 위키백과에서 개념을 찾아 읽음 (무료·키 없음, AI 아님)
/// 위키백과 글은 CC BY-SA 라이선스라 화면에 출처를 함께 보여줌
enum DoitSearch {
    struct Hit: Hashable {
        let title: String
        let snippet: String
    }

    struct Article {
        let title: String
        let text: String
        var url: URL? {
            URL(string: "https://ko.wikipedia.org/wiki/" + (title.replacingOccurrences(of: " ", with: "_")
                .addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? ""))
        }
        var source: String { "출처: 위키백과 「\(title)」" }
        var sentences: [String] { DoitSearch.sentences(text) }
    }

    enum SearchError: LocalizedError {
        case notFound(String)
        case network

        var errorDescription: String? {
            switch self {
            case .notFound(let query): return "'\(query)'에 대한 자료를 찾지 못했어요. 단원 이름을 조금 다르게 써보세요."
            case .network: return "검색하려면 인터넷 연결이 필요해요."
            }
        }
    }

    private static let endpoint = "https://ko.wikipedia.org/w/api.php"
    private static let cache = Cache()

    private actor Cache {
        var articles: [String: Article] = [:]
        var searches: [String: [Hit]] = [:]
        func article(_ key: String) -> Article? { articles[key] }
        func setArticle(_ key: String, _ value: Article) { articles[key] = value }
        func search(_ key: String) -> [Hit]? { searches[key] }
        func setSearch(_ key: String, _ value: [Hit]) { searches[key] = value }
    }

    // MARK: 검색

    static func search(_ query: String, limit: Int = 6) async throws -> [Hit] {
        let q = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !q.isEmpty else { return [] }
        if let cached = await cache.search(q) { return cached }
        let json = try await request([
            "action": "query", "list": "search", "srsearch": q, "srlimit": String(limit),
            "srprop": "snippet", "format": "json", "utf8": "1"
        ])
        let results = ((json["query"] as? [String: Any])?["search"] as? [[String: Any]]) ?? []
        let hits = results.compactMap { item -> Hit? in
            guard let title = item["title"] as? String else { return nil }
            return Hit(title: title, snippet: stripTags(item["snippet"] as? String ?? ""))
        }
        .filter { !$0.title.contains("(동음이의)") && !$0.title.hasSuffix("목록") }
        await cache.setSearch(q, hits)
        return hits
    }

    /// 글 본문 (intro: 첫 문단만)
    static func article(_ title: String, intro: Bool = false, maxChars: Int = 6000) async throws -> Article {
        let key = "\(title)|\(intro)"
        if let cached = await cache.article(key) { return cached }
        var params = [
            "action": "query", "prop": "extracts", "explaintext": "1", "redirects": "1",
            "titles": title, "format": "json", "utf8": "1", "exchars": String(maxChars)
        ]
        if intro { params["exintro"] = "1" }
        let json = try await request(params)
        let pages = ((json["query"] as? [String: Any])?["pages"] as? [String: Any]) ?? [:]
        guard let page = pages.values.first as? [String: Any],
              let extract = page["extract"] as? String, !extract.isEmpty else {
            throw SearchError.notFound(title)
        }
        let article = Article(title: page["title"] as? String ?? title, text: clean(extract))
        await cache.setArticle(key, article)
        return article
    }

    /// 검색해서 가장 잘 맞는 글 하나
    static func bestArticle(for query: String, intro: Bool = false) async throws -> Article {
        let hits = try await search(query)
        guard let first = hits.first else { throw SearchError.notFound(query) }
        // 제목이 검색어를 포함하는 글을 우선
        let compactQuery = query.replacingOccurrences(of: " ", with: "")
        let best = hits.first { compactQuery.contains($0.title.replacingOccurrences(of: " ", with: "")) } ?? first
        return try await article(best.title, intro: intro)
    }

    // MARK: 글 다듬기

    /// 문장 나누기 ("…이다. …한다." 기준), 너무 짧거나 긴 문장 제외
    static func sentences(_ text: String) -> [String] {
        var result: [String] = []
        for paragraph in text.components(separatedBy: "\n") {
            let line = paragraph.trimmingCharacters(in: .whitespaces)
            guard !line.isEmpty, !line.hasPrefix("=") else { continue }
            var current = ""
            let characters = Array(line)
            for (index, character) in characters.enumerated() {
                current.append(character)
                let next = index + 1 < characters.count ? characters[index + 1] : " "
                if (character == "." || character == "?" || character == "!") && next == " " {
                    let previous = current.dropLast().last
                    // 숫자 소수점(3.14)이나 약어는 문장 끝이 아님
                    if let previous, previous.isNumber { continue }
                    result.append(current.trimmingCharacters(in: .whitespaces))
                    current = ""
                }
            }
            if !current.trimmingCharacters(in: .whitespaces).isEmpty { result.append(current.trimmingCharacters(in: .whitespaces)) }
        }
        return result.filter { $0.count >= 15 && $0.count <= 220 && $0.range(of: "[가-힣]", options: .regularExpression) != nil }
    }

    private static func clean(_ text: String) -> String {
        var t = text
        // 괄호 속 외국어 표기·발음 등 제거: (영어: Quadratic function), [1]
        t = t.replacingOccurrences(of: #"\((영어|라틴어|독일어|프랑스어|그리스어|일본어|중국어|한자|문화어)[^)]*\)"#, with: "", options: .regularExpression)
        t = t.replacingOccurrences(of: #"\[\d+\]"#, with: "", options: .regularExpression)
        t = t.replacingOccurrences(of: #"\{\\displaystyle[^}]*\}"#, with: "", options: .regularExpression)
        t = t.replacingOccurrences(of: #" {2,}"#, with: " ", options: .regularExpression)
        return t.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static func stripTags(_ html: String) -> String {
        html.replacingOccurrences(of: "<[^>]+>", with: "", options: .regularExpression)
            .replacingOccurrences(of: "&quot;", with: "\"")
            .replacingOccurrences(of: "&amp;", with: "&")
    }

    private static func request(_ params: [String: String]) async throws -> [String: Any] {
        var components = URLComponents(string: endpoint)!
        components.queryItems = params.map { URLQueryItem(name: $0.key, value: $0.value) }
        guard let url = components.url else { throw SearchError.network }
        var request = URLRequest(url: url)
        request.timeoutInterval = 20
        // 위키미디어 정책: 앱 이름이 드러나는 User-Agent
        request.setValue("DOOOIT/1.0 (iOS study planner)", forHTTPHeaderField: "User-Agent")
        do {
            let (data, _) = try await URLSession.shared.data(for: request)
            return (try JSONSerialization.jsonObject(with: data) as? [String: Any]) ?? [:]
        } catch {
            throw SearchError.network
        }
    }
}
