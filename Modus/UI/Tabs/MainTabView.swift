import SwiftUI

struct MainTabView: View {
    @StateObject private var env = AppEnvironment.shared
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = false

    var body: some View {
        TabView(selection: $env.selectedTab) {
            RadioView()
                .tabItem {
                    Label("Radio", systemImage: "dot.radiowaves.left.and.right")
                }
                .tag(0)

            SearchView()
                .tabItem {
                    Label("Search", systemImage: "magnifyingglass")
                }
                .tag(1)

            SettingsView()
                .tabItem {
                    Label("Settings", systemImage: "gearshape")
                }
                .tag(2)
        }
        .environmentObject(env)
        .fullScreenCover(isPresented: Binding(
            get: { !hasCompletedOnboarding },
            set: { if !$0 { hasCompletedOnboarding = true } }
        )) {
            OnboardingView(hasCompletedOnboarding: $hasCompletedOnboarding)
        }
    }
}