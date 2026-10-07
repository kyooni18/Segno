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

            Text("Segno stores your documents wherever you choose to save them. Sparkle checks Segno’s update feed for signed releases.")
                .font(.footnote)
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(28)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
