import AppKit
import OSLog
import SwiftUI

/// 호스트 앱. 위젯 익스텐션은 단독 배포가 안 되고 반드시 앱 안에 embed되어야 해서 존재한다.
/// 한 번 실행하면 시스템이 앱 안의 위젯을 등록한다.
///
/// 또 하나의 역할: **위젯 클릭 처리**.
/// macOS에서 위젯의 `Link` / `.widgetURL`을 클릭하면 URL이 브라우저로 바로 가지 않고
/// 위젯을 담은 이 앱으로 전달된다. 그래서 받은 URL을 기본 브라우저로 넘겨준다.
@main
struct GitHubTrendingApp: App {
    // SwiftUI 앱에서 AppKit의 AppDelegate 콜백을 쓰기 위한 연결 (Spring의 리스너 등록 비슷한 느낌)
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    var body: some Scene {
        WindowGroup {
            GuideView()
        }
        .windowResizability(.contentSize)
        // URL 이벤트가 와도 SwiftUI가 새 창을 만들지 않도록 (URL은 AppDelegate가 처리)
        .handlesExternalEvents(matching: [])
    }
}

/// NSApplicationDelegate는 MainActor(UI 스레드) 격리라 이 클래스도 자동으로 MainActor에서 동작한다.
final class AppDelegate: NSObject, NSApplicationDelegate {
    private let log = Logger(subsystem: "com.jmkim.GitHubTrending", category: "WidgetClick")
    private var didFinishLaunching = false
    /// 위젯 클릭 때문에 앱이 "새로" 실행된 경우 → URL만 열고 바로 종료
    private var launchedForURL = false

    func application(_ application: NSApplication, open urls: [URL]) {
        log.info("received URLs: \(urls.map(\.absoluteString), privacy: .public)")
        for url in urls where ["http", "https"].contains(url.scheme?.lowercased()) {
            NSWorkspace.shared.open(url)
        }
        if !didFinishLaunching {
            // 실행 완료 전에 URL이 왔다 = URL 때문에 실행됨
            launchedForURL = true
        }
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        didFinishLaunching = true
        if launchedForURL {
            // 안내 창이 잠깐 보이지 않도록 바로 닫고 종료
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
                Text("4. 위젯을 우클릭 → \"위젯 편집\"에서 언어·기간·사용 언어를 고릅니다.")
            }

            Link("github.com/trending 열기", destination: URL(string: "https://github.com/trending")!)
        }
        .padding(24)
        .frame(width: 440)
    }
}
