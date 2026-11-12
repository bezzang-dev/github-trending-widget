import Foundation

/// Parser for the github.com/trending page. GitHub has no trending API, so this scrapes the HTML.
/// Markup changes should only require edits here.
///
/// Structure as of 2026-11 (one `<article class="Box-row">` per repository):
/// ```
/// <article class="Box-row">
///   <h2 class="h3 lh-condensed">
///     <a href="/owner/name" ...> <span class="text-normal">owner /</span> name </a>
///   </h2>
///   <p class="col-9 color-fg-muted my-1 ...">description</p>                        ← optional
///   <div class="f6 color-fg-muted mt-2">
///     <span class="repo-language-color" style="background-color: #3572A5"></span>  ← optional
///     <span itemprop="programmingLanguage">Python</span>                           ← optional
///     <a href="/owner/name/stargazers" ...> 190,461</a>
///     <a href="/owner/name/forks" ...> 22,408</a>
///     <span class="d-inline-block float-sm-right"> 1,052 stars today</span>   (this week / this month)
///   </div>
/// </article>
/// ```
enum TrendingParser {

    enum ParseError: Error, Equatable {
        case noRepositoriesFound
    }

    /// Extracts up to `limit` repositories from the page HTML.
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

    // MARK: - Parsing steps

    /// Returns the inner contents of each `<article class="Box-row">`.
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

        // 1) Repo path: first href="/owner/name" inside <h2>
        guard let h2 = firstCapture(#"<h2[^>]*>(.*?)</h2>"#, in: text),
              let path = firstCapture(#"href="/([^"/]+/[^"/]+)""#, in: h2)
        else { return nil }
        let parts = path.split(separator: "/", maxSplits: 1).map(String.init)
        guard parts.count == 2 else { return nil }

        // 2) Description (optional)
        let description = firstCapture(#"<p class="col-9[^"]*">(.*?)</p>"#, in: text)
            .map(cleanText)
            .flatMap { $0.isEmpty ? nil : $0 }

        // 3) Language and its color (optional)
        let language = firstCapture(#"itemprop="programmingLanguage"[^>]*>(.*?)</span>"#, in: text).map(cleanText)
        let colorHex = firstCapture(#"repo-language-color"[^>]*background-color:\s*(#[0-9A-Fa-f]{3,8})"#, in: text)

        // 4) Total stars and forks from the /stargazers and /forks links
        let stars = firstCapture(#"href="/[^"]+/stargazers"[^>]*>(.*?)</a>"#, in: text).map(parseNumber) ?? 0
        let forks = firstCapture(#"href="/[^"]+/forks"[^>]*>(.*?)</a>"#, in: text).map(parseNumber) ?? 0

        // 5) Period stars: "1,052 stars today" / "1 star this week" / "... this month"
        let periodStars = firstCapture(#"([\d,]+)\s+stars?\s+(?:today|this week|this month)"#, in: text)
            .map(parseNumber) ?? 0

        return TrendingRepo(
            owner: parts[0], name: parts[1],
            description: description,
            language: language, languageColorHex: colorHex,
            stars: stars, forks: forks, periodStars: periodStars
        )
    }

    // MARK: - Helpers

    /// First capture group of `pattern`, with `.` matching newlines.
    static func firstCapture(_ pattern: String, in text: String) -> String? {
        guard let regex = try? NSRegularExpression(pattern: pattern, options: [.dotMatchesLineSeparators]) else { return nil }
        let ns = text as NSString
        guard let match = regex.firstMatch(in: text, range: NSRange(location: 0, length: ns.length)),
              match.numberOfRanges > 1,
              match.range(at: 1).location != NSNotFound
        else { return nil }
        return ns.substring(with: match.range(at: 1))
    }

    /// Strips tags, decodes entities and collapses whitespace.
    static func cleanText(_ raw: String) -> String {
        let noTags = raw.replacingOccurrences(of: #"<[^>]+>"#, with: "", options: .regularExpression)
        let decoded = decodeEntities(noTags)
        return decoded
            .replacingOccurrences(of: #"\s+"#, with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// Parses a number such as "190,461" out of an HTML fragment.
    static func parseNumber(_ raw: String) -> Int {
        let digits = cleanText(raw).filter(\.isNumber)
        return Int(digits) ?? 0
    }

    /// Decodes common named entities and numeric ones (`&#39;`, `&#x27;`).
    static func decodeEntities(_ s: String) -> String {
        guard s.contains("&") else { return s }
        var result = s
        let named = ["&quot;": "\"", "&apos;": "'", "&lt;": "<", "&gt;": ">", "&nbsp;": " "]
        for (k, v) in named { result = result.replacingOccurrences(of: k, with: v) }

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
        // Decode &amp; last so "&amp;lt;" becomes "&lt;", not "<".
        return result.replacingOccurrences(of: "&amp;", with: "&")
    }
}
