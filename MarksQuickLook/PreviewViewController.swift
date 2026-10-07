import AppKit
import MarkdownEngine
import MarkdownEngineCodeBlocks
import MarkdownEngineLatex
import QuickLookUI
import SwiftUI

final class PreviewViewController: NSViewController, QLPreviewingController {
    override func loadView() {
        view = NSView(frame: NSRect(x: 0, y: 0, width: 760, height: 900))
        preferredContentSize = NSSize(width: 760, height: 900)
    }

    func preparePreviewOfFile(at url: URL, completionHandler handler: @escaping (Error?) -> Void) {
        do {
            let markdown = try MarkdownPreviewDecoder.string(contentsOf: url)
            installPreview(markdown: markdown)
            handler(nil)
        } catch {
            handler(error)
        }
    }

    private func installPreview(markdown: String) {
        children.forEach { child in
            child.view.removeFromSuperview()
            child.removeFromParent()
        }

        let hostingController = NSHostingController(rootView: MarkdownQuickLookView(markdown: markdown))
        addChild(hostingController)
        hostingController.view.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(hostingController.view)
        NSLayoutConstraint.activate([
            hostingController.view.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            hostingController.view.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            hostingController.view.topAnchor.constraint(equalTo: view.topAnchor),
            hostingController.view.bottomAnchor.constraint(equalTo: view.bottomAnchor),
        ])
    }
}

private struct MarkdownQuickLookView: View {
    @State private var markdown: String

    init(markdown: String) {
        _markdown = State(initialValue: markdown)
    }

    var body: some View {
        NativeTextViewWrapper(
            text: $markdown,
            configuration: {
                var configuration = MarkdownEditorConfiguration.default
                configuration.services.latex = SwiftMathBridge()
                configuration.services.syntaxHighlighter = SegnoSyntaxHighlighter()
                configuration.extensions = [HighlightExtension(), StrikethroughExtension()]
                configuration.textInsets = TextInsets(horizontal: 16, vertical: 16)
                configuration.headings.topSpacingEm = [0.30, 0.26, 0.22, 0.18, 0.14, 0.10]
                configuration.theme = MarkdownEditorTheme(
                    bodyText: .labelColor,
                    mutedText: .secondaryLabelColor,
                    headingMarker: .gray,
                    link: .linkColor,
                    findMatchHighlight: .systemYellow,
                    findCurrentMatchHighlight: .systemYellow,
                    strikethroughColor: .labelColor,
                    highlightColor: .systemOrange.withAlphaComponent(0.4)
                )
                configuration.codeBlock.fontSizeScale = 0.85
                configuration.codeBlock.paragraphSpacing = 2
                configuration.codeBlock.horizontalIndent = 12
                configuration.inlineCode.fontSizeScale = 0.85
                configuration.blockquote.extraLineHeight = 0
                configuration.lists.indentPerLevel = 27.5
                configuration.lists.extraLineHeight = 2
                configuration.paragraph.spacingFactor = 0.25
                configuration.paragraph.lineHeightExtraSpacing = 2
                return configuration
            }(),
            fontName: "SF Pro",
            fontSize: 16,
            documentId: "quicklook",
            isEditable: false
        )
        .background(Color(nsColor: .textBackgroundColor))
    }
}

private enum MarkdownPreviewDecoder {
    static func string(contentsOf url: URL) throws -> String {
        let data = try Data(contentsOf: url, options: .mappedIfSafe)

        if data.starts(with: [0x00, 0x00, 0xFE, 0xFF]) {
            return try decode(data.dropFirst(4), encoding: .utf32BigEndian)
        }
        if data.starts(with: [0xFF, 0xFE, 0x00, 0x00]) {
            return try decode(data.dropFirst(4), encoding: .utf32LittleEndian)
        }
        if data.starts(with: [0xEF, 0xBB, 0xBF]) {
            return try decode(data.dropFirst(3), encoding: .utf8)
        }
        if data.starts(with: [0xFE, 0xFF]) {
            return try decode(data.dropFirst(2), encoding: .utf16BigEndian)
        }
        if data.starts(with: [0xFF, 0xFE]) {
            return try decode(data.dropFirst(2), encoding: .utf16LittleEndian)
        }

        guard let text = String(data: data, encoding: .utf8) else {
            throw CocoaError(.fileReadInapplicableStringEncoding)
        }
        return text
    }

    private static func decode(_ bytes: Data.SubSequence, encoding: String.Encoding) throws -> String {
        guard let text = String(data: Data(bytes), encoding: encoding) else {
            throw CocoaError(.fileReadInapplicableStringEncoding)
        }
        return text
    }
}
