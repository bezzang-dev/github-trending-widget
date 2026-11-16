# GitHub Trending Widget for macOS

**English** | [한국어](README.ko.md)

A WidgetKit widget that shows the top repositories from [github.com/trending](https://github.com/trending) in Notification Center or on the desktop.
Built with SwiftUI, WidgetKit and App Intents only, with no third-party dependencies.

- Requires macOS 14 (Sonoma) or later
- Sizes: **Medium** shows single-line rows (up to 7, with a smaller font above 5); **Large** adds the description, language, stars and forks (at 7 items it drops the stats line; at 10 it uses single-line rows)
- Configurable in Edit Widget: **programming language, period, spoken language, item count (3/5/7/10), refresh interval, display language**
- Display language: System / 한국어 / English (applies to the widget's text and time format)
- Refreshes at the chosen interval (1 hour by default, 15 minutes to 12 hours) and retries within 15 minutes after a failure. When a refresh fails, the last successful result is shown with a ⚠️ icon
- Clicking a row opens the repository in your browser

## Project layout

```
.
├── project.yml                  # XcodeGen spec; GitHubTrending.xcodeproj is generated from it (not checked in)
├── Signing.example.xcconfig     # Copy to Signing.xcconfig and set your team ID
├── App/
│   └── GitHubTrendingApp.swift  # Host app: setup guide + forwards widget click URLs to the browser
├── Widget/                      # Widget extension target (TrendingWidget.appex)
│   ├── TrendingIntent.swift     # Configuration AppEnums, WidgetConfigurationIntent, URL building
│   ├── TrendingStrings.swift    # In-widget strings (Korean / English)
│   ├── TrendingModels.swift     # TrendingRepo / TrendingSnapshot and sample data
│   ├── TrendingParser.swift     # HTML parser; the only file to touch when GitHub's markup changes
│   ├── TrendingService.swift    # Fetch (Safari UA) → parse → UserDefaults cache
│   └── TrendingWidget.swift     # Entry, timeline provider, views, Widget, WidgetBundle, #Preview
└── Tests/
    ├── Fixtures/*.html          # Saved copies of real trending pages
    ├── ParserTests.swift        # Parser tests
    └── run_parser_tests.sh      # Test runner (needs only the Command Line Tools, not Xcode)
```

### How it works

A widget is not a long-running process. The system daemon (`chronod`) briefly wakes the extension, calls
`timeline(for:in:)`, stores the returned entries and the next reload date (`.after(date)`), then terminates the extension.
The refresh interval is therefore expressed as a **timeline reload policy** rather than a timer, and the system may delay reloads to save power.

GitHub has no trending API, so the widget parses the page HTML. It always fetches and caches the top 10, then slices the list to fit the widget size and the configured item count.

## Getting started

### 1. Set up Xcode

```bash
xcode-select -p
```

If this prints `/Library/Developer/CommandLineTools` instead of `/Applications/Xcode.app/Contents/Developer`, switch to Xcode.
(Install Xcode from the App Store and launch it once to finish installing its components.)

```bash
sudo xcode-select -s /Applications/Xcode.app/Contents/Developer
```

```bash
sudo xcodebuild -license accept
```

### 2. Code signing (Personal Team)

1. In Xcode → Settings → Accounts, click `+` and sign in with your Apple ID to create a Personal Team.
2. Find your team ID, either in the Accounts pane or as the `OU=` value printed by:

```bash
security find-certificate -c "Apple Development" -p | openssl x509 -noout -subject
```

3. Copy the example file and put your 10-character team ID after `DEVELOPMENT_TEAM = ` (`Signing.xcconfig` is git-ignored).

```bash
cp Signing.example.xcconfig Signing.xcconfig
```

> If signing fails because the bundle ID `com.jmkim.GitHubTrending` is already taken, change both `PRODUCT_BUNDLE_IDENTIFIER` values in `project.yml` to your own. The widget's ID must be the app's ID plus a `.suffix`.

### 3. Generate and build

```bash
brew install xcodegen
```

```bash
xcodegen generate
```

```bash
xcodebuild -project GitHubTrending.xcodeproj -scheme GitHubTrending -configuration Debug -derivedDataPath build -allowProvisioningUpdates build
```

### 4. Run and add the widget

```bash
open build/Build/Products/Debug/GitHubTrending.app
```

The system registers the widget the first time the app runs. Then:

1. Click the **date and time** in the menu bar to open Notification Center.
2. Click **Edit Widgets…** at the bottom (or right-click the desktop → Edit Widgets…).
3. Select **GitHubTrending** in the list and drag a medium or large widget into place.
4. Right-click the widget → **Edit Widget** to choose the programming language, period, spoken language, item count, refresh interval and display language.

> Copying the app to `/Applications` keeps the widget working reliably across restarts.
> If you do, **copy it again after every build**; otherwise the system keeps running the old copy in `/Applications`.
>
> ```bash
> rm -rf /Applications/GitHubTrending.app && cp -R build/Build/Products/Debug/GitHubTrending.app /Applications/
> ```

### Parser tests

```bash
./Tests/run_parser_tests.sh
```

To re-download the live pages and check whether the markup has changed:

```bash
./Tests/run_parser_tests.sh --refresh
```

## Troubleshooting

### The widget doesn't appear, or code changes don't show up

1. Make sure you have launched the app at least once; that is what registers the widget.
2. If the app exists in more than one place (`build/`, DerivedData, `/Applications`), an old copy may be the one running. Check the path of the running widget process:

```bash
ps -axo command | grep TrendingWidget.appex | grep -v grep
```

   If it's an outdated copy in `/Applications`, replace it with the copy command above, or delete all but one copy and refresh its Launch Services registration:

```bash
/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister -f -R -trusted build/Build/Products/Debug/GitHubTrending.app
```

3. Restart the widget processes (they relaunch automatically):

```bash
killall TrendingWidget NotificationCenter chronod
```

4. Check that the system sees the extension (a leading `+` means it's enabled):

```bash
pluginkit -mAvvv -p com.apple.widgetkit-extension | grep -i -A3 trending
```

5. If it still doesn't update, remove and re-add the widget, or as a last resort log out or restart.

### The widget only says "Couldn't load"

- Make sure the widget's entitlements include `com.apple.security.network.client`; without it the sandbox blocks all network access.

```bash
codesign -d --entitlements - build/Build/Products/Debug/GitHubTrending.app/Contents/PlugIns/TrendingWidget.appex
```

- Check the logs in Console.app, filtered to the `TrendingWidget` process.
- GitHub may have changed its markup. Run `./Tests/run_parser_tests.sh --refresh` to confirm, then update `TrendingParser.swift`.

### ⚠️ icon in the header

The last refresh failed and cached results are being shown. The widget retries after 15 minutes, or sooner if your refresh interval is shorter.

### Signing errors (`No Account for Team`, `requires a development team`)

Set your team ID in `Signing.xcconfig` and run `xcodegen generate` again. Xcode must be signed in to your Apple ID.

### Swift 6 concurrency errors

The project builds with `SWIFT_VERSION = 6.0` (strict concurrency checking). Common errors:

- **`static var ... is not concurrency-safe`**: mutable global state isn't allowed. Use `static let` when the value never changes (e.g. an AppEnum's `caseDisplayRepresentations`).
- **`Main actor-isolated ... cannot be referenced from a nonisolated context`**: SwiftUI views are bound to the main actor. Move logic shared with background code such as the timeline provider into a `Sendable` type outside the view.
- **`Non-sendable type ... crossing actor boundary`**: values that cross concurrency boundaries must be `Sendable`. This project converts the intent into `TrendingQuery`, a `Sendable` struct, instead of passing the intent around.

### #Preview doesn't render in the Xcode canvas

Open `TrendingWidget.swift` and select the **TrendingWidget** scheme in the canvas. Previews live inside `#if DEBUG`, so they only compile in the Debug configuration.
