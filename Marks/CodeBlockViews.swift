import AppKit
import Combine
import MarkdownEngine
import MarkdownEngineCodeBlocks
import MarkdownEngineLatex
import SwiftUI

struct CodeBlockPresentation: Identifiable, Equatable {
    let id: Int
    let rect: CGRect
    let headerRect: CGRect
    let language: String?
    let code: String
    let isActive: Bool
}

@MainActor
final class CodeBlockPresentationModel: ObservableObject {
    @Published var blocks: [CodeBlockPresentation] = []
}

@MainActor
final class MarkdownEditorAccess {
    private let codeBlockPresentation = CodeBlockPresentationController()

    var onCodeBlocksChange: (([CodeBlockPresentation]) -> Void)? {
        didSet {
            codeBlockPresentation.onCodeBlocksChange = onCodeBlocksChange
        }
    }

    weak var textView: NSTextView? {
        didSet {
            guard oldValue !== textView else { return }
            codeBlockPresentation.attach(to: textView)
        }
    }
}

struct CodeBlockAccessoryOverlay: View {
    @ObservedObject var model: CodeBlockPresentationModel

    @State private var copiedBlockID: Int?
    @State private var hoveredBlockID: Int?

    private let cornerRadius: CGFloat = 9

    var body: some View {
        ZStack(alignment: .topLeading) {
            ForEach(model.blocks) { block in
                blockChrome(for: block)
                    .allowsHitTesting(false)

                copyButton(for: block)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    @ViewBuilder
    private func blockChrome(for block: CodeBlockPresentation) -> some View {
        let headerHeight = max(1, block.headerRect.maxY - block.rect.minY)

        ZStack(alignment: .topLeading) {
            CodeBlockCornerCutout(radius: cornerRadius)
                .fill(
                    Color(nsColor: .textBackgroundColor),
                    style: FillStyle(eoFill: true)
                )

            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .strokeBorder(Color.primary.opacity(0.12), lineWidth: 1)

            Rectangle()
                .fill(Color.primary.opacity(0.025))
                .frame(height: headerHeight)

            Rectangle()
                .fill(Color.primary.opacity(0.09))
                .frame(height: 1)
                .offset(y: headerHeight - 1)

            if !block.isActive {
                Text(Self.displayName(for: block.language))
                    .font(.system(size: 11, weight: .semibold, design: .monospaced))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .padding(.leading, 12)
                    .frame(
                        width: max(0, block.rect.width - 64),
                        height: headerHeight,
                        alignment: .leading
                    )
            }
        }
        .frame(
            width: max(0, block.rect.width),
            height: max(0, block.rect.height)
        )
        .position(x: block.rect.midX, y: block.rect.midY)
    }

    private func copyButton(for block: CodeBlockPresentation) -> some View {
        let copied = copiedBlockID == block.id

        return Button {
            let pasteboard = NSPasteboard.general
            pasteboard.clearContents()
            pasteboard.setString(block.code, forType: .string)

            withAnimation(.easeOut(duration: 0.12)) {
                copiedBlockID = block.id
            }

            DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
                guard copiedBlockID == block.id else { return }
                withAnimation(.easeOut(duration: 0.12)) {
                    copiedBlockID = nil
                }
            }
        } label: {
            Image(systemName: copied ? "checkmark" : "doc.on.doc")
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(copied ? Color.accentColor : Color.secondary)
                .frame(width: 24, height: 22)
                .background(
                    Color.primary.opacity(copied ? 0.1 : (hoveredBlockID == block.id ? 0.08 : 0)),
                    in: RoundedRectangle(cornerRadius: 5, style: .continuous)
                )
        }
        .buttonStyle(.plain)
        .contentShape(RoundedRectangle(cornerRadius: 5, style: .continuous))
        .onHover { isHovered in
            hoveredBlockID = isHovered ? block.id : nil
        }
        .accessibilityLabel(copied ? "Copied" : "Copy Code")
        .help(copied ? "Copied" : "Copy Code")
        .position(
            x: block.rect.maxX - 24,
            y: block.headerRect.midY
        )
    }

    private static func displayName(for language: String?) -> String {
        guard let language else { return String(localized: "Code") }

        let normalized = language
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()

        guard !normalized.isEmpty else { return String(localized: "Code") }

        let names: [String: String] = [
            "bash": "Shell",
            "c#": "C#",
            "c++": "C++",
            "cpp": "C++",
            "csharp": "C#",
            "css": "CSS",
            "html": "HTML",
            "javascript": "JavaScript",
            "js": "JavaScript",
            "json": "JSON",
            "jsx": "JSX",
            "markdown": "Markdown",
            "md": "Markdown",
            "objective-c": "Objective-C",
            "objectivec": "Objective-C",
            "none": "Plain Text",
            "plain": "Plain Text",
            "plaintext": "Plain Text",
            "python": "Python",
            "py": "Python",
            "rust": "Rust",
            "rs": "Rust",
            "sh": "Shell",
            "shell": "Shell",
            "swift": "Swift",
            "text": "Plain Text",
            "ts": "TypeScript",
            "tsx": "TSX",
            "typescript": "TypeScript",
            "xml": "XML",
            "yaml": "YAML",
            "yml": "YAML",
            "zsh": "Shell",
        ]

        guard let name = names[normalized] else { return language }
        return String(localized: String.LocalizationValue(name))
    }
}

private struct CodeBlockCornerCutout: Shape {
    let radius: CGFloat

    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.addRect(rect)
        path.addRoundedRect(
            in: rect,
            cornerSize: CGSize(width: radius, height: radius)
        )
        return path
    }
}

@MainActor
private final class CodeBlockPresentationController: NSObject {
    var onCodeBlocksChange: (([CodeBlockPresentation]) -> Void)?

    private weak var textView: NSTextView?
    private var parsedBlocks: [ParsedCodeBlock] = []
    private var lastPresentations: [CodeBlockPresentation] = []
    private var refreshScheduled = false
    private var needsReparse = true

    func attach(to textView: NSTextView?) {
        NotificationCenter.default.removeObserver(self)
        self.textView = textView
        parsedBlocks = []
        lastPresentations = []
        onCodeBlocksChange?([])

        guard let textView else {
            return
        }

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(textDidChange(_:)),
            name: NSText.didChangeNotification,
            object: textView
        )
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(geometryDidChange(_:)),
            name: NSTextView.didChangeSelectionNotification,
            object: textView
        )

        textView.postsFrameChangedNotifications = true
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(geometryDidChange(_:)),
            name: NSView.frameDidChangeNotification,
            object: textView
        )

        if let clipView = textView.enclosingScrollView?.contentView {
            clipView.postsBoundsChangedNotifications = true
            NotificationCenter.default.addObserver(
                self,
                selector: #selector(geometryDidChange(_:)),
                name: NSView.boundsDidChangeNotification,
                object: clipView
            )
        }

        scheduleRefresh(reparse: true)
    }

    @objc
    private func textDidChange(_ notification: Notification) {
        scheduleRefresh(reparse: true)
    }

    @objc
    private func geometryDidChange(_ notification: Notification) {
        scheduleRefresh(reparse: false)
    }

    private func scheduleRefresh(reparse: Bool) {
        needsReparse = needsReparse || reparse
        guard !refreshScheduled else { return }
        refreshScheduled = true

        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            self.refreshScheduled = false
            let shouldReparse = self.needsReparse
            self.needsReparse = false
            self.refresh(reparse: shouldReparse)
        }
    }

    private func refresh(reparse: Bool) {
        guard let textView,
              let textLayoutManager = textView.textLayoutManager else {
            publish([])
            return
        }

        let nsText = textView.string as NSString
        if reparse {
            parsedBlocks = Self.codeBlocks(in: nsText)
        }
        guard !parsedBlocks.isEmpty else {
            publish([])
            return
        }
        guard let viewportRange = Self.viewportCharacterRange(
            from: textLayoutManager,
            textLength: nsText.length
        ) else { return }

        let viewportEnd = NSMaxRange(viewportRange)
        var lowerBound = 0
        var upperBound = parsedBlocks.count
        while lowerBound < upperBound {
            let middle = lowerBound + (upperBound - lowerBound) / 2
            if NSMaxRange(parsedBlocks[middle].range) < viewportRange.location {
                lowerBound = middle + 1
            } else {
                upperBound = middle
            }
        }

        let visibleBlocks = parsedBlocks.dropFirst(lowerBound).prefix {
            $0.range.location <= viewportEnd
        }
        let selection = textView.selectedRange()
        let presentations = visibleBlocks.compactMap { block -> CodeBlockPresentation? in
            guard NSMaxRange(block.range) <= nsText.length,
                  NSMaxRange(block.contentRange) <= nsText.length,
                  let rect = Self.viewRect(for: block.range, in: textView),
                  let headerRect = Self.viewRect(for: block.openingLine, in: textView) else {
                return nil
            }

            return CodeBlockPresentation(
                id: block.id,
                rect: rect,
                headerRect: headerRect,
                language: block.language,
                code: nsText.substring(with: block.contentRange),
                isActive: Self.isSelection(selection, inside: block.range)
            )
        }
        publish(presentations)
    }

    private func publish(_ presentations: [CodeBlockPresentation]) {
        guard presentations != lastPresentations else { return }
        lastPresentations = presentations
        onCodeBlocksChange?(presentations)
    }

    private static func viewportCharacterRange(
        from textLayoutManager: NSTextLayoutManager,
        textLength: Int
    ) -> NSRange? {
        guard let viewport = textLayoutManager.textViewportLayoutController.viewportRange else {
            return nil
        }

        let documentRange = textLayoutManager.documentRange
        let start = textLayoutManager.offset(from: documentRange.location, to: viewport.location)
        let length = textLayoutManager.offset(from: viewport.location, to: viewport.endLocation)
        guard start >= 0, length >= 0, start <= textLength else { return nil }
        return NSRange(location: start, length: min(length, textLength - start))
    }

    private static func isSelection(_ selection: NSRange, inside range: NSRange) -> Bool {
        guard selection.location != NSNotFound else { return false }
        if selection.length == 0 {
            return selection.location >= range.location && selection.location <= NSMaxRange(range)
        }
        return NSIntersectionRange(selection, range).length > 0
    }

    private struct ParsedCodeBlock {
        let id: Int
        let range: NSRange
        let openingLine: NSRange
        let contentRange: NSRange
        let language: String?
    }

    private struct Fence {
        let character: unichar
        let count: Int
        let info: String
    }

    private static func codeBlocks(in text: NSString) -> [ParsedCodeBlock] {
        guard text.length >= 3 else { return [] }
        var blocks: [ParsedCodeBlock] = []
        var opening: (line: NSRange, fence: Fence)?
        var lineStart = 0

        while lineStart < text.length {
            let lineRange = text.lineRange(for: NSRange(location: lineStart, length: 0))
            if let fence = fence(in: lineRange, text: text) {
                if let current = opening {
                    let isClosingFence = fence.character == current.fence.character &&
                        fence.count >= current.fence.count && fence.info.isEmpty
                    if isClosingFence {
                        let contentStart = NSMaxRange(current.line)
                        let contentLength = max(0, lineRange.location - contentStart)
                        blocks.append(
                            ParsedCodeBlock(
                                id: current.line.location,
                                range: NSRange(
                                    location: current.line.location,
                                    length: NSMaxRange(lineRange) - current.line.location
                                ),
                                openingLine: current.line,
                                contentRange: NSRange(location: contentStart, length: contentLength),
                                language: current.fence.info.isEmpty ? nil : current.fence.info
                            )
                        )
                        opening = nil
                    }
                } else {
                    opening = (lineRange, fence)
                }
            }

            let nextLine = NSMaxRange(lineRange)
            guard nextLine > lineStart else { break }
            lineStart = nextLine
        }
        return blocks
    }

    private static func fence(in lineRange: NSRange, text: NSString) -> Fence? {
        var contentEnd = NSMaxRange(lineRange)
        while contentEnd > lineRange.location {
            let character = text.character(at: contentEnd - 1)
            guard character == 0x0A || character == 0x0D else { break }
            contentEnd -= 1
        }

        var cursor = lineRange.location
        var indentation = 0
        while cursor < contentEnd, indentation < 3, text.character(at: cursor) == 0x20 {
            cursor += 1
            indentation += 1
        }
        guard cursor < contentEnd else { return nil }

        let marker = text.character(at: cursor)
        guard marker == 0x60 || marker == 0x7E else { return nil }
        let markerStart = cursor
        while cursor < contentEnd, text.character(at: cursor) == marker {
            cursor += 1
        }
        let count = cursor - markerStart
        guard count >= 3 else { return nil }

        let info = text.substring(with: NSRange(location: cursor, length: contentEnd - cursor))
            .trimmingCharacters(in: .whitespacesAndNewlines)
        return Fence(character: marker, count: count, info: info)
    }

    private static func viewRect(for range: NSRange, in textView: NSTextView) -> CGRect? {
        guard let textLayoutManager = textView.textLayoutManager,
              let textContainer = textView.textContainer,
              let contentStorage = textLayoutManager.textContentManager as? NSTextContentStorage,
              let start = contentStorage.location(
                contentStorage.documentRange.location,
                offsetBy: range.location
              ),
              let end = contentStorage.location(start, offsetBy: range.length),
              let textRange = NSTextRange(location: start, end: end) else {
            return nil
        }

        textLayoutManager.ensureLayout(for: textRange)
        var rect = CGRect.null
        textLayoutManager.enumerateTextSegments(in: textRange, type: .standard, options: []) {
            _, segmentRect, _, _ in
            rect = rect.isNull ? segmentRect : rect.union(segmentRect)
            return true
        }
        guard !rect.isNull else { return nil }

        let scrollOffset = textView.enclosingScrollView?.contentView.bounds.origin ?? .zero
        rect.origin.x = textView.frame.origin.x + textView.textContainerOrigin.x - scrollOffset.x
        rect.origin.y += textView.textContainerOrigin.y - scrollOffset.y
        rect.size.width = textContainer.containerSize.width

        let scale = max(textView.window?.backingScaleFactor ?? 2, 1)
        rect.origin.x = floor(rect.origin.x * scale) / scale
        rect.origin.y = floor(rect.origin.y * scale) / scale
        rect.size.width = ceil(rect.size.width * scale) / scale
        rect.size.height = ceil(rect.size.height * scale) / scale
        return rect
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }
}
