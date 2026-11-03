import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

/// 모티 AI 인터넷 검색 (일반 웹)
/// 1) DuckDuckGo에서 검색 (무료, 키 없음, 검색 기록을 남기지 않는 검색 엔진) — 검색어만 보내고 질문 전체나 계정 정보는 보내지 않아요
/// 2) 위쪽 결과 페이지 몇 개를 열어 본문에서 질문과 관련된 문단만 골라냄
/// 3) 고른 문단은 그대로 보여주지 않고 모델(언어 모델)가 읽고 자기 말로 정리하는 '재료'로만 써요
extension DoitWeb {
    struct Hit: Equatable {
        let title: String
        let url: String
        let snippet: String
        var site: String { URL(string: url)?.host.map(DoitWeb.siteName) ?? "" }
    }

    /// 인터넷 검색을 쓸지 (설정에서 끌 수 있음)
    static var isEnabled: Bool {
        get { UserDefaults.standard.object(forKey: "doitWeb.enabled") as? Bool ?? true }
        set { UserDefaults.standard.set(newValue, forKey: "doitWeb.enabled") }
    }

    /// 일반 웹 검색 → 페이지 본문 읽기. 못 읽은 페이지는 검색 결과 요약(스니펫)으로 대신함
    static func searchWeb(_ query: String, limit: Int, maxChars: Int) async -> [Source] {
        let hits = await search(query)
        guard !hits.isEmpty else { return [] }
        let picked = Array(hits.filter { isUseful($0.url) }.prefix(limit + 2))
        // 페이지는 동시에 열고, 검색 순서대로 정리
        let texts = await withTaskGroup(of: (Int, String?).self) { group -> [Int: String] in
            for (index, hit) in picked.enumerated() {
                group.addTask { (index, await readPage(hit.url, query: query, maxChars: maxChars)) }
            }
            var result: [Int: String] = [:]
            for await (index, text) in group { if let text { result[index] = text } }
            return result
        }
        var sources: [Source] = []
        for (index, hit) in picked.enumerated() where sources.count < limit {
            let body = texts[index] ?? ""
            let text = body.count >= 80 ? body : hit.snippet
            guard text.count >= 30 else { continue }
            sources.append(Source(title: hit.title, url: hit.url, text: text, language: "web", site: hit.site))
        }
        return sources
    }

    // MARK: 검색

    private static let browserAgent = "Mozilla/5.0 (iPhone; CPU iPhone OS 18_0 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/18.0 Mobile/15E148 Safari/604.1"

    static func search(_ query: String) async -> [Hit] {
        for endpoint in ["https://html.duckduckgo.com/html/", "https://lite.duckduckgo.com/lite/"] {
            guard var components = URLComponents(string: endpoint) else { continue }
            components.queryItems = [URLQueryItem(name: "q", value: query), URLQueryItem(name: "kl", value: "kr-kr")]
            guard let url = components.url, let html = await fetchHTML(url, timeout: 10, maxBytes: 600_000) else { continue }
            let hits = parseDuckDuckGo(html)
            if !hits.isEmpty { return hits }
        }
        return []
    }

    /// DuckDuckGo 검색 결과 HTML 읽기 (html·lite 두 형식 모두)
    static func parseDuckDuckGo(_ html: String) -> [Hit] {
        let linkPattern = #"<a[^>]*class=['"][^'"]*(?:result__a|result-link)[^'"]*['"][^>]*>(.*?)</a>"#
        let snippetPattern = #"<(?:a|td|div)[^>]*class=['"][^'"]*(?:result__snippet|result-snippet)[^'"]*['"][^>]*>(.*?)</(?:a|td|div)>"#
        let links = matches(linkPattern, in: html)
        let snippets = matches(snippetPattern, in: html)
        var hits: [Hit] = []
        var seen = Set<String>()
        for (index, link) in links.enumerated() {
            guard let href = attribute("href", in: link.whole), let url = resolve(href), seen.insert(url).inserted else { continue }
            let title = plainText(link.inner)
            guard !title.isEmpty else { continue }
            // 이 결과의 요약: 이 링크 뒤, 다음 링크 앞에 있는 것 (광고처럼 요약이 없는 결과가 있어도 어긋나지 않게)
            let end = index + 1 < links.count ? links[index + 1].location : Int.max
            let snippet = snippets.first { $0.location > link.location && $0.location < end }.map { plainText($0.inner) } ?? ""
            hits.append(Hit(title: title, url: url, snippet: snippet))
        }
        return hits
    }

    /// DuckDuckGo 중간 주소(//duckduckgo.com/l/?uddg=…)를 실제 주소로. 광고·https가 아닌 주소는 버림
    static func resolve(_ href: String) -> String? {
        var link = decodeEntities(href)
        if link.hasPrefix("//") { link = "https:" + link }
        guard var components = URLComponents(string: link) else { return nil }
        if components.host?.hasSuffix("duckduckgo.com") == true {
            guard components.path.hasPrefix("/l/"), let target = components.queryItems?.first(where: { $0.name == "uddg" })?.value,
                  let real = URLComponents(string: target) else { return nil }
            components = real
        }
        guard components.scheme == "https", let host = components.host, !host.isEmpty else { return nil }
        // 네이버 블로그는 본문이 프레임 안에 있어서 모바일 주소로 읽음
        if host == "blog.naver.com" { components.host = "m.blog.naver.com" }
        return components.url?.absoluteString
    }

    /// 읽을 만한 페이지인지 (동영상·SNS·파일·로그인 페이지 제외)
    static func isUseful(_ url: String) -> Bool {
        guard let components = URLComponents(string: url), let host = components.host?.lowercased() else { return false }
        let blockedHosts = ["youtube.com", "youtu.be", "instagram.com", "facebook.com", "tiktok.com", "x.com", "twitter.com",
                            "pinterest.com", "accounts.google.com", "play.google.com", "apps.apple.com", "coupang.com"]
        if blockedHosts.contains(where: { host == $0 || host.hasSuffix("." + $0) }) { return false }
        let path = components.path.lowercased()
        if [".pdf", ".hwp", ".doc", ".docx", ".ppt", ".pptx", ".xls", ".xlsx", ".zip", ".jpg", ".png", ".mp4"].contains(where: { path.hasSuffix($0) }) { return false }
        if ["login", "signin", "signup"].contains(where: { path.contains($0) }) { return false }
        return true
    }

    /// 출처에 보여줄 사이트 이름 (www. 떼기)
    static func siteName(_ host: String) -> String {
        let h = host.lowercased()
        let known = ["namu.wiki": "나무위키", "ko.wikipedia.org": "위키백과", "en.wikipedia.org": "영어 위키백과",
                     "m.blog.naver.com": "네이버 블로그", "blog.naver.com": "네이버 블로그", "terms.naver.com": "네이버 지식백과",
                     "kin.naver.com": "네이버 지식iN", "encykorea.aks.ac.kr": "한국민족문화대백과", "brunch.co.kr": "브런치",
                     "tistory.com": "티스토리", "stdict.korean.go.kr": "표준국어대사전", "korean.go.kr": "국립국어원"]
        if let name = known[h] { return name }
        if h.hasSuffix(".tistory.com") { return "티스토리" }
        return h.hasPrefix("www.") ? String(h.dropFirst(4)) : h
    }

    // MARK: 페이지 읽기

    static func readPage(_ url: String, query: String, maxChars: Int) async -> String? {
        guard let link = URL(string: url), let html = await fetchHTML(link, timeout: 8, maxBytes: 1_500_000) else { return nil }
        let text = readableText(html, query: query, maxChars: maxChars)
        return text.isEmpty ? nil : text
    }

    /// HTML에서 본문 문단만 골라 질문과 관련된 부분을 앞세움
    static func readableText(_ rawHTML: String, query: String, maxChars: Int) -> String {
        var html = String(rawHTML.prefix(700_000))
        // 본문이 아닌 부분 지우기
        for tag in ["script", "style", "noscript", "svg", "header", "footer", "nav", "aside", "form", "button", "select", "iframe", "template"] {
            html = html.replacingOccurrences(of: "(?is)<\(tag)\\b[^>]*>.*?</\(tag)>", with: " ", options: .regularExpression)
        }
        html = html.replacingOccurrences(of: "(?s)<!--.*?-->", with: " ", options: .regularExpression)
        // 문단 끝은 줄바꿈으로
        html = html.replacingOccurrences(of: "(?i)<br\\s*/?>|</(p|li|h[1-6]|div|tr|td|th|dd|dt|blockquote|section|article)>", with: "\n", options: .regularExpression)
        let lines = plainText(html, keepNewlines: true).components(separatedBy: "\n")
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter(isContentLine)
        guard !lines.isEmpty else { return "" }
        // 질문 낱말이 들어 있는 문단을 앞세우고, 원래 순서는 지킴
        let keywords = query.lowercased().split(separator: " ").map(String.init).filter { $0.count >= 2 }
        let scored = lines.enumerated().map { index, line -> (Int, String, Int) in
            let lower = line.lowercased()
            return (index, line, keywords.filter { lower.contains($0) }.count)
        }
        var chosen = scored.filter { $0.2 > 0 }
        if chosen.count < 2 { chosen = Array(scored.prefix(6)) }
        chosen.sort { $0.0 < $1.0 }
        var text = ""
        var seen = Set<String>()
        for item in chosen where seen.insert(item.1).inserted {
            if text.count + item.1.count > maxChars { break }
            text += (text.isEmpty ? "" : "\n") + item.1
        }
        if text.isEmpty, let first = chosen.first { text = String(first.1.prefix(maxChars)) }
        return text
    }

    /// 메뉴·광고·저작권 같은 줄 거르기
    static func isContentLine(_ line: String) -> Bool {
        guard line.count >= 30 else { return false }
        let junk = ["로그인", "회원가입", "쿠키", "cookie", "copyright", "©", "all rights reserved", "무단 전재", "무단전재", "구독하기", "공유하기",
                    "댓글", "이전글", "다음글", "광고", "javascript", "기사제보", "고객센터", "개인정보처리방침", "이용약관", "바로가기", "본문으로"]
        let lower = line.lowercased()
        if junk.contains(where: { lower.contains($0) }) && line.count < 120 { return false }
        // 낱말이 거의 없는 줄 (메뉴 나열, 해시태그)
        let words = line.split(separator: " ")
        if words.count < 4 { return false }
        if line.filter({ $0 == "#" || $0 == "|" || $0 == "·" }).count > words.count / 2 { return false }
        return true
    }

    // MARK: 공통

    private static func fetchHTML(_ url: URL, timeout: TimeInterval, maxBytes: Int) async -> String? {
        var request = URLRequest(url: url)
        request.timeoutInterval = timeout
        request.setValue(browserAgent, forHTTPHeaderField: "User-Agent")
        request.setValue("ko-KR,ko;q=0.9,en;q=0.7", forHTTPHeaderField: "Accept-Language")
        request.setValue("text/html,application/xhtml+xml", forHTTPHeaderField: "Accept")
        guard let (data, response) = try? await URLSession.shared.data(for: request),
              let http = response as? HTTPURLResponse, http.statusCode == 200, data.count <= maxBytes * 2 else { return nil }
        if let type = http.value(forHTTPHeaderField: "Content-Type")?.lowercased(), !type.contains("html") && !type.contains("text") { return nil }
        return decode(data.prefix(maxBytes), charset: http.textEncodingName)
    }

    /// 글자 인코딩 맞추기 (한국 사이트는 EUC-KR도 있음)
    static func decode(_ data: Data, charset: String?) -> String? {
        let head = String(decoding: data.prefix(3000), as: UTF8.self).lowercased()
        let declared = (charset ?? head.firstMatch(of: #/charset=["']?([a-z0-9_\-]+)/#).map { String($0.1) } ?? "utf-8").lowercased()
        if ["euc-kr", "ks_c_5601-1987", "cp949", "x-windows-949", "ksc5601"].contains(declared) {
            #if canImport(Darwin)
            // 0x0422 = kCFStringEncodingDOSKorean (CP949, EUC-KR을 포함)
            let encoding = String.Encoding(rawValue: CFStringConvertEncodingToNSStringEncoding(CFStringEncoding(0x0422)))
            if let text = String(data: data, encoding: encoding) { return text }
            #endif
        }
        return String(data: data, encoding: .utf8) ?? String(decoding: data, as: UTF8.self)
    }

    private static func matches(_ pattern: String, in text: String) -> [(whole: String, inner: String, location: Int)] {
        guard let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive, .dotMatchesLineSeparators]) else { return [] }
        let ns = text as NSString
        return regex.matches(in: text, range: NSRange(location: 0, length: ns.length)).map { m in
            (ns.substring(with: m.range), m.numberOfRanges > 1 ? ns.substring(with: m.range(at: 1)) : "", m.range.location)
        }
    }

    private static func attribute(_ name: String, in tag: String) -> String? {
        matches("\\b\(name)\\s*=\\s*['\"]([^'\"]*)['\"]", in: tag).first?.inner
    }

    /// 태그 지우고 글자만 (HTML 기호 풀기)
    static func plainText(_ html: String, keepNewlines: Bool = false) -> String {
        var t = html.replacingOccurrences(of: "<[^>]+>", with: " ", options: .regularExpression)
        t = decodeEntities(t)
        t = t.replacingOccurrences(of: "[ \t\u{00A0}]+", with: " ", options: .regularExpression)
        if !keepNewlines { t = t.replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression) }
        return t.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    static func decodeEntities(_ text: String) -> String {
        guard text.contains("&") else { return text }
        var t = text
        for (entity, value) in [("&nbsp;", " "), ("&lt;", "<"), ("&gt;", ">"), ("&quot;", "\""), ("&#39;", "'"), ("&apos;", "'"),
                                ("&middot;", "·"), ("&hellip;", "…"), ("&ndash;", "–"), ("&mdash;", "—"), ("&lsquo;", "‘"), ("&rsquo;", "’"),
                                ("&ldquo;", "“"), ("&rdquo;", "”")] {
            t = t.replacingOccurrences(of: entity, with: value)
        }
        // &#1234; / &#x4E00;
        while let m = t.firstMatch(of: #/&#(x?)([0-9a-fA-F]{1,6});/#) {
            let value = m.1.isEmpty ? UInt32(m.2, radix: 10) : UInt32(m.2, radix: 16)
            let replacement = value.flatMap(Unicode.Scalar.init).map { String(Character($0)) } ?? ""
            t.replaceSubrange(m.range, with: replacement)
        }
        return t.replacingOccurrences(of: "&amp;", with: "&")
    }
}
