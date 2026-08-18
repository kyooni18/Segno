import AppKit
import Combine
import MarkdownEngineCodeBlocks

final class MarkdownStyleServiceCache: ObservableObject {
    private var cacheKey = ""
    private var cachedHighlighter = HighlighterSwiftBridge()

    func syntaxHighlighter(
        codeFontName: String,
        lightBackground: NSColor,
        darkBackground: NSColor
    ) -> HighlighterSwiftBridge {
        let newKey = [
            codeFontName,
            lightBackground.markdownCacheKey,
            darkBackground.markdownCacheKey,
        ].joined(separator: "|")

        if newKey != cacheKey {
            cacheKey = newKey
            cachedHighlighter = HighlighterSwiftBridge(
                lightBackground: lightBackground,
                darkBackground: darkBackground,
                preferredFontNames: [codeFontName, "SF Mono", "Menlo"]
            )
        }

        return cachedHighlighter
    }
}

private extension NSColor {
    var markdownCacheKey: String {
        let color = usingColorSpace(.sRGB) ?? self
        return String(
            format: "%.5f-%.5f-%.5f-%.5f",
            color.redComponent,
            color.greenComponent,
            color.blueComponent,
            color.alphaComponent
        )
    }
}
