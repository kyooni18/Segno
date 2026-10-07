import AppKit
import Combine
import MarkdownEngine
import MarkdownEngineCodeBlocks
import MarkdownEngineLatex
import SwiftUI

struct MarkdownEditorAccessBridge: NSViewRepresentable {
    let access: MarkdownEditorAccess
    let onCodeBlocksChange: ([CodeBlockPresentation]) -> Void

    func makeNSView(context: Context) -> MarkdownEditorAccessBridgeView {
        access.onCodeBlocksChange = onCodeBlocksChange
        return MarkdownEditorAccessBridgeView(access: access)
    }

    func updateNSView(_ nsView: MarkdownEditorAccessBridgeView, context: Context) {
        access.onCodeBlocksChange = onCodeBlocksChange
        nsView.access = access
        nsView.scheduleResolve()
    }
}

@MainActor
final class MarkdownEditorAccessBridgeView: NSView {
    weak var access: MarkdownEditorAccess?
    private var resolveGeneration = 0

    init(access: MarkdownEditorAccess) {
        self.access = access
        super.init(frame: .zero)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        scheduleResolve()
    }

    func scheduleResolve() {
        resolveGeneration &+= 1
        resolve(generation: resolveGeneration, retriesRemaining: 8)
    }

    private func resolve(generation: Int, retriesRemaining: Int) {
        DispatchQueue.main.async { [weak self] in
            guard let self, self.resolveGeneration == generation else { return }

            if let editor = self.window?.contentView?.markdownEditorTextView {
                self.access?.textView = editor
                return
            }

            guard retriesRemaining > 0 else { return }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) { [weak self] in
                self?.resolve(generation: generation, retriesRemaining: retriesRemaining - 1)
            }
        }
    }
}

@MainActor
final class MarkdownEditorScrollOffsetStore {
    private var offsets: [String: CGFloat] = [:]

    func save(_ offset: CGFloat, for documentID: String) {
        offsets[documentID] = offset
    }

    func offset(for documentID: String) -> CGFloat? {
        offsets[documentID]
    }
}

/// Preserves a text anchor across window resizes after AppKit finishes reflowing.
struct MarkdownEditorScrollPositionBridge: NSViewRepresentable {
    let access: MarkdownEditorAccess

    func makeNSView(context: Context) -> MarkdownEditorScrollPositionBridgeView {
        MarkdownEditorScrollPositionBridgeView(access: access)
    }

    func updateNSView(_ nsView: MarkdownEditorScrollPositionBridgeView, context: Context) {
        nsView.access = access
    }
}

@MainActor
final class MarkdownEditorScrollPositionBridgeView: NSView {
    weak var access: MarkdownEditorAccess?
    private var resizeObservers: [NSObjectProtocol] = []
    private var pendingResizeAnchor: Int?

    init(access: MarkdownEditorAccess) {
        self.access = access
        super.init(frame: .zero)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        resizeObservers.forEach(NotificationCenter.default.removeObserver)
        resizeObservers.removeAll()
        guard let window else { return }

        resizeObservers.append(NotificationCenter.default.addObserver(
            forName: NSWindow.willStartLiveResizeNotification,
            object: window,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.pendingResizeAnchor = self?.access?.textView?.visibleMarkdownCharacterIndex
            }
        })
        resizeObservers.append(NotificationCenter.default.addObserver(
            forName: NSWindow.didEndLiveResizeNotification,
            object: window,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.restoreResizeAnchor()
            }
        })
    }

    deinit {
        resizeObservers.forEach(NotificationCenter.default.removeObserver)
    }

    private func restoreResizeAnchor() {
        guard let anchor = pendingResizeAnchor else { return }
        pendingResizeAnchor = nil
        DispatchQueue.main.async { [weak self] in
            guard let editor = self?.access?.textView,
                  anchor < (editor.string as NSString).length else { return }
            editor.scrollMarkdownRangeToVisible(NSRange(location: anchor, length: 0))
        }
    }
}

/// MarkdownEngine keeps a per-document undo stack. ReferenceFileDocument uses the
/// document undo manager to know when a reference-type document is dirty, so both
/// sides must observe the same UndoManager.
struct DocumentUndoManagerBridge: NSViewRepresentable {
    func makeNSView(context: Context) -> DocumentUndoManagerBridgeView {
        DocumentUndoManagerBridgeView()
    }

    func updateNSView(_ nsView: DocumentUndoManagerBridgeView, context: Context) {
        nsView.scheduleBridge()
    }
}

final class DocumentUndoManagerBridgeView: NSView {
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

extension NSTextView {
    var visibleMarkdownCharacterIndex: Int? {
        guard !string.isEmpty else { return nil }
        let visibleRect = visibleRect
        let index = characterIndexForInsertion(
            at: NSPoint(x: visibleRect.minX + 2, y: visibleRect.minY + 2)
        )
        return index < (string as NSString).length ? index : nil
    }

    func scrollMarkdownRangeToVisible(_ range: NSRange) {
        let text = string as NSString
        guard range.location != NSNotFound, NSMaxRange(range) <= text.length else { return }

        let target = NSRange(location: min(range.location, max(0, text.length - 1)), length: 0)

        guard
            let textLayoutManager,
            let scrollView = enclosingScrollView,
            let start = textLayoutManager.textContentManager?.location(
                textLayoutManager.documentRange.location,
                offsetBy: target.location
            )
        else {
            scrollRangeToVisible(target)
            return
        }

        if let end = textLayoutManager.textContentManager?.location(
            textLayoutManager.documentRange.location,
            offsetBy: min(target.location + 1, text.length)
        ), let settleRange = NSTextRange(location: textLayoutManager.documentRange.location, end: end) {
            textLayoutManager.ensureLayout(for: settleRange)
        }

        textLayoutManager.enumerateTextLayoutFragments(from: start, options: [.ensuresLayout]) { fragment in
            let clipView = scrollView.contentView
            var revealRect = fragment.layoutFragmentFrame

            if let segmentLocation = textLayoutManager.textContentManager?.location(
                textLayoutManager.documentRange.location,
                offsetBy: target.location
            ) {
                textLayoutManager.enumerateTextSegments(
                    in: NSTextRange(location: segmentLocation),
                    type: .standard,
                    options: []
                ) { _, segmentFrame, _, _ in
                    if segmentFrame.height > 0 {
                        revealRect = segmentFrame
                    }
                    return false
                }
            }

            let fragmentFrame = revealRect.offsetBy(dx: 0, dy: self.frame.origin.y)
            let targetY = fragmentFrame.minY - scrollView.contentInsets.top - 24
            clipView.scroll(to: NSPoint(x: clipView.bounds.origin.x, y: targetY))
            scrollView.reflectScrolledClipView(clipView)
            return false
        }
    }
}
