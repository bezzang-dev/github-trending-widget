import AppIntents
import WidgetKit

// AppEnum = 위젯 편집 화면(우클릭 → "위젯 편집")에 드롭다운으로 노출되는 enum.
// Java enum과 비슷하지만, 화면에 보일 이름(DisplayRepresentation)을 함께 제공해야 한다.
//
// Swift 6 메모: 프로토콜 요구사항이 `static var`라도 `static let`으로 구현한다.
// `static var`는 "전역 가변 상태"라서 Swift 6에서 동시성 안전하지 않다는 에러가 난다.

enum TrendingLanguage: String, AppEnum {
    case all, java, javascript, typescript, python, swift, kotlin, go, rust
    case cpp, c, csharp, ruby, php, shell, dart, jupyterNotebook

    static let typeDisplayRepresentation: TypeDisplayRepresentation = "언어"
    static let caseDisplayRepresentations: [TrendingLanguage: DisplayRepresentation] = [
        .all: "전체", .java: "Java", .javascript: "JavaScript", .typescript: "TypeScript",
        .python: "Python", .swift: "Swift", .kotlin: "Kotlin", .go: "Go", .rust: "Rust",
        .cpp: "C++", .c: "C", .csharp: "C#", .ruby: "Ruby", .php: "PHP", .shell: "Shell",
        .dart: "Dart", .jupyterNotebook: "Jupyter Notebook",
    ]

    /// /trending/<slug> 경로. nil이면 전체. (이미 퍼센트 인코딩된 값)
    var pathSlug: String? {
        switch self {
        case .all: nil
        case .cpp: "c%2B%2B"
        case .csharp: "c%23"
        case .jupyterNotebook: "jupyter-notebook"
        default: rawValue
        }
    }

    var label: String {
        switch self {
        case .all: "전체"
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

    var label: String {
        switch self {
        case .daily: "오늘"
        case .weekly: "이번 주"
        case .monthly: "이번 달"
        }
    }
}

enum TrendingSpokenLanguage: String, AppEnum {
    case all, ko, en, zh, ja

    static let typeDisplayRepresentation: TypeDisplayRepresentation = "사용 언어"
    static let caseDisplayRepresentations: [TrendingSpokenLanguage: DisplayRepresentation] = [
        .all: "전체", .ko: "한국어", .en: "영어", .zh: "중국어", .ja: "일본어",
    ]

    /// ?spoken_language_code= 값. nil이면 파라미터 생략
    var code: String? { self == .all ? nil : rawValue }
}

/// 위젯 설정 Intent. `@Parameter` 하나가 편집 화면의 항목 하나.
/// (Spring의 @ConfigurationProperties 바인딩 대상 클래스를 떠올리면 된다 — 값은 시스템이 채워 줌)
struct TrendingConfigurationIntent: WidgetConfigurationIntent {
    static let title: LocalizedStringResource = "GitHub Trending"
    static let description = IntentDescription("GitHub Trending 상위 5개 레포를 보여줍니다.")

    @Parameter(title: "언어", default: .all)
    var language: TrendingLanguage

    @Parameter(title: "기간", default: .daily)
    var period: TrendingPeriod

    @Parameter(title: "사용 언어", default: .all)
    var spokenLanguage: TrendingSpokenLanguage

    init() {}

    init(language: TrendingLanguage, period: TrendingPeriod, spokenLanguage: TrendingSpokenLanguage = .all) {
        self.language = language
        self.period = period
        self.spokenLanguage = spokenLanguage
    }
}

/// Intent에서 네트워크/캐시 계층이 쓰는 값만 뽑은 Sendable 값 타입.
/// Intent(@Parameter 래퍼 포함)를 그대로 넘기지 않고 이걸 넘겨서 동시성 경계를 깔끔하게 유지한다.
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

    /// UserDefaults 캐시 키 (설정 조합마다 별도 캐시)
    var cacheKey: String { "trending.cache.\(language.rawValue).\(period.rawValue).\(spokenLanguage.rawValue)" }
}
