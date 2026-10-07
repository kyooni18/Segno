import AppKit
import SwiftUI

enum SegnoPreferences {
    static let readOnlyKey = "editor.readOnly"
    static let tableOfContentsPresentedKey = "navigation.tableOfContentsPresented"
}

private struct DocumentSearchPresentedKey: FocusedValueKey {
    typealias Value = Binding<Bool>
}

struct DocumentSearchCommandActions {
    let showFind: () -> Void
    let findNext: () -> Void
    let findPrevious: () -> Void
}

private struct DocumentSearchCommandActionsKey: FocusedValueKey {
    typealias Value = DocumentSearchCommandActions
}

private struct TableOfContentsPresentedKey: FocusedValueKey {
    typealias Value = Binding<Bool>
}

private struct DocumentFileURLKey: FocusedValueKey {
    typealias Value = URL
}

private struct EditorFontSizeKey: FocusedValueKey {
    typealias Value = Binding<Double>
}

extension FocusedValues {
    var documentSearchPresented: Binding<Bool>? {
        get { self[DocumentSearchPresentedKey.self] }
        set { self[DocumentSearchPresentedKey.self] = newValue }
    }

    var documentSearchCommandActions: DocumentSearchCommandActions? {
        get { self[DocumentSearchCommandActionsKey.self] }
        set { self[DocumentSearchCommandActionsKey.self] = newValue }
    }

    var tableOfContentsPresented: Binding<Bool>? {
        get { self[TableOfContentsPresentedKey.self] }
        set { self[TableOfContentsPresentedKey.self] = newValue }
    }

    var documentFileURL: URL? {
        get { self[DocumentFileURLKey.self] }
        set { self[DocumentFileURLKey.self] = newValue }
    }

    var editorFontSize: Binding<Double>? {
        get { self[EditorFontSizeKey.self] }
        set { self[EditorFontSizeKey.self] = newValue }
    }
}

@main
struct SegnoApp: App {
    @StateObject private var updater = SegnoUpdater()

    var body: some Scene {
        DocumentGroup(newDocument: { MarkdownDocument() }) { file in
            ContentView(document: file.document, fileURL: file.fileURL)
                .toolbarBackground(.background,
                                   for: .windowToolbar)
                .toolbarBackgroundVisibility(.visible, for: .windowToolbar)
        }
        .restorationBehavior(.automatic)
        .windowToolbarStyle(.unifiedCompact(showsTitle: true))
        .commands {
            AppInformationCommands(updater: updater)
            ReadOnlyCommands()
            NavigationCommands()
            DocumentCommands()
            EditorSizingCommands()
        }

        Settings {
            MarkdownStyleSettingsView()
        }

        Window("About Segno", id: "about") {
            AboutSegnoView()
        }
        .defaultSize(width: 376, height: 220)
        .windowResizability(.contentSize)

    }
}

private struct AppInformationCommands: Commands {
    @Environment(\.openWindow) private var openWindow
    @ObservedObject var updater: SegnoUpdater

    var body: some Commands {
        CommandGroup(replacing: .appInfo) {
            Button("About Segno") {
                openWindow(id: "about")
            }

            Button("Check for Updates…", action: updater.checkForUpdates)
                .disabled(!updater.canCheckForUpdates)
        }
    }
}

private struct NavigationCommands: Commands {
    @FocusedBinding(\.documentSearchPresented)
    private var isSearchPresented

    @FocusedValue(\.documentSearchCommandActions)
    private var searchActions

    @FocusedBinding(\.tableOfContentsPresented)
    private var isTableOfContentsPresented

    var body: some Commands {
        CommandGroup(after: .textEditing) {
            Button("Find in Document…") {
                if let searchActions {
                    searchActions.showFind()
                } else {
                    isSearchPresented = true
                }
            }
            .keyboardShortcut("f", modifiers: .command)
            .disabled(isSearchPresented == nil)

            Button("Find Next") {
                searchActions?.findNext()
            }
            .keyboardShortcut("g", modifiers: .command)
            .disabled(searchActions == nil)

            Button("Find Previous") {
                searchActions?.findPrevious()
            }
            .keyboardShortcut("g", modifiers: [.command, .shift])
            .disabled(searchActions == nil)
        }

        CommandGroup(after: .sidebar) {
            Button(
                isTableOfContentsPresented == true
                    ? String(localized: "Hide Table of Contents")
                    : String(localized: "Show Table of Contents")
            ) {
                guard let isTableOfContentsPresented else { return }
                self.isTableOfContentsPresented = !isTableOfContentsPresented
            }
            .keyboardShortcut("o", modifiers: [.command, .shift])
            .disabled(isTableOfContentsPresented == nil)
        }
    }
}

private struct DocumentCommands: Commands {
    @FocusedValue(\.documentFileURL)
    private var documentFileURL

    var body: some Commands {
        CommandGroup(after: .saveItem) {
            Button("Show in Finder") {
                guard let documentFileURL else { return }
                NSWorkspace.shared.activateFileViewerSelecting([documentFileURL])
            }
            .keyboardShortcut("r", modifiers: [.command, .shift])
            .disabled(documentFileURL == nil)

            Button("Copy File Path") {
                guard let documentFileURL else { return }
                NSPasteboard.general.clearContents()
                NSPasteboard.general.setString(documentFileURL.path, forType: .string)
            }
            .disabled(documentFileURL == nil)
        }
    }
}

private struct EditorSizingCommands: Commands {
    @FocusedBinding(\.editorFontSize)
    private var fontSize

    var body: some Commands {
        CommandGroup(after: .toolbar) {
            Button("Increase Text Size") {
                guard let fontSize else { return }
                self.fontSize = min(32, fontSize + 1)
            }
            .keyboardShortcut("+", modifiers: .command)
            .disabled(fontSize == nil || fontSize == 32)

            Button("Decrease Text Size") {
                guard let fontSize else { return }
                self.fontSize = max(12, fontSize - 1)
            }
            .keyboardShortcut("-", modifiers: .command)
            .disabled(fontSize == nil || fontSize == 12)

            Button("Actual Text Size") {
                fontSize = 16
            }
            .keyboardShortcut("0", modifiers: .command)
            .disabled(fontSize == nil)
        }
    }
}

private struct ReadOnlyCommands: Commands {
    @AppStorage(SegnoPreferences.readOnlyKey)
    private var isReadOnly = false

    var body: some Commands {
        CommandGroup(after: .toolbar) {
            Toggle("Read-Only Mode", isOn: $isReadOnly)
                .keyboardShortcut("l", modifiers: [.command, .shift])
        }
    }
}
