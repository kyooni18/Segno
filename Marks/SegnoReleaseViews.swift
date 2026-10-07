import SwiftUI

struct AboutSegnoView: View {
    private var version: String {
        let info = Bundle.main.infoDictionary ?? [:]
        let version = info["CFBundleShortVersionString"] as? String ?? "—"
        let build = info["CFBundleVersion"] as? String ?? "—"
        return "Version \(version) (\(build))"
    }

    var body: some View {
        VStack(spacing: 16) {
            Image(nsImage: NSApplication.shared.applicationIconImage)
                .resizable()
                .frame(width: 72, height: 72)
                .accessibilityLabel("Segno app icon")

            Text("Segno")
                .font(.system(size: 25, weight: .semibold))

            Text("A focused place to write, edit, and preview Markdown.")
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)

            Text(version)
                .font(.callout.monospacedDigit())
                .foregroundStyle(.secondary)

            Divider()

            HStack(spacing: 18) {
                Link("Project Website", destination: URL(string: "https://github.com/kyooni18/Marks")!)
                Link("Support and Feedback", destination: URL(string: "https://github.com/kyooni18/Marks/issues")!)
            }
            .font(.callout)

            Text("Segno stores your documents wherever you choose to save them. Update checks contact GitHub Releases only when you choose Check for Updates.")
                .font(.footnote)
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(28)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

struct SegnoUpdatesView: View {
    @EnvironmentObject private var releaseChecker: SegnoReleaseChecker

    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "arrow.down.app")
                .font(.system(size: 38))
                .foregroundStyle(.tint)
                .accessibilityHidden(true)

            Text("Segno Software Update")
                .font(.title2.weight(.semibold))

            Text("Current version: \(Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "—")")
                .font(.callout)
                .foregroundStyle(.secondary)

            Group {
                switch releaseChecker.state {
                case .idle, .checking:
                    ProgressView("Checking GitHub Releases…")
                case .current:
                    Label("You’re up to date.", systemImage: "checkmark.circle.fill")
                        .foregroundStyle(.green)
                case .updateAvailable(let release):
                    VStack(spacing: 10) {
                        Text("\(release.title) is available")
                            .font(.headline)
                        if !release.notes.isEmpty {
                            ScrollView {
                                Text(release.notes)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .textSelection(.enabled)
                            }
                            .frame(maxHeight: 180)
                        }
                        Button("View Release and Update…") {
                            releaseChecker.openRelease(release)
                        }
                        .buttonStyle(.borderedProminent)
                    }
                case .failed(let message):
                    Text(message)
                        .multilineTextAlignment(.center)
                        .foregroundStyle(.secondary)
                }
            }
            .frame(maxWidth: .infinity, minHeight: 92)

            HStack {
                Button("View All Releases") {
                    releaseChecker.openReleasesPage()
                }
                .buttonStyle(.link)
                Spacer()
                Button(releaseChecker.state.isChecking ? "Checking…" : "Check Again") {
                    Task { await releaseChecker.checkForUpdates() }
                }
                .disabled(releaseChecker.state.isChecking)
            }
        }
        .padding(24)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .task {
            if case .idle = releaseChecker.state {
                await releaseChecker.checkForUpdates()
            }
        }
    }
}

private extension SegnoReleaseChecker.State {
    var isChecking: Bool {
        if case .checking = self { return true }
        return false
    }
}
