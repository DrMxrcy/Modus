import SwiftUI

struct MainTabView: View {
    @StateObject private var env = AppEnvironment.shared

    var body: some View {
        TabView {
            RadioView()
                .tabItem {
                    Label("Radio", systemImage: "dot.radiowaves.left.and.right")
                }

            SearchView()
                .tabItem {
                    Label("Search", systemImage: "magnifyingglass")
                }
        }
        .environmentObject(env)
    }
}
