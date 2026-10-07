import AppKit
import Combine
import MarkdownEngine
import MarkdownEngineCodeBlocks
import MarkdownEngineLatex
import SwiftUI

struct DocumentSearchPopover: View {
    @Binding var text: String
    @Binding var replacement: String
    let focusRequest: Int
    let statusText: String
    let matchCount: Int
    let allowsReplacement: Bool
    let canReplace: Bool
    let onPrevious: () -> Void
    let onNext: () -> Void
    let onReplace: () -> Void
    let onReplaceAll: () -> Void
    let onClose: () -> Void

    @State private var isReplacePresented = false
    @FocusState private var searchFieldFocused: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 7) {
                Button {
                    withAnimation(.snappy(duration: 0.16)) {
                        isReplacePresented.toggle()
                    }
                } label: {
                    Image(systemName: isReplacePresented ? "chevron.down" : "chevron.right")
                        .font(.caption.weight(.semibold))
                        .frame(width: 18, height: 22)
                }
                .buttonStyle(.plain)
                .foregroundStyle(.secondary)
                .help(
                    isReplacePresented
                        ? String(localized: "Hide Replace")
                        : String(localized: "Show Replace")
                )
                .disabled(!allowsReplacement)

                Image(systemName: "magnifyingglass")
                    .foregroundStyle(.secondary)

                TextField("Search Document", text: $text)
                    .textFieldStyle(.plain)
                    .focused($searchFieldFocused)
                    .onSubmit(onNext)

                if !text.isEmpty {
                    Text(statusText)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .monospacedDigit()
                        .lineLimit(1)
                        .padding(.horizontal, 7)
                        .padding(.vertical, 3)
                        .background(.quaternary, in: Capsule())

                    Button {
                        text = ""
                        searchFieldFocused = true
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(.tertiary)
                    }
                    .buttonStyle(.plain)
                    .help("Clear Search")
                }

                HStack(spacing: 0) {
                    Button(action: onPrevious) {
                        Image(systemName: "chevron.up")
                            .frame(width: 25, height: 23)
                    }
                    .help("Previous Match")
                    .disabled(matchCount == 0)

                    Divider()
                        .frame(height: 14)

                    Button(action: onNext) {
                        Image(systemName: "chevron.down")
                            .frame(width: 25, height: 23)
                    }
                    .help("Next Match")
                    .disabled(matchCount == 0)
                }
                .buttonStyle(.plain)
                .background(.quaternary, in: RoundedRectangle(cornerRadius: 7, style: .continuous))

                Button(action: onClose) {
                    Image(systemName: "xmark")
                        .frame(width: 20, height: 20)
                }
                .buttonStyle(.plain)
                .foregroundStyle(.secondary)
                .help("Close Search")
                .keyboardShortcut(.cancelAction)
            }
            .padding(.horizontal, 9)
            .frame(height: 34)
            .background(.quinary, in: RoundedRectangle(cornerRadius: 9, style: .continuous))

            if isReplacePresented, allowsReplacement {
                HStack(spacing: 8) {
                    Image(systemName: "arrow.turn.down.right")
                        .foregroundStyle(.secondary)
                        .frame(width: 18)

                    TextField("Replace With", text: $replacement)
                        .textFieldStyle(.roundedBorder)
                        .onSubmit(onReplace)

                    Button("Replace", action: onReplace)
                        .disabled(!canReplace)

                    Button("Replace All", action: onReplaceAll)
                        .disabled(!canReplace)
                }
                .controlSize(.small)
                .padding(.horizontal, 2)
                .transition(.move(edge: .top).combined(with: .opacity))
            }
        }
        .padding(12)
        .frame(width: 430)
        .onAppear {
            DispatchQueue.main.async {
                searchFieldFocused = true
            }
        }
        .onChange(of: focusRequest) { _, _ in
            searchFieldFocused = true
        }
        .onChange(of: allowsReplacement) { _, allowsReplacement in
            if !allowsReplacement {
                isReplacePresented = false
            }
        }
    }
}

struct TableOfContentsView: View {
    let headings: [MarkdownOutline.Heading]
    let onSelect: (MarkdownOutline.Heading) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("Table of Contents")
                .font(.headline)
                .padding(.horizontal, 14)
                .padding(.vertical, 12)

            Divider()

            if headings.isEmpty {
                ContentUnavailableView(
                    "No Headings",
                    systemImage: "list.bullet.indent",
                    description: Text("Add Markdown headings to build an outline.")
                )
            } else {
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 2) {
                        ForEach(headings) { heading in
                            TableOfContentsRow(heading: heading) {
                                onSelect(heading)
                            }
                        }
                    }
                    .padding(.top, 6)
                    .padding(.bottom, 28)
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }
}

private struct TableOfContentsRow: View {
    let heading: MarkdownOutline.Heading
    let onSelect: () -> Void

    @State private var isHovered = false

    var body: some View {
        Button(action: onSelect) {
            Text(heading.title)
                .lineLimit(2)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.leading, CGFloat(heading.level - 1) * 12)
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .contentShape(Rectangle())
                .background {
                    RoundedRectangle(cornerRadius: 5, style: .continuous)
                        .fill(isHovered ? Color.primary.opacity(0.06) : .clear)
                }
        }
        .buttonStyle(.plain)
        .onHover { isHovered = $0 }
        .animation(.easeOut(duration: 0.12), value: isHovered)
    }
}

enum MarkdownOutline {
    struct Heading: Identifiable {
        let id: Int
        let level: Int
        let title: String
        let range: NSRange
    }

    private struct Fence {
        let marker: Character
        let length: Int
    }

    static func headings(in markdown: String) -> [Heading] {
        let text = markdown as NSString
        var headings: [Heading] = []
        var location = 0
        var activeFence: Fence?

        while location < text.length {
            let lineRange = text.lineRange(for: NSRange(location: location, length: 0))
            let contentRange = rangeWithoutLineEnding(lineRange, in: text)
            let line = text.substring(with: contentRange)

            if let fence = fence(in: line) {
                if let currentFence = activeFence {
                    if fence.marker == currentFence.marker, fence.length >= currentFence.length {
                        activeFence = nil
                    }
                } else {
                    activeFence = fence
                }
            } else if activeFence == nil,
                      let parsedHeading = parseHeading(line) {
                headings.append(
                    Heading(
                        id: headings.count,
                        level: parsedHeading.level,
                        title: displayTitle(for: parsedHeading.title),
                        range: contentRange
                    )
                )
            }

            location = NSMaxRange(lineRange)
        }

        return headings
    }

    private static func rangeWithoutLineEnding(_ range: NSRange, in text: NSString) -> NSRange {
        var length = range.length
        while length > 0 {
            let scalar = text.character(at: range.location + length - 1)
            guard scalar == 0x0A || scalar == 0x0D else { break }
            length -= 1
        }
        return NSRange(location: range.location, length: length)
    }

    private static func fence(in line: String) -> Fence? {
        let trimmed = line.drop(while: { $0 == " " || $0 == "\t" })
        guard let marker = trimmed.first, marker == "`" || marker == "~" else { return nil }
        let length = trimmed.prefix(while: { $0 == marker }).count
        guard length >= 3 else { return nil }
        return Fence(marker: marker, length: length)
    }

    private static func parseHeading(_ line: String) -> (level: Int, title: String)? {
        let trimmed = line.drop(while: { $0 == " " || $0 == "\t" })
        let markerCount = trimmed.prefix(while: { $0 == "#" }).count
        guard (1...6).contains(markerCount) else { return nil }

        let afterMarker = trimmed.dropFirst(markerCount)
        guard let first = afterMarker.first, first == " " || first == "\t" else { return nil }

        var title = String(afterMarker.drop(while: { $0 == " " || $0 == "\t" }))
            .trimmingCharacters(in: .whitespacesAndNewlines)

        if let closingHashes = title.range(of: #"\s+#+\s*$"#, options: .regularExpression) {
            title.removeSubrange(closingHashes)
            title = title.trimmingCharacters(in: .whitespacesAndNewlines)
        }

        return (markerCount, title)
    }

    private static func displayTitle(for rawTitle: String) -> String {
        guard !rawTitle.isEmpty else { return String(localized: "Untitled Heading") }
        if let attributed = try? AttributedString(markdown: rawTitle) {
            let rendered = String(attributed.characters).trimmingCharacters(in: .whitespacesAndNewlines)
            if !rendered.isEmpty {
                return rendered
            }
        }
        return rawTitle
    }
}
