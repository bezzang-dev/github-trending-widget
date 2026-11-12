import Foundation

/// Language of the text rendered inside the widget.
///
/// String Catalogs only follow the system language, so a per-widget language setting needs
/// this small in-code table. The Edit Widget UI is rendered by the system and isn't affected.
enum AppLanguage: String, Sendable, Hashable {
    case ko, en

    var locale: Locale { Locale(identifier: rawValue) }
}

struct TrendingStrings: Sendable {
    let lang: AppLanguage

    private func t(_ ko: String, _ en: String) -> String { lang == .ko ? ko : en }

    var loadFailed: String { t("불러오지 못했어요. 잠시 후 다시 시도합니다.", "Couldn't load. Will retry shortly.") }
    var staleHelp: String { t("갱신 실패 — 마지막 결과를 표시 중", "Refresh failed — showing last result") }

    func header(_ query: TrendingQuery) -> String {
        "Trending · \(query.language.label(lang)) · \(query.period.label(lang))"
    }
}
