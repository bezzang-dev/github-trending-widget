import Foundation

/// One repository row from github.com/trending.
struct TrendingRepo: Codable, Sendable, Hashable, Identifiable {
    let owner: String
    let name: String
    let description: String?
    let language: String?
    /// Language color from the page, e.g. "#3572A5". Kept as a string so this type stays UI-agnostic.
    let languageColorHex: String?
    let stars: Int
    let forks: Int
    /// Stars gained during the selected period.
    let periodStars: Int

    var id: String { "\(owner)/\(name)" }
    var url: URL { URL(string: "https://github.com/\(owner)/\(name)")! }
}

/// The result of one successful fetch; this is what gets cached.
struct TrendingSnapshot: Codable, Sendable {
    let repos: [TrendingRepo]
    let fetchedAt: Date
}

extension TrendingRepo {
    /// Sample data for placeholders, the widget gallery and previews.
    static let samples: [TrendingRepo] = [
        .init(owner: "anthropics", name: "skills", description: "Public repository for Agent Skills",
              language: "Python", languageColorHex: "#3572A5", stars: 190_461, forks: 22_408, periodStars: 1_052),
        .init(owner: "apple", name: "swift", description: "The Swift Programming Language",
              language: "C++", languageColorHex: "#f34b7d", stars: 68_900, forks: 10_500, periodStars: 412),
        .init(owner: "spring-projects", name: "spring-boot", description: "Spring Boot helps you to create Spring-powered, production-grade applications and services with absolute minimum fuss.",
              language: "Java", languageColorHex: "#b07219", stars: 76_300, forks: 41_000, periodStars: 287),
        .init(owner: "microsoft", name: "TypeScript", description: "TypeScript is a superset of JavaScript that compiles to clean JavaScript output.",
              language: "TypeScript", languageColorHex: "#3178c6", stars: 102_000, forks: 12_500, periodStars: 199),
        .init(owner: "rust-lang", name: "rust", description: "Empowering everyone to build reliable and efficient software.",
              language: "Rust", languageColorHex: "#dea584", stars: 99_800, forks: 12_900, periodStars: 156),
        .init(owner: "golang", name: "go", description: "The Go programming language",
              language: "Go", languageColorHex: "#00ADD8", stars: 125_000, forks: 17_800, periodStars: 131),
        .init(owner: "JetBrains", name: "kotlin", description: "The Kotlin Programming Language.",
              language: "Kotlin", languageColorHex: "#A97BFF", stars: 50_100, forks: 5_800, periodStars: 98),
        .init(owner: "python", name: "cpython", description: "The Python programming language",
              language: "Python", languageColorHex: "#3572A5", stars: 64_900, forks: 31_000, periodStars: 87),
        .init(owner: "flutter", name: "flutter", description: "Flutter makes it easy and fast to build beautiful apps for mobile and beyond",
              language: "Dart", languageColorHex: "#00B4AB", stars: 167_000, forks: 28_000, periodStars: 64),
        .init(owner: "nodejs", name: "node", description: "Node.js JavaScript runtime",
              language: "JavaScript", languageColorHex: "#f1e05a", stars: 109_000, forks: 30_000, periodStars: 52),
    ]
}
