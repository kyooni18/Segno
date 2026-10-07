import AppKit
import Combine
import MarkdownEngine
import MarkdownEngineCodeBlocks
import MarkdownEngineLatex
import SwiftUI

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
        .frame(
            minWidth: 460,
            idealWidth: 520,
            maxWidth: 700,
            minHeight: 500,
            idealHeight: 700,
            maxHeight: 900
        )
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
            Text("\(Int(value.wrappedValue).formatted(.number)) \(suffix)")
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
            Text("\(value.wrappedValue.formatted(.number.precision(.fractionLength(precision)))) \(suffix)")
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
