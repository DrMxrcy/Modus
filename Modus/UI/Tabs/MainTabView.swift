import SwiftUI

struct MainTabView: View {
    @StateObject private var env = AppEnvironment.shared

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
        }
        .environmentObject(env)
    }
}
