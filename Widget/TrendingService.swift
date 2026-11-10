import Foundation

/// 요청 → 파싱 → 캐시. (Spring의 @Service + RestTemplate + 간단한 캐시 역할)
///
/// `struct` + 저장 프로퍼티 없음 → 자동으로 Sendable이라 어느 스레드에서 써도 안전.
/// `async throws` 함수는 Java의 CompletableFuture를 동기 코드처럼 쓰는 것과 비슷하다 (`try await`).
struct TrendingService {

    /// 일반 Safari User-Agent. 기본 UA(CFNetwork)로 요청하면 GitHub이 다른 응답을 줄 수 있다.
    static let userAgent =
        "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.4 Safari/605.1.15"

    enum FetchError: Error {
        case badStatus(Int)
        case badEncoding
    }

    /// 네트워크에서 받아 파싱. 성공하면 캐시에 저장까지 한다.
    func fetch(_ query: TrendingQuery) async throws -> TrendingSnapshot {
        var request = URLRequest(url: query.url, cachePolicy: .reloadIgnoringLocalCacheData, timeoutInterval: 20)
        request.setValue(Self.userAgent, forHTTPHeaderField: "User-Agent")
        request.setValue("text/html", forHTTPHeaderField: "Accept")
        request.setValue("en-US,en;q=0.9", forHTTPHeaderField: "Accept-Language")

        let (data, response) = try await URLSession.shared.data(for: request)
        if let http = response as? HTTPURLResponse, !(200..<300).contains(http.statusCode) {
            throw FetchError.badStatus(http.statusCode)
        }
        guard let html = String(data: data, encoding: .utf8) else { throw FetchError.badEncoding }

        let repos = try TrendingParser.parse(html: html, limit: 5)
        let snapshot = TrendingSnapshot(repos: repos, fetchedAt: .now)
        saveCache(snapshot, for: query)
        return snapshot
    }

    // MARK: - 캐시 (UserDefaults)
    // 위젯 익스텐션은 샌드박스 안에서 자기 컨테이너의 UserDefaults를 쓴다.
    // 앱과 공유할 필요가 없으므로 App Group 없이 .standard로 충분.

    func cached(_ query: TrendingQuery) -> TrendingSnapshot? {
        guard let data = UserDefaults.standard.data(forKey: query.cacheKey) else { return nil }
        return try? JSONDecoder().decode(TrendingSnapshot.self, from: data)
    }

    private func saveCache(_ snapshot: TrendingSnapshot, for query: TrendingQuery) {
        guard let data = try? JSONEncoder().encode(snapshot) else { return }
        UserDefaults.standard.set(data, forKey: query.cacheKey)
    }
}
