import AppKit
import Combine
import MarkdownEngine
import MarkdownEngineCodeBlocks
import MarkdownEngineLatex
import SwiftUI

struct DocumentMetrics: Equatable {
    let wordCount: Int
    let characterCount: Int
    let lineCount: Int

    init(text: String) {
        characterCount = text.count
        lineCount = text.isEmpty ? 0 : text.reduce(into: 1) { count, character in
            if character == "\n" {
                count += 1
            }
        }
        wordCount = text.split(whereSeparator: { $0.isWhitespace || $0.isNewline }).count
    }
}


struct DocumentStatusBar: View {
    let fileURL: URL?
    let metrics: DocumentMetrics

    var body: some View {
        HStack(spacing: 10) {
            if let fileURL {
                Label(fileURL.lastPathComponent, systemImage: "doc.text")
                    .lineLimit(1)
                    .truncationMode(.middle)
            } else {
                Label("Unsaved Document", systemImage: "doc.badge.plus")
            }

            Spacer(minLength: 16)

            Text("\(metrics.lineCount) lines")
            Text("\(metrics.wordCount) words")
            Text("\(metrics.characterCount) characters")
        }
        .font(.caption)
        .foregroundStyle(.secondary)
        .padding(.horizontal, 12)
        .frame(height: 26)
        .glassEffect(.clear, in: .rect(cornerRadius: 0))
        .overlay(alignment: .top) {
            Divider()
        }
    }
}
