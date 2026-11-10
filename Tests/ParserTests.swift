// 파서 단독 테스트 (XCTest 없이 Command Line Tools의 swiftc만으로 실행 가능)
// 실행: ./Tests/run_parser_tests.sh
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

            check(repos.count == 5, "레포 5개 추출 (실제 \(repos.count)개)")
            check(Set(repos.map(\.id)).count == 5, "중복 없음")
            check(repos.allSatisfy { !$0.owner.isEmpty && !$0.name.isEmpty && !$0.name.contains(" ") }, "owner/name 정상")
            check(repos.allSatisfy { $0.stars > 0 }, "전체 스타 > 0")
            check(repos.allSatisfy { $0.periodStars > 0 }, "기간 증가 스타 > 0")
            check(repos.allSatisfy { $0.stars >= $0.periodStars }, "전체 스타 ≥ 기간 증가 스타")
            check(repos.allSatisfy { $0.description.map { !$0.contains("<") && !$0.contains("&amp;") } ?? true }, "설명에 태그/엔티티 없음")
            if file.contains("java") {
                check(repos.allSatisfy { $0.language == "Java" }, "모두 Java 레포")
            }
            for (i, r) in repos.enumerated() {
                print("    \(i + 1). \(r.id) [\(r.language ?? "-") \(r.languageColorHex ?? "")] ★\(r.stars) ⑂\(r.forks) +\(r.periodStars)  \(r.description ?? "")")
            }
        }

        // 엣지 케이스
        print("▶︎ edge cases")
        check(TrendingParser.decodeEntities("a &amp; b &#39;c&#x27; &quot;d&quot;") == "a & b 'c' \"d\"", "엔티티 디코딩")
        check(TrendingParser.parseNumber(" <svg/> 1,234\n") == 1234, "숫자 파싱")
        check((try? TrendingParser.parse(html: "<html></html>")) == nil, "레포가 없으면 에러")

        print(failures == 0 ? "\n🎉 모든 테스트 통과" : "\n💥 실패 \(failures)건")
        exit(failures == 0 ? 0 : 1)
    }
}
