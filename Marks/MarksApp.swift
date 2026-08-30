import SwiftUI

enum MarksPreferences {
    static let readOnlyKey = "editor.readOnly"
}

@main
struct MarksApp: App {
    var body: some Scene {
        DocumentGroup(newDocument: { MarkdownDocument() }) { file in
            ContentView(document: file.document)
        }
        .commands {
            ReadOnlyCommands()
        }

        Settings {
            MarkdownStyleSettingsView()
        }
    }
}

private struct ReadOnlyCommands: Commands {
    @AppStorage(MarksPreferences.readOnlyKey)
    private var isReadOnly = false

    var body: some Commands {
        CommandGroup(after: .toolbar) {
            Toggle("Read-Only Mode", isOn: $isReadOnly)
        }
    }
}
