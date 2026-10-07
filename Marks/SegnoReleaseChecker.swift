import AppKit
import Combine
import Foundation

@MainActor
final class SegnoReleaseChecker: ObservableObject {
    struct Release {
        let version: String
        let title: String
        let notes: String
        let url: URL
    }

    enum State {
        case idle
        case checking
        case current
        case updateAvailable(Release)
        case failed(String)
    }

    @Published private(set) var state: State = .idle

    private let releasesURL = URL(string: "https://api.github.com/repos/kyooni18/Marks/releases/latest")!
    private var currentVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "0"
    }

    func checkForUpdates() async {
        if case .checking = state { return }
        state = .checking

        do {
            var request = URLRequest(url: releasesURL)
            request.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
            request.setValue("Segno/\(currentVersion)", forHTTPHeaderField: "User-Agent")
            let (data, response) = try await URLSession.shared.data(for: request)
            guard let response = response as? HTTPURLResponse,
                  (200..<300).contains(response.statusCode) else {
                state = .failed("Segno couldn’t reach the release service. Check your connection and try again.")
                return
            }

            let release = try JSONDecoder().decode(GitHubRelease.self, from: data)
            guard let url = URL(string: release.htmlURL) else {
                state = .failed("The release service returned an invalid release link.")
                return
            }

            let latestVersion = release.tagName.trimmingCharacters(in: CharacterSet(charactersIn: "vV"))
            if Self.compareVersions(latestVersion, currentVersion) == .orderedDescending {
                state = .updateAvailable(
                    Release(
                        version: latestVersion,
                        title: release.name?.isEmpty == false ? release.name! : "Segno \(latestVersion)",
                        notes: release.body?.trimmingCharacters(in: .whitespacesAndNewlines) ?? "",
                        url: url
                    )
                )
            } else {
                state = .current
            }
        } catch {
            state = .failed("Segno couldn’t check for updates. Check your connection and try again.")
        }
    }

    func openRelease(_ release: Release) {
        NSWorkspace.shared.open(release.url)
    }

    func openReleasesPage() {
        NSWorkspace.shared.open(URL(string: "https://github.com/kyooni18/Marks/releases")!)
    }

    private static func compareVersions(_ lhs: String, _ rhs: String) -> ComparisonResult {
        let left = lhs.split(separator: ".").map { Int($0) ?? 0 }
        let right = rhs.split(separator: ".").map { Int($0) ?? 0 }
        for index in 0..<max(left.count, right.count) {
            let a = index < left.count ? left[index] : 0
            let b = index < right.count ? right[index] : 0
            if a != b { return a < b ? .orderedAscending : .orderedDescending }
        }
        return .orderedSame
    }

    private struct GitHubRelease: Decodable {
        let tagName: String
        let name: String?
        let body: String?
        let htmlURL: String

        enum CodingKeys: String, CodingKey {
            case tagName = "tag_name"
            case name
            case body
            case htmlURL = "html_url"
        }
    }
}
