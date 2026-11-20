import Foundation

/// Identità stabile di questo iPhone: la usa il Mac per riconoscerlo (via cavo e su Wi-Fi).
enum Identity {
    static let phoneID: UUID = {
        let key = "phoneID"
        if let saved = UserDefaults.standard.string(forKey: key), let id = UUID(uuidString: saved) { return id }
        let id = UUID()
        UserDefaults.standard.set(id.uuidString, forKey: key)
        return id
    }()
}
