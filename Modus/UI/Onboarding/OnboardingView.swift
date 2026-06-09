import SwiftUI

/// First-launch onboarding flow with three feature cards.
/// Pure SwiftUI implementation (no external dependency).
/// Persisted via AppStorage("hasCompletedOnboarding").
struct OnboardingView: View {
    @Binding var hasCompletedOnboarding: Bool
    @State private var currentPage = 0
    @State private var isAuthorizing = false

    private let features: [FeatureInfo] = [
        FeatureInfo(
            icon: "dot.radiowaves.left.and.right",
            title: "Your Radio, Your Way",
            subtitle: "Modus builds behavioral radio stations from a single song."
        ),
        FeatureInfo(
            icon: "waveform",
            title: "AI DJ Arc",
            subtitle: "Pro subscribers hear AI commentary between tracks. Toggle it anytime in Settings."
        ),
        FeatureInfo(
            icon: "sparkles",
            title: "Discover & Grow",
            subtitle: "Start from any track and your station evolves based on what you skip, keep, and explore."
        )
    ]

    var body: some View {
        ZStack {
            // Subtle gradient background
            LinearGradient(
                colors: [Color.purple.opacity(0.15), Color.black, Color.indigo.opacity(0.15)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            VStack(spacing: 32) {
                Spacer()

                // Page indicator dots
                HStack(spacing: 8) {
                    ForEach(0..<features.count, id: \.self) { index in
                        Circle()
                            .fill(index == currentPage ? Color.accentColor : Color.secondary.opacity(0.4))
                            .frame(width: 8, height: 8)
                            .animation(.easeInOut(duration: 0.3), value: currentPage)
                    }
                }

                // Feature card
                TabView(selection: $currentPage) {
                    ForEach(0..<features.count, id: \.self) { index in
                        featureCard(features[index])
                            .tag(index)
                    }
                }
                .tabViewStyle(.page(indexDisplayMode: .never))
                .animation(.easeInOut(duration: 0.3), value: currentPage)

                Spacer()

                if currentPage == features.count - 1 {
                    // Last page: explicit Apple Music auth step
                    Button {
                        isAuthorizing = true
                        Task {
                            await AppEnvironment.shared.requestAuth()
                            isAuthorizing = false
                            withAnimation { hasCompletedOnboarding = true }
                        }
                    } label: {
                        HStack(spacing: 8) {
                            if isAuthorizing {
                                ProgressView()
                                    .progressViewStyle(.circular)
                                    .tint(.white)
                                    .controlSize(.small)
                            }
                            Text("Connect Apple Music")
                                .font(.headline)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                    }
                    .buttonStyle(.borderedProminent)
                    .padding(.horizontal, 40)
                    .disabled(isAuthorizing)

                    Button("Maybe Later — limited radio") {
                        withAnimation { hasCompletedOnboarding = true }
                    }
                    .foregroundStyle(.secondary)
                    .disabled(isAuthorizing)
                    .padding(.top, 4)

                    Text("Modus uses Apple Music to build your stations. Your listening stays private — we don't sell or share your data.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 32)
                        .padding(.top, 8)
                        .padding(.bottom, 20)
                } else {
                    // Non-last pages: Continue / Skip
                    Button {
                        withAnimation { currentPage += 1 }
                    } label: {
                        Text("Continue")
                            .font(.headline)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                    }
                    .buttonStyle(.borderedProminent)
                    .padding(.horizontal, 40)

                    Button("Skip") {
                        withAnimation { hasCompletedOnboarding = true }
                    }
                    .foregroundStyle(.secondary)
                    .padding(.bottom, 20)
                }
            }
            .padding()
        }
    }

    private func featureCard(_ feature: FeatureInfo) -> some View {
        VStack(spacing: 20) {
            Image(systemName: feature.icon)
                .font(.system(size: 56))
                .foregroundStyle(Color.accentColor)
                .frame(height: 80)

            Text(feature.title)
                .font(.title2.bold())
                .multilineTextAlignment(.center)

            Text(feature.subtitle)
                .font(.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 24)
        }
    }
}

struct FeatureInfo: Identifiable {
    let id = UUID()
    let icon: String
    let title: String
    let subtitle: String
}