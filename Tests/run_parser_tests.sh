#!/bin/zsh
# 파서 테스트 실행 스크립트. Xcode 없이 Command Line Tools만 있어도 동작.
#   ./Tests/run_parser_tests.sh            # 저장된 HTML(Fixtures)로 테스트
#   ./Tests/run_parser_tests.sh --refresh  # 실제 페이지를 다시 받아서 테스트 (구조 변경 확인용)
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
