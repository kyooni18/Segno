import AppKit
import Combine
import MarkdownEngine
import MarkdownEngineCodeBlocks
import MarkdownEngineLatex
import SwiftUI

enum MarkdownStylePreferences {
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
    static let defaultParagraphSpacingFactor = 0.25
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

extension NSColor {
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
