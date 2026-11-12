import Foundation

/// Fetches and parses the trending page, caching the last successful result per query.
struct TrendingService {

    /// A regular Safari user agent; GitHub may serve different markup to the default CFNetwork one.
    static let userAgent =
        "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.4 Safari/605.1.15"

    enum FetchError: Error {
        case badStatus(Int)
        case badEncoding
    }

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

        let repos = try TrendingParser.parse(html: html, limit: TrendingItemCount.maxValue)
        let snapshot = TrendingSnapshot(repos: repos, fetchedAt: .now)
        saveCache(snapshot, for: query)
        return snapshot
    }

    // MARK: - Cache
    // Only the extension reads its cache, so its own sandboxed UserDefaults is enough (no App Group).

    func cached(_ query: TrendingQuery) -> TrendingSnapshot? {
        guard let data = UserDefaults.standard.data(forKey: query.cacheKey) else { return nil }
        return try? JSONDecoder().decode(TrendingSnapshot.self, from: data)
    }

    private func saveCache(_ snapshot: TrendingSnapshot, for query: TrendingQuery) {
        guard let data = try? JSONEncoder().encode(snapshot) else { return }
        UserDefaults.standard.set(data, forKey: query.cacheKey)
    }
}
