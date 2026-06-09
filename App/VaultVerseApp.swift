import SwiftUI

@main
struct VaultVerseApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @State private var env = AppEnvironment.makeDefault()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(env)
                .frame(minWidth: 1060, minHeight: 700)
                .task {
                    await env.restoreActiveLibrary()
                    await env.refreshConnection()
                }
                .tint(VaultTheme.cherryPink)
                .preferredColorScheme(.dark)
        }
        .windowStyle(.titleBar)
        .windowToolbarStyle(.unified)
        .defaultSize(width: 1240, height: 820)
    }
}
