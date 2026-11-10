import Foundation

/// 트렌딩 레포 1개. (Java의 record/DTO에 해당)
/// - `Codable`: JSON 직렬화 (Jackson 역할) → UserDefaults 캐시에 사용
/// - `Sendable`: 스레드(동시성 도메인) 간에 안전하게 넘길 수 있다는 표시. Swift 6에서 필수에 가까움
struct TrendingRepo: Codable, Sendable, Hashable, Identifiable {
    let owner: String
    let name: String
    let description: String?
    let language: String?
    /// GitHub 페이지가 주는 언어 색 (예: "#3572A5"). SwiftUI 의존을 없애려고 문자열로 보관
    let languageColorHex: String?
    let stars: Int
    let forks: Int
    /// 선택한 기간(오늘/이번 주/이번 달) 동안 늘어난 스타 수
    let periodStars: Int

    var id: String { "\(owner)/\(name)" }
    var url: URL { URL(string: "https://github.com/\(owner)/\(name)")! }
}

/// 한 번 성공적으로 받아온 결과 묶음 (캐시 단위)
struct TrendingSnapshot: Codable, Sendable {
    let repos: [TrendingRepo]
    let fetchedAt: Date
}

extension TrendingRepo {
    /// 위젯 갤러리 미리보기 / placeholder / #Preview 용 샘플 데이터
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
    ]
}
