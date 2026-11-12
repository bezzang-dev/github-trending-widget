// Standalone parser tests; builds with plain swiftc, no XCTest or Xcode needed.
// Run: ./Tests/run_parser_tests.sh
import Foundation

@main
struct ParserTests {
    static func main() throws {
        let fixtures = URL(fileURLWithPath: CommandLine.arguments[1])
        var failures = 0

        func check(_ cond: Bool, _ msg: String) {
            if cond { print("  ✅ \(msg)") } else { print("  ❌ \(msg)"); failures += 1 }
        }

        for file in ["trending_all.html", "trending_java_weekly.html"] {
            print("▶︎ \(file)")
            let html = try String(contentsOf: fixtures.appendingPathComponent(file), encoding: .utf8)
            let repos = try TrendingParser.parse(html: html, limit: 5)

            check(repos.count == 5, "extracts 5 repos (got \(repos.count))")
            check(Set(repos.map(\.id)).count == 5, "no duplicates")
            // The widget fetches up to TrendingItemCount.maxValue (10).
            let ten = try TrendingParser.parse(html: html, limit: 10)
            check(ten.count == 10, "limit 10 extracts 10 repos (got \(ten.count))")
            check(Set(ten.map(\.id)).count == 10, "no duplicates among 10")
            check(repos.allSatisfy { !$0.owner.isEmpty && !$0.name.isEmpty && !$0.name.contains(" ") }, "owner/name are well-formed")
            check(repos.allSatisfy { $0.stars > 0 }, "total stars > 0")
            check(repos.allSatisfy { $0.periodStars > 0 }, "period stars > 0")
            check(repos.allSatisfy { $0.stars >= $0.periodStars }, "total stars >= period stars")
            check(repos.allSatisfy { $0.description.map { !$0.contains("<") && !$0.contains("&amp;") } ?? true }, "descriptions contain no tags or entities")
            if file.contains("java") {
                check(repos.allSatisfy { $0.language == "Java" }, "all repos are Java")
            }
            for (i, r) in repos.enumerated() {
                print("    \(i + 1). \(r.id) [\(r.language ?? "-") \(r.languageColorHex ?? "")] ★\(r.stars) ⑂\(r.forks) +\(r.periodStars)  \(r.description ?? "")")
            }
        }

        // Edge cases
        print("▶︎ edge cases")
        check(TrendingParser.decodeEntities("a &amp; b &#39;c&#x27; &quot;d&quot;") == "a & b 'c' \"d\"", "decodes entities")
        check(TrendingParser.parseNumber(" <svg/> 1,234\n") == 1234, "parses numbers")
        check((try? TrendingParser.parse(html: "<html></html>")) == nil, "throws when no repos are found")

        print(failures == 0 ? "\n🎉 All tests passed" : "\n💥 \(failures) failed")
        exit(failures == 0 ? 0 : 1)
    }
}
