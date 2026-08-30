import AppKit
import MarkdownEngine
import MarkdownEngineCodeBlocks
import MarkdownEngineLatex
import SwiftUI

private enum MarkdownStylePreferences {
    static let fontNameKey = "markdownStyle.fontName"
    static let fontSizeKey = "markdownStyle.fontSize"
    static let horizontalInsetKey = "markdownStyle.horizontalInset"
    static let verticalInsetKey = "markdownStyle.verticalInset"
    static let outerPaddingKey = "markdownStyle.outerPadding"
    static let bodyTextColorKey = "markdownStyle.bodyTextColor"
    static let mutedTextColorKey = "markdownStyle.mutedTextColor"
    static let headingMarkerColorKey = "markdownStyle.headingMarkerColor"
    static let linkColorKey = "markdownStyle.linkColor"
    static let highlightColorKey = "markdownStyle.highlightColor"
    static let findMatchHighlightColorKey = "markdownStyle.findMatchHighlightColor"
    static let findCurrentMatchHighlightColorKey = "markdownStyle.findCurrentMatchHighlightColor"
    static let strikethroughColorKey = "markdownStyle.strikethroughColor"
    static let codeFontNameKey = "markdownStyle.codeFontName"
    static let codeBlockFontScaleKey = "markdownStyle.codeBlockFontScale"
    static let codeBlockParagraphSpacingKey = "markdownStyle.codeBlockParagraphSpacing"
    static let codeBlockHorizontalIndentKey = "markdownStyle.codeBlockHorizontalIndent"
    static let codeBlockLightBackgroundKey = "markdownStyle.codeBlockLightBackground"
    static let codeBlockDarkBackgroundKey = "markdownStyle.codeBlockDarkBackground"
    static let inlineCodeFontScaleKey = "markdownStyle.inlineCodeFontScale"
    static let blockquoteExtraLineHeightKey = "markdownStyle.blockquoteExtraLineHeight"
    static let listIndentPerLevelKey = "markdownStyle.listIndentPerLevel"
    static let listExtraLineHeightKey = "markdownStyle.listExtraLineHeight"
    static let paragraphSpacingFactorKey = "markdownStyle.paragraphSpacingFactor"
    static let paragraphLineHeightExtraKey = "markdownStyle.paragraphLineHeightExtra"

    static let defaultFontName = "SF Pro"
    static let defaultFontSize = 16.0
    static let defaultHorizontalInset = 0.0
    static let defaultVerticalInset = 0.0
    static let defaultOuterPadding = 16.0
    static let defaultCodeFontName = "SF Mono"
    static let defaultCodeBlockFontScale = 0.85
    static let defaultCodeBlockParagraphSpacing = 2.0
    static let defaultCodeBlockHorizontalIndent = 12.0
    static let defaultInlineCodeFontScale = 0.85
    static let defaultBlockquoteExtraLineHeight = 0.0
    static let defaultListIndentPerLevel = 27.5
    static let defaultListExtraLineHeight = 2.0
    static let defaultParagraphSpacingFactor = 0.3
    static let defaultParagraphLineHeightExtra = 2.0

    static let availableFontNames: [String] = {
        var names = NSFontManager.shared.availableFonts.sorted {
            $0.localizedCaseInsensitiveCompare($1) == .orderedAscending
        }

        if !names.contains(defaultCodeFontName) {
            names.insert(defaultCodeFontName, at: 0)
        }
        if !names.contains(defaultFontName) {
            names.insert(defaultFontName, at: 0)
        }
        return names
    }()

    static func color(for storedValue: String, fallback: NSColor) -> NSColor {
        NSColor(hex: storedValue) ?? fallback
    }
}

private extension NSColor {
    convenience init?(hex: String) {
        let value = hex.trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "#", with: "")
        guard value.count == 6 || value.count == 8,
              let number = UInt64(value, radix: 16) else {
            return nil
        }

        let red = CGFloat((number >> (value.count == 8 ? 24 : 16)) & 0xFF) / 255
        let green = CGFloat((number >> (value.count == 8 ? 16 : 8)) & 0xFF) / 255
        let blue = CGFloat((number >> (value.count == 8 ? 8 : 0)) & 0xFF) / 255
        let alpha = value.count == 8 ? CGFloat(number & 0xFF) / 255 : 1
        self.init(calibratedRed: red, green: green, blue: blue, alpha: alpha)
    }

    var markdownHex: String {
        let color = usingColorSpace(.sRGB) ?? self
        let red = Int((color.redComponent * 255).rounded())
        let green = Int((color.greenComponent * 255).rounded())
        let blue = Int((color.blueComponent * 255).rounded())
        let alpha = Int((color.alphaComponent * 255).rounded())
        return String(format: "#%02X%02X%02X%02X", red, green, blue, alpha)
    }
}

struct ContentView: View {
    @ObservedObject var document: MarkdownDocument
    @StateObject private var styleServiceCache = MarkdownStyleServiceCache()

    @AppStorage(MarksPreferences.readOnlyKey)
    private var isReadOnly = false

    @AppStorage(MarkdownStylePreferences.fontNameKey)
    private var fontName = MarkdownStylePreferences.defaultFontName
    @AppStorage(MarkdownStylePreferences.fontSizeKey)
    private var fontSize = MarkdownStylePreferences.defaultFontSize
    @AppStorage(MarkdownStylePreferences.horizontalInsetKey)
    private var horizontalInset = MarkdownStylePreferences.defaultHorizontalInset
    @AppStorage(MarkdownStylePreferences.verticalInsetKey)
    private var verticalInset = MarkdownStylePreferences.defaultVerticalInset
    @AppStorage(MarkdownStylePreferences.outerPaddingKey)
    private var outerPadding = MarkdownStylePreferences.defaultOuterPadding
    @AppStorage(MarkdownStylePreferences.bodyTextColorKey)
    private var bodyTextColor = ""
    @AppStorage(MarkdownStylePreferences.mutedTextColorKey)
    private var mutedTextColor = ""
    @AppStorage(MarkdownStylePreferences.headingMarkerColorKey)
    private var headingMarkerColor = ""
    @AppStorage(MarkdownStylePreferences.linkColorKey)
    private var linkColor = ""
    @AppStorage(MarkdownStylePreferences.highlightColorKey)
    private var highlightColor = ""
    @AppStorage(MarkdownStylePreferences.findMatchHighlightColorKey)
    private var findMatchHighlightColor = ""
    @AppStorage(MarkdownStylePreferences.findCurrentMatchHighlightColorKey)
    private var findCurrentMatchHighlightColor = ""
    @AppStorage(MarkdownStylePreferences.strikethroughColorKey)
    private var strikethroughColor = ""
    @AppStorage(MarkdownStylePreferences.codeFontNameKey)
    private var codeFontName = MarkdownStylePreferences.defaultCodeFontName
    @AppStorage(MarkdownStylePreferences.codeBlockFontScaleKey)
    private var codeBlockFontScale = MarkdownStylePreferences.defaultCodeBlockFontScale
    @AppStorage(MarkdownStylePreferences.codeBlockParagraphSpacingKey)
    private var codeBlockParagraphSpacing = MarkdownStylePreferences.defaultCodeBlockParagraphSpacing
    @AppStorage(MarkdownStylePreferences.codeBlockHorizontalIndentKey)
    private var codeBlockHorizontalIndent = MarkdownStylePreferences.defaultCodeBlockHorizontalIndent
    @AppStorage(MarkdownStylePreferences.codeBlockLightBackgroundKey)
    private var codeBlockLightBackground = ""
    @AppStorage(MarkdownStylePreferences.codeBlockDarkBackgroundKey)
    private var codeBlockDarkBackground = ""
    @AppStorage(MarkdownStylePreferences.inlineCodeFontScaleKey)
    private var inlineCodeFontScale = MarkdownStylePreferences.defaultInlineCodeFontScale
    @AppStorage(MarkdownStylePreferences.blockquoteExtraLineHeightKey)
    private var blockquoteExtraLineHeight = MarkdownStylePreferences.defaultBlockquoteExtraLineHeight
    @AppStorage(MarkdownStylePreferences.listIndentPerLevelKey)
    private var listIndentPerLevel = MarkdownStylePreferences.defaultListIndentPerLevel
    @AppStorage(MarkdownStylePreferences.listExtraLineHeightKey)
    private var listExtraLineHeight = MarkdownStylePreferences.defaultListExtraLineHeight
    @AppStorage(MarkdownStylePreferences.paragraphSpacingFactorKey)
    private var paragraphSpacingFactor = MarkdownStylePreferences.defaultParagraphSpacingFactor
    @AppStorage(MarkdownStylePreferences.paragraphLineHeightExtraKey)
    private var paragraphLineHeightExtra = MarkdownStylePreferences.defaultParagraphLineHeightExtra

    private let documentID: String

    init(document: MarkdownDocument) {
        self.document = document
        documentID = String(describing: ObjectIdentifier(document))
    }
    
    

    var body: some View {
        NativeTextViewWrapper(
            text: $document.text,
            configuration: editorConfiguration,
            fontName: fontName,
            fontSize: CGFloat(fontSize),
            documentId: documentID,
            isEditable: !isReadOnly
        )
        // The engine keeps parsed style state in the native editor. Recreate it
        // when persisted appearance or layout controls change so settings apply
        // immediately and consistently across all Markdown constructs.
        .id(editorStyleIdentity)
        .frame(minWidth: 540, minHeight: 480)
        .background(Color(nsColor: .textBackgroundColor))
        .background {
            DocumentUndoManagerBridge()
                .frame(width: 0, height: 0)
        }
        .padding(CGFloat(outerPadding))
        .toolbar {
            ToolbarItem {
                Picker("Read-Only Mode", selection: $isReadOnly) {
                    Image(systemName: "character.cursor.ibeam")
                        .tag(false)
                    Image(systemName: "book")
                        .tag(true)
                }
                .pickerStyle(.tabs)
            }
        }
    }

    private var editorConfiguration: MarkdownEditorConfiguration {
        var configuration = Self.baseEditorConfiguration
        configuration.theme = MarkdownEditorTheme(
            bodyText: MarkdownStylePreferences.color(for: bodyTextColor, fallback: .labelColor),
            mutedText: MarkdownStylePreferences.color(for: mutedTextColor, fallback: .secondaryLabelColor),
            headingMarker: MarkdownStylePreferences.color(for: headingMarkerColor, fallback: .gray),
            link: MarkdownStylePreferences.color(for: linkColor, fallback: .linkColor),
            findMatchHighlight: MarkdownStylePreferences.color(for: findMatchHighlightColor, fallback: .systemYellow),
            findCurrentMatchHighlight: MarkdownStylePreferences.color(for: findCurrentMatchHighlightColor, fallback: .systemYellow),
            strikethroughColor: MarkdownStylePreferences.color(for: strikethroughColor, fallback: .labelColor),
            highlightColor: MarkdownStylePreferences.color(
                for: highlightColor,
                fallback: .systemOrange.withAlphaComponent(0.4)
            )
        )
        configuration.textInsets = TextInsets(
            horizontal: CGFloat(horizontalInset),
            vertical: CGFloat(verticalInset)
        )
        configuration.codeBlock.fontSizeScale = CGFloat(codeBlockFontScale)
        configuration.codeBlock.paragraphSpacing = CGFloat(codeBlockParagraphSpacing)
        configuration.codeBlock.horizontalIndent = CGFloat(codeBlockHorizontalIndent)
        configuration.inlineCode.fontSizeScale = CGFloat(inlineCodeFontScale)
        configuration.blockquote.extraLineHeight = CGFloat(blockquoteExtraLineHeight)
        configuration.lists.indentPerLevel = CGFloat(listIndentPerLevel)
        configuration.lists.extraLineHeight = CGFloat(listExtraLineHeight)
        configuration.paragraph.spacingFactor = CGFloat(paragraphSpacingFactor)
        configuration.paragraph.lineHeightExtraSpacing = CGFloat(paragraphLineHeightExtra)
        configuration.services.syntaxHighlighter = styleServiceCache.syntaxHighlighter(
            codeFontName: codeFontName,
            lightBackground: MarkdownStylePreferences.color(
                for: codeBlockLightBackground,
                fallback: NSColor(calibratedWhite: 0.95, alpha: 1)
            ),
            darkBackground: MarkdownStylePreferences.color(
                for: codeBlockDarkBackground,
                fallback: NSColor(calibratedWhite: 0.13, alpha: 1)
            )
        )
        return configuration
    }

    private var editorStyleIdentity: String {
        [
            bodyTextColor,
            mutedTextColor,
            headingMarkerColor,
            linkColor,
            highlightColor,
            findMatchHighlightColor,
            findCurrentMatchHighlightColor,
            strikethroughColor,
            codeFontName,
            String(codeBlockFontScale),
            String(codeBlockParagraphSpacing),
            String(codeBlockHorizontalIndent),
            codeBlockLightBackground,
            codeBlockDarkBackground,
            String(inlineCodeFontScale),
            String(blockquoteExtraLineHeight),
            String(listIndentPerLevel),
            String(listExtraLineHeight),
            String(paragraphSpacingFactor),
            String(paragraphLineHeightExtra),
        ].joined(separator: "|")
    }

    private static let baseEditorConfiguration: MarkdownEditorConfiguration = {
        var configuration = MarkdownEditorConfiguration.default
        configuration.services.latex = SwiftMathBridge()
        configuration.extensions = [HighlightExtension(), StrikethroughExtension()]
        return configuration
    }()


}

struct MarkdownStyleSettingsView: View {
    @AppStorage(MarkdownStylePreferences.fontNameKey)
    private var fontName = MarkdownStylePreferences.defaultFontName
    @AppStorage(MarkdownStylePreferences.fontSizeKey)
    private var fontSize = MarkdownStylePreferences.defaultFontSize
    @AppStorage(MarkdownStylePreferences.horizontalInsetKey)
    private var horizontalInset = MarkdownStylePreferences.defaultHorizontalInset
    @AppStorage(MarkdownStylePreferences.verticalInsetKey)
    private var verticalInset = MarkdownStylePreferences.defaultVerticalInset
    @AppStorage(MarkdownStylePreferences.outerPaddingKey)
    private var outerPadding = MarkdownStylePreferences.defaultOuterPadding
    @AppStorage(MarkdownStylePreferences.bodyTextColorKey)
    private var bodyTextColor = ""
    @AppStorage(MarkdownStylePreferences.mutedTextColorKey)
    private var mutedTextColor = ""
    @AppStorage(MarkdownStylePreferences.headingMarkerColorKey)
    private var headingMarkerColor = ""
    @AppStorage(MarkdownStylePreferences.linkColorKey)
    private var linkColor = ""
    @AppStorage(MarkdownStylePreferences.highlightColorKey)
    private var highlightColor = ""
    @AppStorage(MarkdownStylePreferences.findMatchHighlightColorKey)
    private var findMatchHighlightColor = ""
    @AppStorage(MarkdownStylePreferences.findCurrentMatchHighlightColorKey)
    private var findCurrentMatchHighlightColor = ""
    @AppStorage(MarkdownStylePreferences.strikethroughColorKey)
    private var strikethroughColor = ""
    @AppStorage(MarkdownStylePreferences.codeFontNameKey)
    private var codeFontName = MarkdownStylePreferences.defaultCodeFontName
    @AppStorage(MarkdownStylePreferences.codeBlockFontScaleKey)
    private var codeBlockFontScale = MarkdownStylePreferences.defaultCodeBlockFontScale
    @AppStorage(MarkdownStylePreferences.codeBlockParagraphSpacingKey)
    private var codeBlockParagraphSpacing = MarkdownStylePreferences.defaultCodeBlockParagraphSpacing
    @AppStorage(MarkdownStylePreferences.codeBlockHorizontalIndentKey)
    private var codeBlockHorizontalIndent = MarkdownStylePreferences.defaultCodeBlockHorizontalIndent
    @AppStorage(MarkdownStylePreferences.codeBlockLightBackgroundKey)
    private var codeBlockLightBackground = ""
    @AppStorage(MarkdownStylePreferences.codeBlockDarkBackgroundKey)
    private var codeBlockDarkBackground = ""
    @AppStorage(MarkdownStylePreferences.inlineCodeFontScaleKey)
    private var inlineCodeFontScale = MarkdownStylePreferences.defaultInlineCodeFontScale
    @AppStorage(MarkdownStylePreferences.blockquoteExtraLineHeightKey)
    private var blockquoteExtraLineHeight = MarkdownStylePreferences.defaultBlockquoteExtraLineHeight
    @AppStorage(MarkdownStylePreferences.listIndentPerLevelKey)
    private var listIndentPerLevel = MarkdownStylePreferences.defaultListIndentPerLevel
    @AppStorage(MarkdownStylePreferences.listExtraLineHeightKey)
    private var listExtraLineHeight = MarkdownStylePreferences.defaultListExtraLineHeight
    @AppStorage(MarkdownStylePreferences.paragraphSpacingFactorKey)
    private var paragraphSpacingFactor = MarkdownStylePreferences.defaultParagraphSpacingFactor
    @AppStorage(MarkdownStylePreferences.paragraphLineHeightExtraKey)
    private var paragraphLineHeightExtra = MarkdownStylePreferences.defaultParagraphLineHeightExtra

    var body: some View {
        Form {
            Section("Typography") {
                Picker("Font", selection: $fontName) {
                    ForEach(MarkdownStylePreferences.availableFontNames, id: \.self) { name in
                        Text(name).tag(name)
                    }
                }
                .pickerStyle(.menu)

                styleSlider(
                    title: "Font Size",
                    value: $fontSize,
                    range: 12...32,
                    step: 1,
                    suffix: "pt"
                )
            }

            Section("Spacing") {
                styleSlider(
                    title: "Horizontal Inset",
                    value: $horizontalInset,
                    range: 0...80,
                    step: 2,
                    suffix: "pt"
                )

                styleSlider(
                    title: "Vertical Inset",
                    value: $verticalInset,
                    range: 0...60,
                    step: 2,
                    suffix: "pt"
                )

                styleSlider(
                    title: "Window Padding",
                    value: $outerPadding,
                    range: 0...40,
                    step: 2,
                    suffix: "pt"
                )
            }

            Section("Code") {
                Picker("Code Font", selection: $codeFontName) {
                    ForEach(MarkdownStylePreferences.availableFontNames, id: \.self) { name in
                        Text(name).tag(name)
                    }
                }
                .pickerStyle(.menu)

                styleDecimalSlider(
                    title: "Block Font Scale",
                    value: $codeBlockFontScale,
                    range: 0.65...1.20,
                    step: 0.05,
                    suffix: "x",
                    precision: 2
                )

                styleDecimalSlider(
                    title: "Inline Code Scale",
                    value: $inlineCodeFontScale,
                    range: 0.65...1.20,
                    step: 0.05,
                    suffix: "x",
                    precision: 2
                )

                styleSlider(
                    title: "Block Indent",
                    value: $codeBlockHorizontalIndent,
                    range: 0...40,
                    step: 1,
                    suffix: "pt"
                )

                styleSlider(
                    title: "Block Spacing",
                    value: $codeBlockParagraphSpacing,
                    range: 0...24,
                    step: 1,
                    suffix: "pt"
                )

                markdownColorPicker(
                    "Light Background",
                    value: $codeBlockLightBackground,
                    fallback: NSColor(calibratedWhite: 0.95, alpha: 1)
                )
                markdownColorPicker(
                    "Dark Background",
                    value: $codeBlockDarkBackground,
                    fallback: NSColor(calibratedWhite: 0.13, alpha: 1)
                )
            }

            Section("Blockquotes and Paragraphs") {
                styleDecimalSlider(
                    title: "Quote Line Spacing",
                    value: $blockquoteExtraLineHeight,
                    range: 0...12,
                    step: 0.5,
                    suffix: "pt",
                    precision: 1
                )

                styleDecimalSlider(
                    title: "Paragraph Spacing",
                    value: $paragraphSpacingFactor,
                    range: 0...1,
                    step: 0.05,
                    suffix: "x",
                    precision: 2
                )

                styleDecimalSlider(
                    title: "Line Spacing",
                    value: $paragraphLineHeightExtra,
                    range: 0...12,
                    step: 0.5,
                    suffix: "pt",
                    precision: 1
                )
            }

            Section("Lists") {
                styleDecimalSlider(
                    title: "Indent Per Level",
                    value: $listIndentPerLevel,
                    range: 16...48,
                    step: 0.5,
                    suffix: "pt",
                    precision: 1
                )

                styleDecimalSlider(
                    title: "Line Spacing",
                    value: $listExtraLineHeight,
                    range: 0...12,
                    step: 0.5,
                    suffix: "pt",
                    precision: 1
                )
            }

            Section("Markdown Colors") {
                markdownColorPicker("Body Text", value: $bodyTextColor, fallback: .labelColor)
                markdownColorPicker("Muted / Quote Text", value: $mutedTextColor, fallback: .secondaryLabelColor)
                markdownColorPicker("Heading Markers", value: $headingMarkerColor, fallback: .gray)
                markdownColorPicker("Links", value: $linkColor, fallback: .linkColor)
                markdownColorPicker(
                    "Inline Highlight",
                    value: $highlightColor,
                    fallback: .systemOrange.withAlphaComponent(0.4)
                )
                markdownColorPicker(
                    "Search Matches",
                    value: $findMatchHighlightColor,
                    fallback: .systemYellow
                )
                markdownColorPicker(
                    "Current Match",
                    value: $findCurrentMatchHighlightColor,
                    fallback: .systemYellow
                )
                markdownColorPicker("Strikethrough", value: $strikethroughColor, fallback: .labelColor)
            }

            HStack {
                Spacer()
                Button("Restore Defaults") {
                    restoreDefaults()
                }
            }
        }
        .formStyle(.grouped)
        .padding(20)
        .frame(width: 520, height: 700)
    }

    @ViewBuilder
    private func styleSlider(
        title: LocalizedStringKey,
        value: Binding<Double>,
        range: ClosedRange<Double>,
        step: Double,
        suffix: String
    ) -> some View {
        HStack(spacing: 12) {
            Text(title)
                .frame(width: 150, alignment: .leading)
            Slider(value: value, in: range, step: step)
            Text("\(Int(value.wrappedValue)) \(suffix)")
                .monospacedDigit()
                .frame(width: 62, alignment: .trailing)
        }
    }

    @ViewBuilder
    private func styleDecimalSlider(
        title: LocalizedStringKey,
        value: Binding<Double>,
        range: ClosedRange<Double>,
        step: Double,
        suffix: String,
        precision: Int
    ) -> some View {
        HStack(spacing: 12) {
            Text(title)
                .frame(width: 150, alignment: .leading)
            Slider(value: value, in: range, step: step)
            Text(String(format: "%.*f %@", precision, value.wrappedValue, suffix))
                .monospacedDigit()
                .frame(width: 70, alignment: .trailing)
        }
    }

    private func restoreDefaults() {
        fontName = MarkdownStylePreferences.defaultFontName
        fontSize = MarkdownStylePreferences.defaultFontSize
        horizontalInset = MarkdownStylePreferences.defaultHorizontalInset
        verticalInset = MarkdownStylePreferences.defaultVerticalInset
        outerPadding = MarkdownStylePreferences.defaultOuterPadding
        bodyTextColor = ""
        mutedTextColor = ""
        headingMarkerColor = ""
        linkColor = ""
        highlightColor = ""
        findMatchHighlightColor = ""
        findCurrentMatchHighlightColor = ""
        strikethroughColor = ""
        codeFontName = MarkdownStylePreferences.defaultCodeFontName
        codeBlockFontScale = MarkdownStylePreferences.defaultCodeBlockFontScale
        codeBlockParagraphSpacing = MarkdownStylePreferences.defaultCodeBlockParagraphSpacing
        codeBlockHorizontalIndent = MarkdownStylePreferences.defaultCodeBlockHorizontalIndent
        codeBlockLightBackground = ""
        codeBlockDarkBackground = ""
        inlineCodeFontScale = MarkdownStylePreferences.defaultInlineCodeFontScale
        blockquoteExtraLineHeight = MarkdownStylePreferences.defaultBlockquoteExtraLineHeight
        listIndentPerLevel = MarkdownStylePreferences.defaultListIndentPerLevel
        listExtraLineHeight = MarkdownStylePreferences.defaultListExtraLineHeight
        paragraphSpacingFactor = MarkdownStylePreferences.defaultParagraphSpacingFactor
        paragraphLineHeightExtra = MarkdownStylePreferences.defaultParagraphLineHeightExtra
    }

    private func markdownColorPicker(
        _ title: LocalizedStringKey,
        value: Binding<String>,
        fallback: NSColor
    ) -> some View {
        ColorPicker(
            title,
            selection: Binding(
                get: {
                    Color(nsColor: MarkdownStylePreferences.color(for: value.wrappedValue, fallback: fallback))
                },
                set: { newColor in
                    value.wrappedValue = (NSColor(newColor).usingColorSpace(.sRGB) ?? NSColor(newColor)).markdownHex
                }
            ),
            supportsOpacity: true
        )
    }
}

/// MarkdownEngine keeps a per-document undo stack. ReferenceFileDocument uses the
/// document undo manager to know when a reference-type document is dirty, so both
/// sides must observe the same UndoManager.
private struct DocumentUndoManagerBridge: NSViewRepresentable {
    func makeNSView(context: Context) -> DocumentUndoManagerBridgeView {
        DocumentUndoManagerBridgeView()
    }

    func updateNSView(_ nsView: DocumentUndoManagerBridgeView, context: Context) {
        nsView.scheduleBridge()
    }
}

private final class DocumentUndoManagerBridgeView: NSView {
    private var bridgeGeneration = 0

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        scheduleBridge()
    }

    func scheduleBridge() {
        bridgeGeneration &+= 1
        let generation = bridgeGeneration
        bridge(generation: generation, retriesRemaining: 6)
    }

    private func bridge(generation: Int, retriesRemaining: Int) {
        DispatchQueue.main.async { [weak self] in
            guard let self, self.bridgeGeneration == generation else { return }

            if self.installUndoManagerBridge() {
                return
            }

            guard retriesRemaining > 0 else { return }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) { [weak self] in
                guard let self, self.bridgeGeneration == generation else { return }
                self.bridge(generation: generation, retriesRemaining: retriesRemaining - 1)
            }
        }
    }

    private func installUndoManagerBridge() -> Bool {
        guard
            let window,
            let document = window.windowController?.document as? NSDocument,
            let contentView = window.contentView
        else {
            return false
        }

        guard
            let editor = contentView.markdownEditorTextView,
            let coordinator = editor.delegate as? NativeTextViewCoordinator,
            let editorUndoManager = coordinator.undoManager(for: editor)
        else {
            return false
        }

        if document.undoManager !== editorUndoManager {
            document.undoManager = editorUndoManager
        }
        return true
    }
}

private extension NSView {
    var markdownEditorTextView: NSTextView? {
        if let textView = self as? NSTextView,
           textView.delegate is NativeTextViewCoordinator {
            return textView
        }

        for subview in subviews {
            if let textView = subview.markdownEditorTextView {
                return textView
            }
        }
        return nil
    }
}

#Preview {
    ContentView(document: MarkdownDocument())
}
