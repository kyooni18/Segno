import Combine
import Foundation
import SwiftUI
import UniformTypeIdentifiers

final class MarkdownDocument: ReferenceFileDocument, @unchecked Sendable {
    struct DocumentSnapshot: Sendable {
        let text: String
        let encoding: TextEncoding
    }

    enum TextEncoding: Sendable {
        case utf8
        case utf8WithBOM
        case utf16LittleEndian
        case utf16BigEndian
        case utf32LittleEndian
        case utf32BigEndian
    }

    typealias Snapshot = DocumentSnapshot

    static var readableContentTypes: [UTType] { [.markdown, .plainText] }
    static var writableContentTypes: [UTType] { [.markdown, .plainText] }

    let objectWillChange = ObservableObjectPublisher()

    var text: String {
        get {
            textLock.lock()
            defer { textLock.unlock() }
            return storageText
        }
        set {
            textLock.lock()
            let changed = storageText != newValue
            textLock.unlock()

            guard changed else { return }
            objectWillChange.send()

            textLock.lock()
            storageText = newValue
            textLock.unlock()
        }
    }

    private let sourceEncoding: TextEncoding
    private let textLock = NSLock()
    private var storageText: String

    init(text: String = starterText) {
        sourceEncoding = .utf8
        storageText = text
    }

    required init(configuration: ReadConfiguration) throws {
        guard let data = configuration.file.regularFileContents else {
            throw CocoaError(.fileReadCorruptFile)
        }

        let decoded = try Self.decode(data)
        sourceEncoding = decoded.encoding
        storageText = decoded.text
    }

    func snapshot(contentType: UTType) throws -> DocumentSnapshot {
        textLock.lock()
        defer { textLock.unlock() }
        return DocumentSnapshot(text: storageText, encoding: sourceEncoding)
    }

    func fileWrapper(snapshot: DocumentSnapshot, configuration: WriteConfiguration) throws -> FileWrapper {
        let data = try Self.encode(snapshot.text, as: snapshot.encoding)
        return FileWrapper(regularFileWithContents: data)
    }

    private static func decode(_ data: Data) throws -> (text: String, encoding: TextEncoding) {
        if data.starts(with: [0x00, 0x00, 0xFE, 0xFF]) {
            return try decodeBOMData(data, dropping: 4, encoding: .utf32BigEndian, kind: .utf32BigEndian)
        }

        if data.starts(with: [0xFF, 0xFE, 0x00, 0x00]) {
            return try decodeBOMData(data, dropping: 4, encoding: .utf32LittleEndian, kind: .utf32LittleEndian)
        }

        if data.starts(with: [0xEF, 0xBB, 0xBF]) {
            return try decodeBOMData(data, dropping: 3, encoding: .utf8, kind: .utf8WithBOM)
        }

        if data.starts(with: [0xFE, 0xFF]) {
            return try decodeBOMData(data, dropping: 2, encoding: .utf16BigEndian, kind: .utf16BigEndian)
        }

        if data.starts(with: [0xFF, 0xFE]) {
            return try decodeBOMData(data, dropping: 2, encoding: .utf16LittleEndian, kind: .utf16LittleEndian)
        }

        guard let text = String(data: data, encoding: .utf8) else {
            throw CocoaError(.fileReadInapplicableStringEncoding)
        }
        return (text, .utf8)
    }

    private static func decodeBOMData(
        _ data: Data,
        dropping byteCount: Int,
        encoding: String.Encoding,
        kind: TextEncoding
    ) throws -> (text: String, encoding: TextEncoding) {
        let body = Data(data.dropFirst(byteCount))
        guard let text = String(data: body, encoding: encoding) else {
            throw CocoaError(.fileReadInapplicableStringEncoding)
        }
        return (text, kind)
    }

    private static func encode(_ text: String, as encoding: TextEncoding) throws -> Data {
        switch encoding {
        case .utf8:
            return Data(text.utf8)

        case .utf8WithBOM:
            var data = Data([0xEF, 0xBB, 0xBF])
            data.append(contentsOf: text.utf8)
            return data

        case .utf16LittleEndian:
            return try encodeWithBOM(text, encoding: .utf16LittleEndian, bom: [0xFF, 0xFE])

        case .utf16BigEndian:
            return try encodeWithBOM(text, encoding: .utf16BigEndian, bom: [0xFE, 0xFF])

        case .utf32LittleEndian:
            return try encodeWithBOM(text, encoding: .utf32LittleEndian, bom: [0xFF, 0xFE, 0x00, 0x00])

        case .utf32BigEndian:
            return try encodeWithBOM(text, encoding: .utf32BigEndian, bom: [0x00, 0x00, 0xFE, 0xFF])
        }
    }

    private static func encodeWithBOM(
        _ text: String,
        encoding: String.Encoding,
        bom: [UInt8]
    ) throws -> Data {
        guard let body = text.data(using: encoding) else {
            throw CocoaError(.fileWriteInapplicableStringEncoding)
        }
        var data = Data(bom)
        data.append(body)
        return data
    }

    static let starterText = ""
}
