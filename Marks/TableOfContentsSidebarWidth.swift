import AppKit
import SwiftUI

enum TableOfContentsSidebarWidth {
    static let storageKey = "navigation.tableOfContentsWidth"
    static let minimum: CGFloat = 190
    static let ideal: CGFloat = 250
    static let maximum: CGFloat = 360

    /// Restores the width the user last dragged to, or `ideal` when none was saved.
    static func restoredWidth() -> CGFloat {
        let stored = UserDefaults.standard.double(forKey: storageKey)
        guard stored > 0 else { return ideal }
        return clamped(CGFloat(stored))
    }

    static func clamped(_ width: CGFloat) -> CGFloat {
        min(max(width, minimum), maximum)
    }
}

/// Wraps the Table of Contents so the width the user drags to is saved.
///
/// Only changes made while the left mouse button is held are saved. Presenting,
/// hiding, and relaunch layout all change the width without a drag, so they
/// never overwrite the saved value with a transient or default width.
struct TableOfContentsInspector: View {
    let headings: [MarkdownOutline.Heading]
    let onSelect: (MarkdownOutline.Heading) -> Void

    @AppStorage(TableOfContentsSidebarWidth.storageKey)
    private var storedWidth = Double(TableOfContentsSidebarWidth.ideal)

    var body: some View {
        TableOfContentsView(headings: headings, onSelect: onSelect)
            .onGeometryChange(for: CGFloat.self) { proxy in
                proxy.size.width
            } action: { width in
                guard NSEvent.pressedMouseButtons & 1 != 0 else { return }
                storedWidth = Double(TableOfContentsSidebarWidth.clamped(width))
            }
    }
}
