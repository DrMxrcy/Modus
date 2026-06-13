import SwiftUI
import StoreKit

struct SettingsView: View {
    @EnvironmentObject var env: AppEnvironment
    @AppStorage("djVoiceEnabled") private var djVoiceEnabled = true
    @AppStorage("defaultSurpriseMode") private var defaultSurpriseMode = false
    @AppStorage("defaultArcShaping") private var defaultArcShaping = false

    var body: some View {
        NavigationStack {
            Form {
                // MARK: - DJ & Station
                Section {
                    Toggle(isOn: $djVoiceEnabled) {
                        Label("AI DJ Voice", systemImage: "waveform")
                    }
                    Text("Hear AI commentary between tracks")
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    Toggle(isOn: $defaultSurpriseMode) {
                        Label("Surprise Me", systemImage: "shuffle")
                    }
                    Text("Start stations with surprise picks enabled")
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    if env.subscriptionManager.isPro {
                        Toggle(isOn: $defaultArcShaping) {
                            Label("DJ Arc", systemImage: "sparkles")
                        }
                        Text("Use DJ Arc to shape station flow")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    } else {
                        HStack {
                            Label {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text("DJ Arc")
                                    Text("Pro feature — AI-powered station shaping")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            } icon: {
                                Image(systemName: "sparkles")
                            }
                            Spacer()
                            Text("Pro")
                                .font(.caption2.bold())
                                .foregroundStyle(.white)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 3)
                                .background(Color.accentColor, in: Capsule())
                        }
                    }
                } header: {
                    Text("DJ & Station")
                }

                // MARK: - Account
                Section {
                    Button {
                        showPaywall = true
                    } label: {
                        HStack {
                            Label("Subscription", systemImage: "person.crop.circle")
                            Spacer()
                            Text(env.subscriptionManager.isPro ? "Pro" : "Free")
                                .font(.subheadline.bold())
                                .foregroundStyle(env.subscriptionManager.isPro ? .green : .secondary)
                            Image(systemName: "chevron.right")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }

                    Button {
                        Task { await env.subscriptionManager.restorePurchases() }
                    } label: {
                        Label("Restore Purchases", systemImage: "arrow.clockwise")
                    }
                    .disabled(env.subscriptionManager.isRestoring)
                } header: {
                    Text("Account")
                }

                // MARK: - About
                Section {
                    Link(destination: URL(string: "https://modus.audio/privacy")!) {
                        Label("Privacy Policy", systemImage: "hand.raised")
                    }

                    HStack {
                        Label("Version", systemImage: "info.circle")
                        Spacer()
                        Text(appVersion)
                            .foregroundStyle(.secondary)
                    }
                } header: {
                    Text("About")
                }

                // MARK: - Debug (Phase 0 engine spike)
                Section {
                    NavigationLink {
                        SpikeView()
                    } label: {
                        Label("Phase 0 Engine Spike", systemImage: "ladybug")
                    }
                } header: {
                    Text("Debug")
                } footer: {
                    Text("Device-only. Validates Song.station steerability and on-device preview MIR before the engine pivot.")
                }
            }
            .navigationTitle("Settings")
            .sheet(isPresented: $showPaywall) {
                PaywallSheet(
                    subscriptionManager: env.subscriptionManager,
                    onDismiss: { showPaywall = false }
                )
                .presentationDetents([.medium, .large])
            }
        }
    }

    // MARK: - Private

    @State private var showPaywall = false

    private var appVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "—"
    }
}