import Foundation

/// github.com/trending HTML 파서.
///
/// GitHub에는 Trending 공식 API가 없어서 HTML을 직접 파싱한다.
/// 페이지 구조가 바뀌면 **이 파일만** 고치면 되도록 분리했다.
///
/// 2026-11 기준 확인한 구조 (레포 1개 = `<article class="Box-row">` 1개):
/// ```
/// <article class="Box-row">
///   <h2 class="h3 lh-condensed">
///     <a href="/owner/name" ...> <span class="text-normal">owner /</span> name </a>
///   </h2>
///   <p class="col-9 color-fg-muted my-1 ...">설명</p>              ← 없을 수 있음
///   <div class="f6 color-fg-muted mt-2">
///     <span class="repo-language-color" style="background-color: #3572A5"></span>  ← 없을 수 있음
///     <span itemprop="programmingLanguage">Python</span>                           ← 없을 수 있음
///     <a href="/owner/name/stargazers" ...> 190,461</a>
///     <a href="/owner/name/forks" ...> 22,408</a>
///     <span class="d-inline-block float-sm-right"> 1,052 stars today</span>   (this week / this month)
///   </div>
/// </article>
/// ```
/// 외부 라이브러리를 쓰지 않으므로 정규식(NSRegularExpression, Java의 java.util.regex와 비슷)으로 뽑는다.
enum TrendingParser {

    enum ParseError: Error, Equatable {
        case noRepositoriesFound
    }

    /// HTML 전체에서 레포 목록을 최대 `limit`개 추출
    static func parse(html: String, limit: Int = 5) throws -> [TrendingRepo] {
        var repos: [TrendingRepo] = []
        for block in articleBlocks(in: html) {
            if let repo = parseArticle(block) {
                repos.append(repo)
                if repos.count == limit { break }
            }
        }
        if repos.isEmpty { throw ParseError.noRepositoriesFound }
        return repos
    }

    // MARK: - 단계별 파싱

    /// `<article class="Box-row"> ... </article>` 블록들을 잘라낸다
    static func articleBlocks(in html: String) -> [Substring] {
        let openTag = #"<article class="Box-row">"#
        var blocks: [Substring] = []
        var searchRange = html.startIndex..<html.endIndex
        while let open = html.range(of: openTag, range: searchRange) {
            let rest = open.upperBound..<html.endIndex
            let close = html.range(of: "</article>", range: rest)?.lowerBound ?? html.endIndex
            blocks.append(html[open.upperBound..<close])
            searchRange = close..<html.endIndex
        }
        return blocks
    }

    static func parseArticle(_ block: Substring) -> TrendingRepo? {
        let text = String(block)

        // 1) 레포 경로: <h2 ...> 안의 첫 번째 href="/owner/name"
        guard let h2 = firstCapture(#"<h2[^>]*>(.*?)</h2>"#, in: text),
              let path = firstCapture(#"href="/([^"/]+/[^"/]+)""#, in: h2)
        else { return nil }
        let parts = path.split(separator: "/", maxSplits: 1).map(String.init)
        guard parts.count == 2 else { return nil }

        // 2) 설명: <p class="col-9 ..."> (없으면 nil)
        let description = firstCapture(#"<p class="col-9[^"]*">(.*?)</p>"#, in: text)
            .map(cleanText)
            .flatMap { $0.isEmpty ? nil : $0 }

        // 3) 언어 + 언어색
        let language = firstCapture(#"itemprop="programmingLanguage"[^>]*>(.*?)</span>"#, in: text).map(cleanText)
        let colorHex = firstCapture(#"repo-language-color"[^>]*background-color:\s*(#[0-9A-Fa-f]{3,8})"#, in: text)

        // 4) 전체 스타 / 포크: /stargazers, /forks 링크 안의 숫자
        let stars = firstCapture(#"href="/[^"]+/stargazers"[^>]*>(.*?)</a>"#, in: text).map(parseNumber) ?? 0
        let forks = firstCapture(#"href="/[^"]+/forks"[^>]*>(.*?)</a>"#, in: text).map(parseNumber) ?? 0

        // 5) 기간 증가 스타: "1,052 stars today" / "1 star this week" / "... this month"
        let periodStars = firstCapture(#"([\d,]+)\s+stars?\s+(?:today|this week|this month)"#, in: text)
            .map(parseNumber) ?? 0

        return TrendingRepo(
            owner: parts[0], name: parts[1],
            description: description,
            language: language, languageColorHex: colorHex,
            stars: stars, forks: forks, periodStars: periodStars
        )
    }

    // MARK: - 유틸

    /// 정규식의 첫 번째 캡처 그룹을 돌려준다. `.`이 줄바꿈도 매칭하도록 dotMatchesLineSeparators 사용
    static func firstCapture(_ pattern: String, in text: String) -> String? {
        guard let regex = try? NSRegularExpression(pattern: pattern, options: [.dotMatchesLineSeparators]) else { return nil }
        let ns = text as NSString
        guard let match = regex.firstMatch(in: text, range: NSRange(location: 0, length: ns.length)),
              match.numberOfRanges > 1,
              match.range(at: 1).location != NSNotFound
        else { return nil }
        return ns.substring(with: match.range(at: 1))
    }

    /// 태그 제거 + 엔티티 디코딩 + 공백 정리
    static func cleanText(_ raw: String) -> String {
        let noTags = raw.replacingOccurrences(of: #"<[^>]+>"#, with: "", options: .regularExpression)
        let decoded = decodeEntities(noTags)
        return decoded
            .replacingOccurrences(of: #"\s+"#, with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// "190,461" 처럼 HTML 조각 안의 숫자만 뽑아 Int로
    static func parseNumber(_ raw: String) -> Int {
        let digits = cleanText(raw).filter(\.isNumber)
        return Int(digits) ?? 0
    }

    /// 자주 나오는 HTML 엔티티만 디코딩 (&amp; &lt; &gt; &quot; &#39; &#x27; &#1234; 등)
    static func decodeEntities(_ s: String) -> String {
        guard s.contains("&") else { return s }
        var result = s
        let named = ["&quot;": "\"", "&apos;": "'", "&lt;": "<", "&gt;": ">", "&nbsp;": " "]
        for (k, v) in named { result = result.replacingOccurrences(of: k, with: v) }

        // 숫자 엔티티 (&#39; / &#x27;)
        if let regex = try? NSRegularExpression(pattern: #"&#(x?)([0-9A-Fa-f]+);"#) {
            let ns = result as NSString
            var out = ""
            var last = 0
            for m in regex.matches(in: result, range: NSRange(location: 0, length: ns.length)) {
                out += ns.substring(with: NSRange(location: last, length: m.range.location - last))
                let isHex = m.range(at: 1).length > 0
                let num = ns.substring(with: m.range(at: 2))
                if let code = UInt32(num, radix: isHex ? 16 : 10), let scalar = Unicode.Scalar(code) {
                    out.unicodeScalars.append(scalar)
                } else {
                    out += ns.substring(with: m.range)
                }
                last = m.range.location + m.range.length
            }
            out += ns.substring(from: last)
            result = out
        }
        // &amp;는 마지막에 (이중 디코딩 방지)
        return result.replacingOccurrences(of: "&amp;", with: "&")
    }
}
