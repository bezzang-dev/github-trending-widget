import SwiftUI
import WidgetKit

// MARK: - Entry

struct TrendingEntry: TimelineEntry {
    let date: Date
    let query: TrendingQuery
    let repos: [TrendingRepo]
    /// Time of the last successful fetch (also when showing cached data).
    let fetchedAt: Date?
    /// True when this refresh failed and cached data is shown; adds a warning icon to the header.
    let isStale: Bool
    let lang: AppLanguage
    /// Requested count; the view may show fewer depending on the widget family.
    let itemCount: TrendingItemCount

    var strings: TrendingStrings { TrendingStrings(lang: lang) }

    static func sample(_ query: TrendingQuery = .init(TrendingConfigurationIntent()), stale: Bool = false,
                       lang: AppLanguage = TrendingDisplayLanguage.system.resolved,
                       itemCount: TrendingItemCount = .five) -> TrendingEntry {
        TrendingEntry(date: .now, query: query, repos: TrendingRepo.samples, fetchedAt: .now, isStale: stale,
                      lang: lang, itemCount: itemCount)
    }
}

// MARK: - Provider

struct TrendingProvider: AppIntentTimelineProvider {
    private let service = TrendingService()

    func placeholder(in context: Context) -> TrendingEntry {
        .sample()
    }

    func snapshot(for configuration: TrendingConfigurationIntent, in context: Context) async -> TrendingEntry {
        let query = TrendingQuery(configuration)
        let lang = configuration.displayLanguage.resolved
        let count = configuration.itemCount
        if context.isPreview { return .sample(query, lang: lang, itemCount: count) }
        return await load(query, lang: lang, itemCount: count)
    }

    /// Reloads after the configured interval on success, or sooner (`retrySeconds`) on failure.
    func timeline(for configuration: TrendingConfigurationIntent, in context: Context) async -> Timeline<TrendingEntry> {
        let query = TrendingQuery(configuration)
        let lang = configuration.displayLanguage.resolved
        let count = configuration.itemCount
        let interval = configuration.refreshInterval
        let entry = context.isPreview ? .sample(query, lang: lang, itemCount: count)
                                      : await load(query, lang: lang, itemCount: count)
        let failed = entry.isStale || entry.repos.isEmpty
        let next = Date.now.addingTimeInterval(failed ? interval.retrySeconds : interval.seconds)
        return Timeline(entries: [entry], policy: .after(next))
    }

    private func load(_ query: TrendingQuery, lang: AppLanguage, itemCount: TrendingItemCount) async -> TrendingEntry {
        do {
            let snap = try await service.fetch(query)
            return TrendingEntry(date: .now, query: query, repos: snap.repos, fetchedAt: snap.fetchedAt,
                                 isStale: false, lang: lang, itemCount: itemCount)
        } catch {
            // Fall back to the last successful result, marked as stale.
            let cached = service.cached(query)
            return TrendingEntry(date: .now, query: query, repos: cached?.repos ?? [],
                                 fetchedAt: cached?.fetchedAt, isStale: true, lang: lang, itemCount: itemCount)
        }
    }
}

// MARK: - Views

struct TrendingWidgetView: View {
    @Environment(\.widgetFamily) private var family
    let entry: TrendingEntry

    private var repos: [TrendingRepo] {
        let limit = family == .systemLarge
            ? entry.itemCount.value
            : min(entry.itemCount.value, TrendingItemCount.mediumMaxValue)
        return Array(entry.repos.prefix(limit))
    }

    var body: some View {
        VStack(alignment: .leading, spacing: family == .systemLarge ? 6 : 4) {
            HeaderView(entry: entry)
            if repos.isEmpty {
                Spacer()
                Label(entry.strings.loadFailed, systemImage: "wifi.exclamationmark")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity)
                Spacer()
            } else if family == .systemLarge {
                // Simplify rows as the count grows: full detail up to 5, description up to 7, single line beyond.
                switch repos.count {
                case ...5: LargeList(repos: repos, showMeta: true)
                case ...7: LargeList(repos: repos, showMeta: false)
                default: MediumList(repos: repos)
                }
            } else {
                // A smaller font lets up to 7 rows fit.
                MediumList(repos: repos, font: repos.count > 5 ? .caption : .subheadline)
            }
        }
        // Format times and numbers in the display language.
        .environment(\.locale, entry.lang.locale)
        .containerBackground(.background, for: .widget)
        // Taps outside a row (e.g. the header) open the trending page for this configuration.
        .widgetURL(entry.query.url)
    }
}

private struct HeaderView: View {
    let entry: TrendingEntry

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: "chart.line.uptrend.xyaxis")
                .foregroundStyle(.orange)
            Text(entry.strings.header(entry.query))
                .fontWeight(.semibold)
                .lineLimit(1)
            Spacer(minLength: 4)
            if entry.isStale {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundStyle(.yellow)
                    .help(entry.strings.staleHelp)
            }
            if let fetchedAt = entry.fetchedAt {
                Text(fetchedAt, style: .time)
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
            }
        }
        .font(.caption)
    }
}

/// Single-line rows: medium widgets, and large widgets showing more than 7.
private struct MediumList: View {
    let repos: [TrendingRepo]
    var font: Font = .subheadline

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            ForEach(Array(repos.enumerated()), id: \.element.id) { index, repo in
                Link(destination: repo.url) {
                    HStack(spacing: 6) {
                        RankText(rank: index + 1)
                        LanguageDot(hex: repo.languageColorHex)
                        RepoNameText(repo: repo)
                        Spacer(minLength: 4)
                        PeriodStars(count: repo.periodStars)
                    }
                    .font(font)
                    .frame(maxHeight: .infinity)
                }
            }
        }
    }
}

/// Large-widget rows with a description and, if `showMeta`, a language/stars/forks line.
private struct LargeList: View {
    let repos: [TrendingRepo]
    let showMeta: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            ForEach(Array(repos.enumerated()), id: \.element.id) { index, repo in
                if index > 0 { Divider() }
                Link(destination: repo.url) {
                    HStack(alignment: .firstTextBaseline, spacing: 6) {
                        RankText(rank: index + 1)
                        VStack(alignment: .leading, spacing: 2) {
                            RepoNameText(repo: repo)
                                .font(.subheadline)
                            Text(repo.description ?? " ")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                            if showMeta {
                                HStack(spacing: 10) {
                                    if let language = repo.language {
                                        HStack(spacing: 3) {
                                            LanguageDot(hex: repo.languageColorHex)
                                            Text(language)
                                        }
                                    }
                                    Label(repo.stars.formatted(), systemImage: "star")
                                    Label(repo.forks.formatted(), systemImage: "arrow.triangle.branch")
                                    Spacer(minLength: 4)
                                    PeriodStars(count: repo.periodStars)
                                }
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                                .labelStyle(CompactLabelStyle())
                            }
                        }
                        if !showMeta {
                            Spacer(minLength: 4)
                            PeriodStars(count: repo.periodStars)
                                .font(.caption)
                        }
                    }
                    .frame(maxHeight: .infinity)
                }
            }
        }
    }
}

// MARK: - Components

private struct RankText: View {
    let rank: Int
    var body: some View {
        Text("\(rank)")
            .monospacedDigit()
            .foregroundStyle(.secondary)
            .frame(width: 12, alignment: .trailing)
    }
}

/// "owner / name" with the name in bold.
private struct RepoNameText: View {
    let repo: TrendingRepo
    var body: some View {
        Text("\(Text(repo.owner + " /").foregroundStyle(.secondary)) \(Text(repo.name).fontWeight(.bold))")
            .lineLimit(1)
            .truncationMode(.tail)
    }
}

private struct LanguageDot: View {
    let hex: String?
    var body: some View {
        Circle()
            .fill(Color(hex: hex) ?? .gray)
            .frame(width: 8, height: 8)
    }
}

private struct PeriodStars: View {
    let count: Int
    var body: some View {
        HStack(spacing: 2) {
            Image(systemName: "star.fill").imageScale(.small)
            Text("+\(count.formatted())").monospacedDigit()
        }
        .foregroundStyle(.orange)
        .lineLimit(1)
        .fixedSize()
    }
}

private struct CompactLabelStyle: LabelStyle {
    func makeBody(configuration: Configuration) -> some View {
        HStack(spacing: 2) {
            configuration.icon.imageScale(.small)
            configuration.title
        }
    }
}

extension Color {
    /// Parses "#3572A5" or "#f34".
    init?(hex: String?) {
        guard var s = hex?.trimmingCharacters(in: .whitespaces) else { return nil }
        if s.hasPrefix("#") { s.removeFirst() }
        if s.count == 3 { s = s.map { "\($0)\($0)" }.joined() }
        guard s.count == 6, let v = UInt32(s, radix: 16) else { return nil }
        self.init(red: Double((v >> 16) & 0xFF) / 255, green: Double((v >> 8) & 0xFF) / 255, blue: Double(v & 0xFF) / 255)
    }
}

// MARK: - Widget & Bundle

struct TrendingWidget: Widget {
    let kind = "TrendingWidget"

    var body: some WidgetConfiguration {
        AppIntentConfiguration(kind: kind, intent: TrendingConfigurationIntent.self, provider: TrendingProvider()) { entry in
            TrendingWidgetView(entry: entry)
        }
        .configurationDisplayName("GitHub Trending")
        .description("GitHub Trending 상위 레포를 보여줍니다.")
        .supportedFamilies([.systemMedium, .systemLarge])
    }
}

@main
struct TrendingWidgetBundle: WidgetBundle {
    var body: some Widget {
        TrendingWidget()
    }
}

// MARK: - Previews

#if DEBUG
#Preview("Medium", as: .systemMedium) {
    TrendingWidget()
} timeline: {
    TrendingEntry.sample()
    TrendingEntry.sample(itemCount: .seven)
    TrendingEntry.sample(.init(TrendingConfigurationIntent(language: .java, period: .weekly)), stale: true, lang: .en)
}

#Preview("Large", as: .systemLarge) {
    TrendingWidget()
} timeline: {
    TrendingEntry.sample()
    TrendingEntry.sample(.init(TrendingConfigurationIntent(language: .java, period: .weekly)), stale: true, lang: .en)
    TrendingEntry.sample(itemCount: .three)
    TrendingEntry.sample(itemCount: .seven)
    TrendingEntry.sample(itemCount: .ten)
}
#endif
