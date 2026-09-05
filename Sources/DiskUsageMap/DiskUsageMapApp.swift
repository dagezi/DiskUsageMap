import SwiftUI
import AppKit

/// A bare `swift build`/`swift run` executable has no Info.plist, so
/// LaunchServices' guess at whether this should be a normal foreground app is
/// unreliable — it can (and, per user report, sometimes does) register it as
/// "BackgroundOnly": no Dock icon, no Cmd+Tab entry, no visible window. Force
/// the normal, findable app policy explicitly instead of leaving it to chance.
final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)
    }
}

@main
struct DiskUsageMapApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .windowResizability(.contentSize)
        .defaultSize(width: 1100, height: 700)
    }
}
