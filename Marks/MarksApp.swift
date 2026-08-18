import SwiftUI

@main
struct MarksApp: App {
    var body: some Scene {
        DocumentGroup(newDocument: { MarkdownDocument() }) { file in
            ContentView(document: file.document)
        }

        Settings {
            MarkdownStyleSettingsView()
        }
    }
}
