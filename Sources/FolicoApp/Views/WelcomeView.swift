import SwiftUI

struct WelcomeView: View {
    @EnvironmentObject private var appState: AppState

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 28) {
                HStack(alignment: .center, spacing: 18) {
                    AppIconMark()

                    VStack(alignment: .leading, spacing: 6) {
                        Text("Folico")
                            .font(.system(size: 52, weight: .bold))
                        Text("Make Finder make sense.")
                            .font(.title2)
                            .foregroundStyle(.secondary)
                    }
                }

                Text("Folico auto-generates folder icon suggestions from folder names. AI agents can use the CLI to explain the plan and apply only the changes you approve.")
                    .font(.title3)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: 760, alignment: .leading)

                LazyVGrid(columns: [GridItem(.adaptive(minimum: 210), spacing: 14)], alignment: .leading, spacing: 14) {
                    OnboardingStep(
                        systemImage: "wand.and.sparkles",
                        title: "Auto-generate",
                        message: "Scan child folders and match names like Invoices, Photos, GitHub, Design, Movies, and Music."
                    )
                    OnboardingStep(
                        systemImage: "brain.head.profile",
                        title: "AI-ready",
                        message: "Ask an agent to run Folico's JSON CLI, summarize suggestions, and choose approved item numbers."
                    )
                    OnboardingStep(
                        systemImage: "checklist",
                        title: "Preview first",
                        message: "Review every suggested icon before Folico changes Finder metadata."
                    )
                    OnboardingStep(
                        systemImage: "arrow.uturn.backward.circle",
                        title: "Restore anytime",
                        message: "Folico records applied icons so you can restore default folder icons later."
                    )
                }

                VStack(alignment: .leading, spacing: 10) {
                    Text("Privacy")
                        .font(.headline)
                    Text("Folico only scans folder names inside folders you select. It does not upload your files or read file contents.")
                        .foregroundStyle(.secondary)
                }
                .padding(14)
                .frame(maxWidth: 760, alignment: .leading)
                .background(.green.opacity(0.10), in: RoundedRectangle(cornerRadius: 8))

                HStack(spacing: 12) {
                    Button {
                        appState.chooseWatchedFolder()
                    } label: {
                        Label("Choose Folder", systemImage: "folder.badge.plus")
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)

                    Button {
                        appState.selectedSection = .settings
                    } label: {
                        Label("View Build Info", systemImage: "hammer")
                    }
                    .controlSize(.large)
                }
            }
            .padding(48)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
    }
}

private struct AppIconMark: View {
    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 24)
                .fill(.blue.gradient)
                .frame(width: 92, height: 92)
                .shadow(color: .black.opacity(0.18), radius: 12, y: 5)

            Image(systemName: "folder.fill")
                .font(.system(size: 48, weight: .semibold))
                .foregroundStyle(.white)

            Image(systemName: "sparkle")
                .font(.system(size: 20, weight: .bold))
                .foregroundStyle(.blue)
                .offset(x: 22, y: 10)
        }
        .frame(width: 104, height: 104)
    }
}

private struct OnboardingStep: View {
    let systemImage: String
    let title: String
    let message: String

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Image(systemName: systemImage)
                .font(.system(size: 24, weight: .semibold))
                .foregroundStyle(.blue)
                .frame(width: 34, height: 34, alignment: .leading)

            Text(title)
                .font(.headline)

            Text(message)
                .font(.callout)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(14)
        .frame(maxWidth: .infinity, minHeight: 156, alignment: .topLeading)
        .background(.secondary.opacity(0.08), in: RoundedRectangle(cornerRadius: 8))
    }
}
