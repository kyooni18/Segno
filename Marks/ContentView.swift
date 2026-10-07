import AppKit
import Combine
import MarkdownEngine
import MarkdownEngineCodeBlocks
import MarkdownEngineLatex
import SwiftUI

struct ContentView: View {
    @ObservedObject var document: MarkdownDocument
    @StateObject private var styleServiceCache = MarkdownStyleServiceCache()
    @StateObject private var codeBlockPresentationModel = CodeBlockPresentationModel()
    @State private var editorAccess = MarkdownEditorAccess()
    @State private var editorScrollOffsets = MarkdownEditorScrollOffsetStore()
    @State private var documentMetrics: DocumentMetrics
    @State private var documentHeadings: [MarkdownOutline.Heading]
    @State private var restoredTableOfContentsWidth: CGFloat

    @State private var isSearchPresented = false
    @State private var searchText = ""
    @State private var replacementText = ""
    @State private var searchMatchCount = 0
    @State private var searchMatchIndex = 0
    @State private var searchFocusRequest = 0
    @AppStorage(SegnoPreferences.tableOfContentsPresentedKey)
    private var isTableOfContentsPresented = true

    @AppStorage(SegnoPreferences.readOnlyKey)
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
    private let fileURL: URL?

    init(document: MarkdownDocument, fileURL: URL? = nil) {
        self.document = document
        self.fileURL = fileURL
        documentID = String(describing: ObjectIdentifier(document))
        _documentMetrics = State(initialValue: DocumentMetrics(text: document.text))
        _documentHeadings = State(initialValue: MarkdownOutline.headings(in: document.text))
        _restoredTableOfContentsWidth = State(initialValue: TableOfContentsSidebarWidth.restoredWidth())
    }
    
    

    var body: some View {
        editorPane
        .onChange(of: searchText) { _, _ in
            searchMatchIndex = 0
            updateSearchHighlights()
        }
        .onChange(of: document.text) { _, newText in
            documentMetrics = DocumentMetrics(text: newText)
            documentHeadings = MarkdownOutline.headings(in: newText)
            guard isSearchPresented, !searchText.isEmpty else { return }
            updateSearchHighlights()
        }
        .onChange(of: isSearchPresented) { _, isPresented in
            if isPresented {
                searchFocusRequest &+= 1
                if !seedSearchFromSelectionIfAvailable(onlyWhenEmpty: true) {
                    updateSearchHighlights()
                }
            } else {
                clearSearchHighlights()
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: findResultsNotification)) { notification in
            guard let count = notification.userInfo?["count"] as? Int else { return }
            searchMatchCount = count
            searchMatchIndex = count == 0 ? 0 : min(searchMatchIndex, count - 1)
        }
        .focusedSceneValue(\.documentSearchPresented, $isSearchPresented)
        .focusedSceneValue(
            \.documentSearchCommandActions,
            DocumentSearchCommandActions(
                showFind: presentSearch,
                findNext: findNextFromCommand,
                findPrevious: findPreviousFromCommand
            )
        )
        .focusedSceneValue(\.tableOfContentsPresented, $isTableOfContentsPresented)
        .focusedSceneValue(\.documentFileURL, fileURL)
        .focusedSceneValue(\.editorFontSize, $fontSize)
        .inspector(isPresented: $isTableOfContentsPresented) {
            TableOfContentsInspector(headings: documentHeadings) { heading in
                navigateToHeading(heading)
            }
            .inspectorColumnWidth(
                min: TableOfContentsSidebarWidth.minimum,
                ideal: restoredTableOfContentsWidth,
                max: TableOfContentsSidebarWidth.maximum
            )
        }
        .background(WindowFrameRestorationBridge())
        .toolbar {
            ToolbarItemGroup() {
                HStack(spacing: -1) {
                    Picker("Read-Only Mode", selection: $isReadOnly) {
                        Image(systemName: "character.cursor.ibeam")
                            .tag(false)
                        Image(systemName: "book")
                            .tag(true)
                    }
                    .pickerStyle(.tabs)
                    .help(isReadOnly ? String(localized: "Read Mode") : String(localized: "Edit Mode"))
                    Divider()
                        .padding(.leading, 6)
                        .padding(.vertical, 2)
                    Button {
                        if isSearchPresented {
                            searchFocusRequest &+= 1
                        } else {
                            presentSearch()
                        }
                    } label: {
                        Image(systemName: "magnifyingglass")
                    }
                    .help("Find in Document")
                    .popover(isPresented: $isSearchPresented, arrowEdge: .top) {
                        DocumentSearchPopover(
                            text: $searchText,
                            replacement: $replacementText,
                            focusRequest: searchFocusRequest,
                            statusText: searchStatusText,
                            matchCount: searchMatchCount,
                            allowsReplacement: !isReadOnly,
                            canReplace: !isReadOnly && searchMatchCount > 0,
                            onPrevious: selectPreviousSearchMatch,
                            onNext: selectNextSearchMatch,
                            onReplace: replaceCurrentSearchMatch,
                            onReplaceAll: replaceAllSearchMatches,
                            onClose: { isSearchPresented = false }
                        )
                    }
                    Button {
                        isTableOfContentsPresented.toggle()
                    } label: {
                        Image(systemName: "sidebar.right")
                    }
                    .help(
                        isTableOfContentsPresented
                        ? String(localized: "Hide Table of Contents")
                        : String(localized: "Show Table of Contents")
                    )
                }
                .background(
                    Capsule()
                        .foregroundStyle(.background)
                        .shadow(color: .black.opacity(0.2), radius: 4, x: 0, y: 4)
                )
                .padding(.trailing, 4)
            }
            .sharedBackgroundVisibility(.hidden)
        }
        .safeAreaInset(edge: .bottom, spacing: 0) {
            DocumentStatusBar(fileURL: fileURL, metrics: documentMetrics)
        }
        .animation(.snappy(duration: 0.2), value: isTableOfContentsPresented)
    }

    private var editorPane: some View {
        NativeTextViewWrapper(
            text: $document.text,
            configuration: editorConfiguration,
            fontName: fontName,
            fontSize: CGFloat(fontSize),
            documentId: documentID,
            isEditable: !isReadOnly,
            onPersistScrollOffset: { id, offset in
                editorScrollOffsets.save(offset, for: id)
            },
            restoreScrollOffset: { id in
                editorScrollOffsets.offset(for: id)
            }
        )
        .overlay(alignment: .topLeading) {
            CodeBlockAccessoryOverlay(model: codeBlockPresentationModel)
                .zIndex(-4)
        }
        // The engine keeps parsed style state in the native editor. Recreate it
        // when persisted appearance or layout controls change so settings apply
        // immediately and consistently across all Markdown constructs.
        .id(editorStyleIdentity)
        .overlay {
            MarkdownEditorScrollPositionBridge(access: editorAccess)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .allowsHitTesting(false)
        }
        .frame(minWidth: 400, minHeight: 320)
        .background(Color(nsColor: .textBackgroundColor))
        .background {
            ZStack {
                DocumentUndoManagerBridge()
                MarkdownEditorAccessBridge(
                    access: editorAccess,
                    onCodeBlocksChange: { blocks in
                        if codeBlockPresentationModel.blocks != blocks {
                            codeBlockPresentationModel.blocks = blocks
                        }
                    }
                )
            }
            .frame(width: 0, height: 0)
        }
    }

    private func presentSearch() {
        _ = seedSearchFromSelectionIfAvailable(onlyWhenEmpty: false)
        if isSearchPresented {
            searchFocusRequest &+= 1
        } else {
            isSearchPresented = true
        }
    }

    private func findNextFromCommand() {
        guard isSearchPresented, !searchText.isEmpty else {
            presentSearch()
            return
        }
        selectNextSearchMatch()
    }

    private func findPreviousFromCommand() {
        guard isSearchPresented, !searchText.isEmpty else {
            presentSearch()
            return
        }
        selectPreviousSearchMatch()
    }

    @discardableResult
    private func seedSearchFromSelectionIfAvailable(onlyWhenEmpty: Bool) -> Bool {
        if onlyWhenEmpty, !searchText.isEmpty { return false }
        guard let editor = editorAccess.textView else { return false }

        let selectedRange = editor.selectedRange()
        let displayedText = editor.string as NSString
        guard selectedRange.length > 0, NSMaxRange(selectedRange) <= displayedText.length else { return false }

        let selectedText = displayedText.substring(with: selectedRange)
        guard selectedText.count <= 256,
              !selectedText.contains("\n"),
              !selectedText.contains("\r"),
              !selectedText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
              selectedText != searchText else { return false }

        searchText = selectedText
        return true
    }

    private var findQueryNotification: Notification.Name {
        Notification.Name("Segno.FindQuery.\(documentID)")
    }

    private var findResultsNotification: Notification.Name {
        Notification.Name("Segno.FindResults.\(documentID)")
    }

    private var findClearNotification: Notification.Name {
        Notification.Name("Segno.FindClear.\(documentID)")
    }

    private var replaceCurrentNotification: Notification.Name {
        Notification.Name("Segno.ReplaceCurrent.\(documentID)")
    }

    private var replaceAllNotification: Notification.Name {
        Notification.Name("Segno.ReplaceAll.\(documentID)")
    }

    private var searchStatusText: String {
        guard searchMatchCount > 0 else { return String(localized: "No Results") }
        return String.localizedStringWithFormat(
            String(localized: "%lld of %lld"),
            searchMatchIndex + 1,
            searchMatchCount
        )
    }

    private func updateSearchHighlights() {
        guard isSearchPresented, !searchText.isEmpty else {
            clearSearchHighlights()
            return
        }

        NotificationCenter.default.post(
            name: findQueryNotification,
            object: nil,
            userInfo: [
                "query": searchText,
                "currentIndex": searchMatchIndex,
            ]
        )
    }

    private func clearSearchHighlights() {
        searchMatchCount = 0
        searchMatchIndex = 0
        NotificationCenter.default.post(name: findClearNotification, object: nil)
    }

    private func selectNextSearchMatch() {
        guard searchMatchCount > 0 else { return }
        searchMatchIndex = (searchMatchIndex + 1) % searchMatchCount
        updateSearchHighlights()
    }

    private func selectPreviousSearchMatch() {
        guard searchMatchCount > 0 else { return }
        searchMatchIndex = (searchMatchIndex - 1 + searchMatchCount) % searchMatchCount
        updateSearchHighlights()
    }

    private func replaceCurrentSearchMatch() {
        guard !isReadOnly, searchMatchCount > 0, !searchText.isEmpty else { return }
        NotificationCenter.default.post(
            name: replaceCurrentNotification,
            object: nil,
            userInfo: [
                "query": searchText,
                "replacement": replacementText,
                "currentIndex": searchMatchIndex,
            ]
        )
    }

    private func replaceAllSearchMatches() {
        guard !isReadOnly, searchMatchCount > 0, !searchText.isEmpty else { return }
        searchMatchIndex = 0
        NotificationCenter.default.post(
            name: replaceAllNotification,
            object: nil,
            userInfo: [
                "query": searchText,
                "replacement": replacementText,
            ]
        )
    }

    private func navigateToHeading(_ heading: MarkdownOutline.Heading) {
        guard let editor = editorAccess.textView else { return }
        let displayedHeadings = MarkdownOutline.headings(in: editor.string)
        guard displayedHeadings.indices.contains(heading.id) else { return }
        editor.scrollMarkdownRangeToVisible(displayedHeadings[heading.id].range)
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
            horizontal: CGFloat(horizontalInset + outerPadding),
            vertical: CGFloat(verticalInset + outerPadding)
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
            lightBackground: resolvedCodeBlockLightBackground,
            darkBackground: resolvedCodeBlockDarkBackground
        )
        configuration.services.bus = MarkdownEditorBus(
            findClearHighlights: findClearNotification,
            findQuery: findQueryNotification,
            findResults: findResultsNotification,
            replaceCurrent: replaceCurrentNotification,
            replaceAll: replaceAllNotification
        )
        return configuration
    }

    private var resolvedCodeBlockLightBackground: NSColor {
        MarkdownStylePreferences.color(
            for: codeBlockLightBackground,
            fallback: NSColor(calibratedWhite: 0.95, alpha: 1)
        )
    }

    private var resolvedCodeBlockDarkBackground: NSColor {
        MarkdownStylePreferences.color(
            for: codeBlockDarkBackground,
            fallback: NSColor(calibratedWhite: 0.13, alpha: 1)
        )
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
        configuration.headings.topSpacingEm = [0.30, 0.26, 0.22, 0.18, 0.14, 0.10]
        configuration.services.latex = SwiftMathBridge()
        configuration.extensions = [HighlightExtension(), StrikethroughExtension()]
        return configuration
    }()


}

#Preview {
    ContentView(document: MarkdownDocument())
}
