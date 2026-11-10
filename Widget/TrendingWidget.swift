import SwiftUI
import WidgetKit

// MARK: - Entry
// 위젯은 "시점별 스냅샷(Entry)들의 타임라인"을 시스템에 넘기고, 시스템이 그 시점에 뷰를 그린다.
// 위젯 코드는 상시 실행되는 게 아니라, 시스템(chronod)이 필요할 때만 잠깐 깨워서 타임라인을 받아간다.

struct TrendingEntry: TimelineEntry {
    let date: Date
    let query: TrendingQuery
    let repos: [TrendingRepo]
    /// 마지막으로 네트워크에서 성공한 시각 (캐시 표시 시에도 원래 시각)
    let fetchedAt: Date?
    /// 이번 갱신이 실패해서 캐시를 보여주는 중이면 true → 헤더에 경고 아이콘
    let isStale: Bool

    static func sample(_ query: TrendingQuery = .init(TrendingConfigurationIntent()), stale: Bool = false) -> TrendingEntry {
        TrendingEntry(date: .now, query: query, repos: TrendingRepo.samples, fetchedAt: .now, isStale: stale)
    }
}

// MARK: - Provider
// Spring으로 치면 "스케줄러 + 데이터 공급자". 시스템이 아래 3개 메서드를 호출한다.

struct TrendingProvider: AppIntentTimelineProvider {
    private let service = TrendingService()

    /// 로딩 중 회색 박스(redacted)로 보여줄 자리표시 데이터. 동기 & 즉시 반환해야 한다.
    func placeholder(in context: Context) -> TrendingEntry {
        .sample()
    }

    /// 위젯 갤러리 미리보기 등 "한 장"이 필요할 때
    func snapshot(for configuration: TrendingConfigurationIntent, in context: Context) async -> TrendingEntry {
        let query = TrendingQuery(configuration)
        if context.isPreview { return .sample(query) }
        return await load(query)
    }

    /// 실제 타임라인. 성공 시 60분, 실패 시 15분 뒤 다시 불러 달라고 요청한다.
    func timeline(for configuration: TrendingConfigurationIntent, in context: Context) async -> Timeline<TrendingEntry> {
        let query = TrendingQuery(configuration)
        let entry = context.isPreview ? .sample(query) : await load(query)
        let failed = entry.isStale || entry.repos.isEmpty
        let next = Date.now.addingTimeInterval(failed ? 15 * 60 : 60 * 60)
        return Timeline(entries: [entry], policy: .after(next))
    }

    private func load(_ query: TrendingQuery) async -> TrendingEntry {
        do {
            let snap = try await service.fetch(query)
            return TrendingEntry(date: .now, query: query, repos: snap.repos, fetchedAt: snap.fetchedAt, isStale: false)
        } catch {
            // 실패 → 마지막 성공 결과(캐시)를 경고 표시와 함께 보여준다
            let cached = service.cached(query)
            return TrendingEntry(date: .now, query: query, repos: cached?.repos ?? [],
                                 fetchedAt: cached?.fetchedAt, isStale: true)
        }
    }
}

// MARK: - Views

struct TrendingWidgetView: View {
    @Environment(\.widgetFamily) private var family
    let entry: TrendingEntry

    var body: some View {
        VStack(alignment: .leading, spacing: family == .systemLarge ? 6 : 4) {
            HeaderView(entry: entry)
            if entry.repos.isEmpty {
                Spacer()
                Label("불러오지 못했어요. 잠시 후 다시 시도합니다.", systemImage: "wifi.exclamationmark")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity)
                Spacer()
            } else if family == .systemLarge {
                LargeList(repos: entry.repos)
            } else {
                MediumList(repos: entry.repos)
            }
        }
        .containerBackground(.background, for: .widget)
        // Link가 없는 영역(헤더 등)을 클릭하면 현재 설정의 Trending 페이지를 연다
        .widgetURL(entry.query.url)
    }
}

private struct HeaderView: View {
    let entry: TrendingEntry

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: "chart.line.uptrend.xyaxis")
                .foregroundStyle(.orange)
            Text("Trending · \(entry.query.language.label) · \(entry.query.period.label)")
                .fontWeight(.semibold)
                .lineLimit(1)
            Spacer(minLength: 4)
            if entry.isStale {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundStyle(.yellow)
                    .help("갱신 실패 — 마지막 결과를 표시 중")
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

/// systemMedium: 5줄 압축
private struct MediumList: View {
    let repos: [TrendingRepo]

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
                    .font(.subheadline)
                    .frame(maxHeight: .infinity)
                }
            }
        }
    }
}

/// systemLarge: 5개 행 (설명 + 메타 정보)
private struct LargeList: View {
    let repos: [TrendingRepo]

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
                    .frame(maxHeight: .infinity)
                }
            }
        }
    }
}

// MARK: - 작은 구성 요소

private struct RankText: View {
    let rank: Int
    var body: some View {
        Text("\(rank)")
            .monospacedDigit()
            .foregroundStyle(.secondary)
            .frame(width: 12, alignment: .trailing)
    }
}

/// "owner / name" — name만 굵게
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
    /// "#3572A5" / "#f34" 형태의 16진수 문자열 → Color
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
        .description("GitHub Trending 상위 5개 레포를 보여줍니다.")
        .supportedFamilies([.systemMedium, .systemLarge])
    }
}

/// 익스텐션의 진입점 (Java의 main 클래스에 해당). 위젯을 여러 개 만들면 여기에 나열한다.
@main
struct TrendingWidgetBundle: WidgetBundle {
    var body: some Widget {
        TrendingWidget()
    }
}

// MARK: - Previews (Xcode 캔버스에서 확인)

#if DEBUG
#Preview("Medium", as: .systemMedium) {
    TrendingWidget()
} timeline: {
    TrendingEntry.sample()
    TrendingEntry.sample(.init(TrendingConfigurationIntent(language: .java, period: .weekly)), stale: true)
}

#Preview("Large", as: .systemLarge) {
    TrendingWidget()
} timeline: {
    TrendingEntry.sample()
    TrendingEntry.sample(.init(TrendingConfigurationIntent(language: .java, period: .weekly)), stale: true)
}
#endif
