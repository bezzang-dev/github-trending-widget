import AppKit
import OSLog
import SwiftUI

/// Host app that embeds the widget extension; launching it once registers the widget.
///
/// On macOS, widget `Link` / `widgetURL` taps are delivered to the containing app instead of
/// the browser, so the app forwards http(s) URLs to the default browser.
@main
struct GitHubTrendingApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    var body: some Scene {
        WindowGroup {
            GuideView()
        }
        .windowResizability(.contentSize)
        // Don't open a new window for incoming URLs; AppDelegate handles them.
        .handlesExternalEvents(matching: [])
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    private let log = Logger(subsystem: "com.jmkim.GitHubTrending", category: "WidgetClick")
    private var didFinishLaunching = false
    /// Set when the app was launched only to handle a widget tap; it quits after opening the URL.
    private var launchedForURL = false

    func application(_ application: NSApplication, open urls: [URL]) {
        log.info("received URLs: \(urls.map(\.absoluteString), privacy: .public)")
        for url in urls where ["http", "https"].contains(url.scheme?.lowercased()) {
            NSWorkspace.shared.open(url)
        }
        if !didFinishLaunching {
            // URLs that arrive before launch finishes are what launched us.
            launchedForURL = true
        }
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        didFinishLaunching = true
        if launchedForURL {
            // Hide the guide window so it doesn't flash before quitting.
            NSApp.windows.forEach { $0.orderOut(nil) }
            DispatchQueue.main.async { NSApp.terminate(nil) }
        }
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { true }
}

struct GuideView: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Label("GitHub Trending 위젯", systemImage: "chart.line.uptrend.xyaxis")
                .font(.title2.bold())

            Text("위젯이 설치되었습니다. 이 앱은 창을 닫아도 됩니다.")
                .foregroundStyle(.secondary)

            VStack(alignment: .leading, spacing: 6) {
                Text("위젯 추가 방법").font(.headline)
                Text("1. 메뉴 막대의 시계를 클릭해 알림 센터를 엽니다.")
                Text("2. 맨 아래 \"위젯 편집…\"을 누릅니다.")
                Text("3. 목록에서 \"GitHubTrending\"을 찾아 중간/대형 크기를 끌어다 놓습니다.")
                Text("4. 위젯을 우클릭 → \"위젯 편집\"에서 언어·기간·갱신 주기·표시 언어 등을 고릅니다.")
            }

            Link("github.com/trending 열기", destination: URL(string: "https://github.com/trending")!)
        }
        .padding(24)
        .frame(width: 440)
    }
}
