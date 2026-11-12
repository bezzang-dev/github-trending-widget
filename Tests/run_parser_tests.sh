#!/bin/zsh
# Runs the parser tests. Needs only the Command Line Tools, not Xcode.
#   ./Tests/run_parser_tests.sh            # test against the saved HTML in Tests/Fixtures
#   ./Tests/run_parser_tests.sh --refresh  # re-download the live pages first (to detect markup changes)
set -euo pipefail
ROOT="${0:A:h:h}"
FIX="$ROOT/Tests/Fixtures"
UA='Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.4 Safari/605.1.15'

if [[ "${1:-}" == "--refresh" ]]; then
  mkdir -p "$FIX"
  curl -sSfL -A "$UA" -o "$FIX/trending_all.html" "https://github.com/trending"
  curl -sSfL -A "$UA" -o "$FIX/trending_java_weekly.html" "https://github.com/trending/java?since=weekly"
fi

OUT="$(mktemp -d)/parser-tests"
swiftc -swift-version 6 -parse-as-library -o "$OUT" \
  "$ROOT/Widget/TrendingModels.swift" \
  "$ROOT/Widget/TrendingParser.swift" \
  "$ROOT/Tests/ParserTests.swift"
"$OUT" "$FIX"
