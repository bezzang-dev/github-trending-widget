import AppIntents
import WidgetKit

// Note: AppEnum requirements declared as `static var` are implemented with `static let`,
// because mutable global state is a concurrency error in Swift 6.

enum TrendingLanguage: String, AppEnum {
    case all, java, javascript, typescript, python, swift, kotlin, go, rust
    case cpp, c, csharp, ruby, php, shell, dart, jupyterNotebook

    static let typeDisplayRepresentation: TypeDisplayRepresentation = "프로그래밍 언어"
    static let caseDisplayRepresentations: [TrendingLanguage: DisplayRepresentation] = [
        .all: "전체", .java: "Java", .javascript: "JavaScript", .typescript: "TypeScript",
        .python: "Python", .swift: "Swift", .kotlin: "Kotlin", .go: "Go", .rust: "Rust",
        .cpp: "C++", .c: "C", .csharp: "C#", .ruby: "Ruby", .php: "PHP", .shell: "Shell",
        .dart: "Dart", .jupyterNotebook: "Jupyter Notebook",
    ]

    /// Percent-encoded path component for `/trending/<slug>`; nil means all languages.
    var pathSlug: String? {
        switch self {
        case .all: nil
        case .cpp: "c%2B%2B"
        case .csharp: "c%23"
        case .jupyterNotebook: "jupyter-notebook"
        default: rawValue
        }
    }

    func label(_ lang: AppLanguage) -> String {
        switch self {
        case .all: lang == .ko ? "전체" : "All"
        case .cpp: "C++"
        case .csharp: "C#"
        case .javascript: "JavaScript"
        case .typescript: "TypeScript"
        case .php: "PHP"
        case .jupyterNotebook: "Jupyter Notebook"
        default: rawValue.prefix(1).uppercased() + rawValue.dropFirst()
        }
    }
}

enum TrendingPeriod: String, AppEnum {
    case daily, weekly, monthly

    static let typeDisplayRepresentation: TypeDisplayRepresentation = "기간"
    static let caseDisplayRepresentations: [TrendingPeriod: DisplayRepresentation] = [
        .daily: "오늘", .weekly: "이번 주", .monthly: "이번 달",
    ]

    func label(_ lang: AppLanguage) -> String {
        switch (self, lang) {
        case (.daily, .ko): "오늘"
        case (.weekly, .ko): "이번 주"
        case (.monthly, .ko): "이번 달"
        case (.daily, .en): "Today"
        case (.weekly, .en): "This week"
        case (.monthly, .en): "This month"
        }
    }
}

enum TrendingSpokenLanguage: String, AppEnum {
    case all, ko, en, zh, ja

    static let typeDisplayRepresentation: TypeDisplayRepresentation = "사용 언어"
    static let caseDisplayRepresentations: [TrendingSpokenLanguage: DisplayRepresentation] = [
        .all: "전체", .ko: "한국어", .en: "영어", .zh: "중국어", .ja: "일본어",
    ]

    /// Value for `spoken_language_code`; nil omits the parameter.
    var code: String? { self == .all ? nil : rawValue }
}

/// Requested delay before the next timeline reload. WidgetKit may defer it further.
enum TrendingRefreshInterval: String, AppEnum {
    case min15, min30, hour1, hour3, hour6, hour12

    static let typeDisplayRepresentation: TypeDisplayRepresentation = "갱신 주기"
    static let caseDisplayRepresentations: [TrendingRefreshInterval: DisplayRepresentation] = [
        .min15: "15분", .min30: "30분", .hour1: "1시간",
        .hour3: "3시간", .hour6: "6시간", .hour12: "12시간",
    ]

    var seconds: TimeInterval {
        switch self {
        case .min15: 15 * 60
        case .min30: 30 * 60
        case .hour1: 60 * 60
        case .hour3: 3 * 60 * 60
        case .hour6: 6 * 60 * 60
        case .hour12: 12 * 60 * 60
        }
    }

    /// Delay after a failed fetch: 15 minutes, capped at the regular interval.
    var retrySeconds: TimeInterval { min(15 * 60, seconds) }
}

/// Number of repositories to show. Medium widgets are capped at `mediumMaxValue`.
enum TrendingItemCount: String, AppEnum {
    case three, five, seven, ten

    static let typeDisplayRepresentation: TypeDisplayRepresentation = "표시 개수"
    static let caseDisplayRepresentations: [TrendingItemCount: DisplayRepresentation] = [
        .three: "상위 3개", .five: "상위 5개", .seven: "상위 7개", .ten: "상위 10개",
    ]

    var value: Int {
        switch self {
        case .three: 3
        case .five: 5
        case .seven: 7
        case .ten: 10
        }
    }

    /// Always fetch and cache this many, then slice per widget, so changing the count needs no refetch.
    static let maxValue = 10
    /// Rows that fit in a medium widget.
    static let mediumMaxValue = 7
}

/// Language for the widget's text. `.system` follows the user's preferred languages.
enum TrendingDisplayLanguage: String, AppEnum {
    case system, ko, en

    static let typeDisplayRepresentation: TypeDisplayRepresentation = "위젯 표시 언어"
    static let caseDisplayRepresentations: [TrendingDisplayLanguage: DisplayRepresentation] = [
        .system: "시스템 설정", .ko: "한국어", .en: "English",
    ]

    var resolved: AppLanguage {
        switch self {
        case .ko: .ko
        case .en: .en
        case .system:
            Locale.preferredLanguages.first?.hasPrefix("ko") == true ? .ko : .en
        }
    }
}

/// Widget configuration. Each `@Parameter` is one row in the Edit Widget UI.
struct TrendingConfigurationIntent: WidgetConfigurationIntent {
    static let title: LocalizedStringResource = "GitHub Trending"
    static let description = IntentDescription("GitHub Trending 상위 레포를 보여줍니다.")

    @Parameter(title: "프로그래밍 언어", default: .all)
    var language: TrendingLanguage

    @Parameter(title: "기간", default: .daily)
    var period: TrendingPeriod

    @Parameter(title: "사용 언어", description: "레포 설명·README에 쓰인 언어로 필터링합니다.", default: .all)
    var spokenLanguage: TrendingSpokenLanguage

    @Parameter(title: "표시 개수", description: "중간 크기 위젯은 최대 7개까지 표시됩니다.", default: .five)
    var itemCount: TrendingItemCount

    @Parameter(title: "갱신 주기", default: .hour1)
    var refreshInterval: TrendingRefreshInterval

    @Parameter(title: "위젯 표시 언어", description: "위젯 안 문구의 언어입니다.", default: .system)
    var displayLanguage: TrendingDisplayLanguage

    init() {}

    init(language: TrendingLanguage, period: TrendingPeriod, spokenLanguage: TrendingSpokenLanguage = .all,
         itemCount: TrendingItemCount = .five, refreshInterval: TrendingRefreshInterval = .hour1, displayLanguage: TrendingDisplayLanguage = .system) {
        self.language = language
        self.period = period
        self.spokenLanguage = spokenLanguage
        self.itemCount = itemCount
        self.refreshInterval = refreshInterval
        self.displayLanguage = displayLanguage
    }
}

/// The part of the configuration that determines what is fetched and cached.
/// A plain `Sendable` value, so the intent itself never crosses concurrency boundaries.
struct TrendingQuery: Sendable, Hashable {
    let language: TrendingLanguage
    let period: TrendingPeriod
    let spokenLanguage: TrendingSpokenLanguage

    init(_ intent: TrendingConfigurationIntent) {
        language = intent.language
        period = intent.period
        spokenLanguage = intent.spokenLanguage
    }

    var url: URL {
        var s = "https://github.com/trending"
        if let slug = language.pathSlug { s += "/\(slug)" }
        s += "?since=\(period.rawValue)"
        if let code = spokenLanguage.code { s += "&spoken_language_code=\(code)" }
        return URL(string: s)!
    }

    var cacheKey: String { "trending.cache.\(language.rawValue).\(period.rawValue).\(spokenLanguage.rawValue)" }
}
