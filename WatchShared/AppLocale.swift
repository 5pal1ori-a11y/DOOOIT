import Foundation

/// 앱 화면 언어 (계정 → 앱 → 언어)
/// - 번역 키는 한국어 원문 (Localizable.xcstrings, 원문 언어 = 한국어)
/// - 고르면 `AppleLanguages`에 저장 (다시 열면 시스템이 그 언어로 엶) + 지금 화면은 그 언어 묶음(lproj)으로 바로 바꿈
/// - 워치 · 워치 위젯은 시스템 언어를 따름 (고른 값이 없으면 `.system`)
enum AppLanguage: String, CaseIterable, Identifiable, Sendable {
    case system
    case ko
    case en
    case zhHans = "zh-Hans"
    case ja

    var id: String { rawValue }

    /// 고르는 목록에 보이는 이름 (각 언어 이름은 그 언어로)
    var displayName: String {
        switch self {
        case .system: return L("시스템 설정 따름")
        case .ko: return "한국어"
        case .en: return "English"
        case .zhHans: return "中文(简体)"
        case .ja: return "日本語"
        }
    }

    /// 위젯이 읽는 App Group 키 (앱이 고른 언어 코드, 시스템이면 지움)
    static let groupKey = "appLanguage"
    /// 앱 화면이 지켜보는 값 (바뀌면 다시 그림). 실제 선택은 AppleLanguages에서 읽음
    static let storageKey = "appLanguage"
    static let appGroup = "group.com.donghyeon.moti"
    static let supported = ["ko", "en", "zh-Hans", "ja"]

    /// 지금 고른 언어 (앱 설정에 저장된 AppleLanguages → 없으면 시스템)
    static var selected: AppLanguage {
        lock.lock(); defer { lock.unlock() }
        if let cachedSelected { return cachedSelected }
        let value = readSelected()
        cachedSelected = value
        return value
    }

    private static func readSelected() -> AppLanguage {
        if let override { return override }
        #if os(watchOS)
        return .system
        #else
        let bundleID = Bundle.main.bundleIdentifier ?? ""
        // 앱 영역에 직접 저장한 값만 봄 (기기 전체 언어 목록과 구분)
        let own = UserDefaults.standard.persistentDomain(forName: bundleID)?["AppleLanguages"] as? [String]
        if let first = own?.first, let lang = match(first) { return lang }
        // 위젯 확장: 앱이 App Group에 적어 둔 언어
        if Bundle.main.bundlePath.hasSuffix(".appex"),
           let code = UserDefaults(suiteName: appGroup)?.string(forKey: groupKey), let lang = match(code) {
            return lang
        }
        return .system
        #endif
    }

    /// 화면 사진(-uiLang)·미리보기에서만 쓰는 강제 언어
    nonisolated(unsafe) static var override: AppLanguage? {
        didSet { clearCache() }
    }

    // 자주 불려서(글자마다) 한 번 읽은 값을 기억 (언어를 바꿀 때 지움)
    nonisolated(unsafe) private static var cachedSelected: AppLanguage?
    nonisolated(unsafe) private static var cachedCode: String?
    nonisolated(unsafe) private static var cachedLocale: Locale?

    private static func clearCache() {
        lock.lock()
        cachedSelected = nil; cachedCode = nil; cachedLocale = nil; bundles.removeAll()
        lock.unlock()
    }

    /// "en-US", "zh-Hans-CN", "ja-JP" → 지원하는 언어
    static func match(_ code: String) -> AppLanguage? {
        let c = code.lowercased()
        if c.hasPrefix("zh") { return .zhHans }
        if c.hasPrefix("ko") { return .ko }
        if c.hasPrefix("en") { return .en }
        if c.hasPrefix("ja") { return .ja }
        return nil
    }

    /// 실제로 보이는 언어 코드 (ko · en · zh-Hans · ja)
    static var code: String {
        lock.lock()
        if let cachedCode { lock.unlock(); return cachedCode }
        lock.unlock()
        let value = readCode()
        lock.lock(); cachedCode = value; lock.unlock()
        return value
    }

    private static func readCode() -> String {
        let s = selected
        if s != .system { return s.rawValue }
        // 시스템: 기기 언어 목록에서 지원하는 첫 언어 (앱에서 "시스템"으로 되돌린 직후에도 바로 맞게)
        let list = UserDefaults.standard.stringArray(forKey: "AppleLanguages") ?? Locale.preferredLanguages
        if let lang = list.lazy.compactMap(match).first { return lang.rawValue }
        let first = Bundle.main.preferredLocalizations.first ?? "ko"
        return match(first)?.rawValue ?? "ko"
    }

    static var isKorean: Bool { code == "ko" }

    /// 날짜·숫자에 쓰는 지역 설정 (언어는 고른 것, 나라는 기기 그대로)
    static var locale: Locale {
        let c = code
        lock.lock()
        if let cachedLocale { lock.unlock(); return cachedLocale }
        lock.unlock()
        let region = Locale.current.region?.identifier ?? "KR"
        let value = c == "zh-Hans" ? Locale(identifier: "zh_Hans_\(region)") : Locale(identifier: "\(c)_\(region)")
        lock.lock(); cachedLocale = value; lock.unlock()
        return value
    }

    /// 번역을 찾는 묶음: 고른 언어의 lproj (없으면 앱 묶음 그대로)
    static var bundle: Bundle {
        let c = code
        lock.lock(); defer { lock.unlock() }
        if let cached = bundles[c] { return cached }
        var found = Bundle.main
        if Bundle.main.preferredLocalizations.first != c,
           let path = Bundle.main.path(forResource: c, ofType: "lproj"), let b = Bundle(path: path) {
            found = b
        }
        bundles[c] = found
        return found
    }

    nonisolated(unsafe) private static var bundles: [String: Bundle] = [:]
    private static let lock = NSLock()

    /// 언어 바꾸기: 다음 실행부터 시스템이 그 언어로 열고, 위젯에도 알려 줌
    static func set(_ language: AppLanguage) {
        let defaults = UserDefaults.standard
        let group = UserDefaults(suiteName: appGroup)
        if language == .system {
            defaults.removeObject(forKey: "AppleLanguages")
            group?.removeObject(forKey: groupKey)
        } else {
            defaults.set([language.rawValue], forKey: "AppleLanguages")
            group?.set(language.rawValue, forKey: groupKey)
        }
        clearCache()
        defaults.set(language.rawValue, forKey: storageKey)
    }

    /// 그 언어 묶음에서 바로 찾기 (언어를 고른 직후 안내를 새 언어로 보여 줄 때)
    static func text(_ value: String.LocalizationValue, in language: AppLanguage) -> String {
        guard language != .system, let path = Bundle.main.path(forResource: language.rawValue, ofType: "lproj"),
              let b = Bundle(path: path) else { return String(localized: value, bundle: .main) }
        return String(localized: value, bundle: b)
    }

    /// 앱을 켤 때: 지금 언어를 위젯에 알려 줌 (iPhone 설정 앱에서 앱 언어를 바꾼 경우도 따라가게)
    static func syncToWidgets() {
        let group = UserDefaults(suiteName: appGroup)
        let s = selected
        if s == .system { group?.removeObject(forKey: groupKey) } else { group?.set(s.rawValue, forKey: groupKey) }
        UserDefaults.standard.set(s.rawValue, forKey: storageKey)
    }
}

/// 번역 (키 = 한국어 원문). 보간도 됨: `L("\(n)개")` → 키 "%lld개"
func L(_ value: String.LocalizationValue) -> String {
    String(localized: value, bundle: AppLanguage.bundle, locale: AppLanguage.locale)
}

extension String {
    /// 저장된 값·변수(한국어 원문)를 화면에 보일 때 번역 (카탈로그에 없으면 그대로: 사용자가 적은 이름 등)
    var loc: String {
        AppLanguage.bundle.localizedString(forKey: self, value: self, table: nil)
    }
}

extension Date {
    /// 화면용 날짜 글자: 한국어면 그 모양 그대로("M월 d일"), 다른 언어면 같은 내용을 그 언어 모양으로 ("Nov 5", "11月5日")
    func ui(_ pattern: String) -> String {
        AppDateFormat.formatter(pattern).string(from: self)
    }
}

enum AppDateFormat {
    nonisolated(unsafe) private static var cache: [String: DateFormatter] = [:]
    private static let lock = NSLock()

    static func formatter(_ pattern: String) -> DateFormatter {
        let code = AppLanguage.code
        let cacheKey = code + "|" + pattern
        lock.lock(); defer { lock.unlock() }
        if let f = cache[cacheKey] { return f }
        let f = DateFormatter()
        f.calendar = .autoupdatingCurrent
        f.timeZone = .autoupdatingCurrent
        if code == "ko" {
            f.locale = Locale(identifier: "ko_KR")
            f.dateFormat = pattern
        } else if !pattern.contains(where: { $0 == "a" || !$0.isASCII }) {
            // 숫자 모양("M/d", "HH:mm", "E")은 그대로, 요일 이름만 그 언어로
            f.locale = AppLanguage.locale
            f.dateFormat = pattern
        } else {
            let locale = AppLanguage.locale
            f.locale = locale
            f.dateFormat = DateFormatter.dateFormat(fromTemplate: template(pattern), options: 0, locale: locale) ?? pattern
        }
        cache[cacheKey] = f
        return f
    }

    /// 달력 머리 요일 (일요일부터): 일 월 화 / S M T / 日 一 二 / 日 月 火
    static var weekdaySymbols: [String] {
        var cal = Calendar(identifier: .gregorian)
        cal.locale = AppLanguage.locale
        return cal.veryShortStandaloneWeekdaySymbols
    }

    /// 짧은 요일 (일요일부터): 일 월 / Sun Mon / 周日 周一 / 日 月
    static var shortWeekdaySymbols: [String] {
        var cal = Calendar(identifier: .gregorian)
        cal.locale = AppLanguage.locale
        return cal.shortStandaloneWeekdaySymbols
    }

    /// "다음 주 월요일" → "월" / "Mon" / "周一" / "月"
    static func weekdayLabel(_ dayText: String) -> String {
        let day = dayText.replacingOccurrences(of: "다음 주 ", with: "")
        let names = ["일요일", "월요일", "화요일", "수요일", "목요일", "금요일", "토요일"]
        guard !AppLanguage.isKorean, let index = names.firstIndex(of: day) else {
            return day.replacingOccurrences(of: "요일", with: "")
        }
        var cal = Calendar(identifier: .gregorian)
        cal.locale = AppLanguage.locale
        return cal.shortStandaloneWeekdaySymbols[index]
    }

    /// 한국어 모양 → 템플릿 ("M월 d일 EEEE" → "MMMdEEEE", "a h:mm" → "jmm", "yyyy년 M월" → "yyyyMMMM")
    static func template(_ pattern: String) -> String {
        let hasDay = pattern.contains("d")
        var t = ""
        var letters = pattern.filter { $0.isASCII && $0.isLetter }
        // 오전/오후 + 12시간 → 그 언어의 시각 모양
        if letters.contains("a") || letters.contains("h") || letters.contains("H") {
            letters = letters.replacingOccurrences(of: "a", with: "")
                .replacingOccurrences(of: "hh", with: "j").replacingOccurrences(of: "h", with: "j")
                .replacingOccurrences(of: "HH", with: "j").replacingOccurrences(of: "H", with: "j")
        }
        for ch in letters {
            if ch == "M" {
                // 달 이름: 날짜가 있으면 짧게(Nov 5), 달만 있으면 길게(November 2026)
                if !t.contains("M") { t += hasDay ? "MMM" : "MMMM" }
            } else {
                t.append(ch)
            }
        }
        return t
    }
}
