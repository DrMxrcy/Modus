import SwiftUI

/// First-launch onboarding flow with three feature cards.
/// Pure SwiftUI implementation (no external dependency).
/// Persisted via AppStorage("hasCompletedOnboarding").
struct OnboardingView: View {
    @Binding var hasCompletedOnboarding: Bool
    @State private var currentPage = 0

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

                // Continue / Get Started button
                Button {
                    withAnimation {
                        hasCompletedOnboarding = true
                    }
                } label: {
                    Text(currentPage == features.count - 1 ? "Get Started" : "Continue")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                }
                .buttonStyle(.borderedProminent)
                .padding(.horizontal, 40)

                // Skip button (except last page)
                if currentPage < features.count - 1 {
                    Button("Skip") {
                        withAnimation {
                            hasCompletedOnboarding = true
                        }
                    }
                    .foregroundStyle(.secondary)
                    .padding(.bottom, 20)
                } else {
                    Spacer().frame(height: 44)
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