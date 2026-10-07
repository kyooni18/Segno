import AppKit
import Combine
import MarkdownEngine
import MarkdownEngineCodeBlocks

final class MarkdownStyleServiceCache: ObservableObject {
    private var cacheKey = ""
    private var cachedHighlighter = MarksSyntaxHighlighter()

    func syntaxHighlighter(
        codeFontName: String,
        lightBackground: NSColor,
        darkBackground: NSColor
    ) -> MarksSyntaxHighlighter {
        let newKey = [
            codeFontName,
            lightBackground.markdownCacheKey,
            darkBackground.markdownCacheKey,
        ].joined(separator: "|")

        if newKey != cacheKey {
            cacheKey = newKey
            cachedHighlighter = MarksSyntaxHighlighter(
                lightBackground: lightBackground,
                darkBackground: darkBackground,
                preferredFontNames: [codeFontName, "SF Mono", "Menlo"]
            )
        }

        return cachedHighlighter
    }
}

final class MarksSyntaxHighlighter: SyntaxHighlighter, @unchecked Sendable {
    private let highlighter: HighlighterSwiftBridge

    init(
        lightBackground: NSColor = NSColor(calibratedWhite: 0.95, alpha: 1),
        darkBackground: NSColor = NSColor(calibratedWhite: 0.13, alpha: 1),
        preferredFontNames: [String] = ["SF Mono", "Menlo"]
    ) {
        highlighter = HighlighterSwiftBridge(
            lightTheme: "github",
            darkTheme: "github-dark",
            lightBackground: lightBackground,
            darkBackground: darkBackground,
            preferredFontNames: preferredFontNames
        )
    }

    func codeFont(size: CGFloat) -> NSFont {
        highlighter.codeFont(size: size)
    }

    func backgroundColor() -> NSColor {
        highlighter.backgroundColor()
    }

    var appearanceDidChangeNotification: Notification.Name? {
        highlighter.appearanceDidChangeNotification
    }

    func highlight(code: String, language: String?) -> NSAttributedString? {
        guard let language else { return nil }

        let rawLanguage = language
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()

        guard !rawLanguage.isEmpty,
              !Self.plainTextAliases.contains(rawLanguage) else {
            return nil
        }

        let normalizedLanguage = Self.languageAliases[rawLanguage] ?? rawLanguage
        guard Self.supportedLanguages.contains(normalizedLanguage) else {
            return nil
        }

        return highlighter.highlight(code: code, language: normalizedLanguage)
    }

    private static let plainTextAliases: Set<String> = [
        "none",
        "plain",
        "plaintext",
        "raw",
        "text",
        "txt",
    ]

    private static let languageAliases: [String: String] = [
        "asm": "x86asm",
        "c#": "csharp",
        "c++": "cpp",
        "cc": "cpp",
        "cjs": "javascript",
        "clj": "clojure",
        "cljs": "clojure",
        "cs": "csharp",
        "cxx": "cpp",
        "docker": "dockerfile",
        "dotenv": "properties",
        "erl": "erlang",
        "ex": "elixir",
        "exs": "elixir",
        "f#": "fsharp",
        "fs": "fsharp",
        "gql": "graphql",
        "golang": "go",
        "h++": "cpp",
        "hpp": "cpp",
        "hs": "haskell",
        "htm": "xml",
        "html": "xml",
        "java-script": "javascript",
        "javascriptreact": "javascript",
        "js": "javascript",
        "json5": "json",
        "jsonc": "json",
        "jsx": "javascript",
        "kt": "kotlin",
        "kts": "kotlin",
        "m": "objectivec",
        "make": "makefile",
        "md": "markdown",
        "mdown": "markdown",
        "mjs": "javascript",
        "mm": "objectivec",
        "nasm": "x86asm",
        "obj-c": "objectivec",
        "obj-c++": "objectivec",
        "objc": "objectivec",
        "objc++": "objectivec",
        "objective-c": "objectivec",
        "objective-c++": "objectivec",
        "pl": "perl",
        "proto": "protobuf",
        "ps": "powershell",
        "ps1": "powershell",
        "py": "python",
        "rb": "ruby",
        "rs": "rust",
        "sh": "bash",
        "shellscript": "bash",
        "svg": "xml",
        "tex": "latex",
        "toml": "ini",
        "ts": "typescript",
        "tsx": "typescript",
        "typescriptreact": "typescript",
        "vb": "vbnet",
        "vb.net": "vbnet",
        "xhtml": "xml",
        "yml": "yaml",
        "zsh": "bash",
    ]

    private static let supportedLanguages: Set<String> = Set(
        """
        1c,abnf,accesslog,actionscript,ada,angelscript,apache,applescript,arcade,arduino,armasm,asciidoc,aspectj,autohotkey,autoit,avrasm,awk,axapta,bash,basic,bnf,brainfuck,c,cal,capnproto,ceylon,clean,clojure,clojure-repl,cmake,coffeescript,coq,cos,cpp,crmsh,crystal,csharp,csp,css,d,dart,delphi,diff,django,dns,dockerfile,dos,dsconfig,dts,dust,ebnf,elixir,elm,erb,erlang,erlang-repl,excel,fix,flix,fortran,fsharp,gams,gauss,gcode,gherkin,glsl,gml,go,golo,gradle,graphql,groovy,haml,handlebars,haskell,haxe,hsp,http,hy,inform7,ini,irpf90,isbl,java,javascript,jboss-cli,json,julia,julia-repl,kotlin,lasso,latex,ldif,leaf,less,lisp,livecodeserver,livescript,llvm,lsl,lua,makefile,markdown,mathematica,matlab,maxima,mel,mercury,mipsasm,mizar,mojolicious,monkey,moonscript,n1ql,nestedtext,nginx,nim,nix,node-repl,nsis,objectivec,ocaml,openscad,oxygene,parser3,perl,pf,pgsql,php,php-template,plaintext,pony,powershell,processing,profile,prolog,properties,protobuf,puppet,purebasic,python,python-repl,q,qml,r,reasonml,rib,roboconf,routeros,rsl,ruby,ruleslanguage,rust,sas,scala,scheme,scilab,scss,shell,smali,smalltalk,sml,sqf,sql,stan,stata,step21,stylus,subunit,swift,taggerscript,tap,tcl,thrift,tp,twig,typescript,vala,vbnet,vbscript,vbscript-html,verilog,vhdl,vim,wasm,wren,x86asm,xl,xml,xquery,yaml,zephir
        """
        .split(separator: ",")
        .map { String($0).trimmingCharacters(in: .whitespacesAndNewlines) }
    )
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
