import Foundation
import Testing

/// Garantisce che il catalogo `Shared/Localizable.xcstrings` sia completo e coerente con il codice.
@Suite struct LocalizationTests {
    static let languages = ["en", "it", "fr", "es", "de"]
    static let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent()

    /// chiave → lingua → testo
    private func catalog() throws -> [String: [String: String]] {
        let data = try Data(contentsOf: Self.root.appending(path: "Shared/Localizable.xcstrings"))
        let json = try #require(JSONSerialization.jsonObject(with: data) as? [String: Any])
        let strings = try #require(json["strings"] as? [String: [String: Any]])
        return strings.mapValues { entry in
            (entry["localizations"] as? [String: [String: [String: String]]] ?? [:])
                .compactMapValues { $0["stringUnit"]?["value"] }
        }
    }

    @Test func everyKeyIsTranslatedInEveryLanguage() throws {
        for (key, values) in try catalog() {
            for language in Self.languages {
                #expect(values[language]?.isEmpty == false, "\(key) manca in \(language)")
            }
        }
    }

    @Test func keysUsedInCodeExist() throws {
        let keys = Set(try catalog().keys)
        let pattern = try NSRegularExpression(pattern: #""((?:app|step|phone|gesture|state|detail|perm|mac|action|about)\.[a-z_]+(?:\.[a-z]+)?)""#)
        for folder in ["Shared", "Mac", "Phone"] {
            let files = FileManager.default.enumerator(at: Self.root.appending(path: folder), includingPropertiesForKeys: nil)!
            for case let file as URL in files where file.pathExtension == "swift" {
                let text = try String(contentsOf: file, encoding: .utf8)
                for match in pattern.matches(in: text, range: NSRange(text.startIndex..., in: text)) {
                    let key = String(text[Range(match.range(at: 1), in: text)!])
                    let exists = keys.contains(key) || keys.contains(key + ".title")   // o prefisso di una famiglia dinamica
                    #expect(exists, "\(file.lastPathComponent): chiave '\(key)' assente dal catalogo")
                }
            }
        }
    }

    /// Ogni app elencata in `AboutContent` ha frase tradotta e icona.
    @Test func aboutAppsAreComplete() throws {
        let keys = Set(try catalog().keys)
        let source = try String(contentsOf: Self.root.appending(path: "Mac/AboutContent.swift"), encoding: .utf8)
        let ids = try NSRegularExpression(pattern: #"App\(id: "([a-z]+)""#).matches(in: source, range: NSRange(source.startIndex..., in: source))
            .map { String(source[Range($0.range(at: 1), in: source)!]) }
        #expect(!ids.isEmpty)
        for id in ids {
            #expect(keys.contains("about.app.\(id)"), "manca la frase di \(id)")
            #expect(FileManager.default.fileExists(atPath: Self.root.appending(path: "Mac/Assets.xcassets/App_\(id).imageset/icon.png").path), "manca l'icona di \(id)")
        }
    }

    /// Chiavi costruite dinamicamente (`step.\(nome).title`, `state.\(key).detail`, …).
    @Test func dynamicKeysExist() throws {
        let keys = Set(try catalog().keys)
        let families: [(String, [String])] = [
            ("step", ["cable", "mac", "phone"]), ("gesture", ["one", "two"]), ("perm", ["screen", "accessibility"]), ("about.feature", ["display", "touch", "private"]),
            ("state", ["permissions", "device", "app", "connecting", "streaming", "failed", "outdated", "disconnected"]),
        ]
        for (prefix, names) in families {
            for name in names { for part in ["title", "detail"] { #expect(keys.contains("\(prefix).\(name).\(part)")) } }
        }
    }
}
