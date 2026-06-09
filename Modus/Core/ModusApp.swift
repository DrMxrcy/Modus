import SwiftUI
import SwiftData
import TipKit

@main
struct ModusApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    init() {
        // Configure TipKit on launch — contextual tips fire once per feature encounter
        do {
            try Tips.configure()
        } catch {
            // TipKit is best-effort; don't crash if configuration fails
        }
    }

    var body: some Scene {
        WindowGroup {
            MainTabView()
                .environmentObject(AppEnvironment.shared)
                .modelContainer(AppEnvironment.shared.modelContainer)
        }
    }
}

class AppDelegate: NSObject, UIApplicationDelegate {
    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        return true
    }
}
