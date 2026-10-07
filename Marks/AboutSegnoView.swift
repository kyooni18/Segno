import SwiftUI

struct AboutSegnoView: View {
    private var version: String {
        let info = Bundle.main.infoDictionary ?? [:]
        return info["CFBundleShortVersionString"] as? String ?? "—"
    }

    private var build: String {
        let info = Bundle.main.infoDictionary ?? [:]
        return info["CFBundleVersion"] as? String ?? "—"
    }

    var body: some View {
        VStack(spacing: 12) {
            Image(nsImage: NSApplication.shared.applicationIconImage)
                .resizable()
                .frame(width: 64, height: 64)
                .accessibilityLabel(Text("Segno app icon"))

            Text("Segno")
                .font(.system(size: 24, weight: .semibold))

            Text("Version \(version) (\(build))")
                .font(.callout.monospacedDigit())
                .foregroundStyle(.secondary)
        }
        .frame(width: 320)
        .padding(28)
        .fixedSize(horizontal: true, vertical: true)
    }
}
