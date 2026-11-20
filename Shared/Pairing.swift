import Foundation
import Security

/// Segreto condiviso tra un Mac e un iPhone per i collegamenti Wi-Fi (TLS con chiave pre-condivisa).
/// Nasce via cavo USB, un canale già autenticato, e non viaggia mai sulla rete.
struct PairingKey: Codable, Equatable {
    static let idSize = 8, secretSize = 32

    var id: Data        // identificatore pubblico (PSK identity)
    var secret: Data    // 256 bit casuali

    static func random() -> PairingKey {
        PairingKey(id: Data((0..<idSize).map { _ in .random(in: .min ... .max) }),
                   secret: Data((0..<secretSize).map { _ in .random(in: .min ... .max) }))
    }
}

/// Un iPhone abbinato, come lo conosce il Mac.
struct PairedPhone: Codable, Equatable, Identifiable {
    var id: UUID
    var name: String
    var key: PairingKey
}

/// Archivio nel portachiavi: un elemento per account, valore codificato in JSON.
struct Vault<Value: Codable> {
    let service: String

    /// Il portachiavi non restituisce i dati di più elementi in una sola query: prima gli account, poi ciascun valore.
    func all() -> [Value] {
        let list: [CFString: Any] = [kSecClass: kSecClassGenericPassword, kSecAttrService: service,
                                     kSecMatchLimit: kSecMatchLimitAll, kSecReturnAttributes: true]
        var result: CFTypeRef?
        guard SecItemCopyMatching(list as CFDictionary, &result) == errSecSuccess, let items = result as? [[CFString: Any]] else { return [] }
        return items.compactMap { $0[kSecAttrAccount] as? String }.compactMap(load)
    }

    private func load(account: String) -> Value? {
        let query: [CFString: Any] = [kSecClass: kSecClassGenericPassword, kSecAttrService: service,
                                      kSecAttrAccount: account, kSecReturnData: true]
        var result: CFTypeRef?
        guard SecItemCopyMatching(query as CFDictionary, &result) == errSecSuccess, let data = result as? Data else { return nil }
        return try? JSONDecoder().decode(Value.self, from: data)
    }

    func save(_ value: Value, account: String) {
        guard let data = try? JSONEncoder().encode(value) else { return }
        let key: [CFString: Any] = [kSecClass: kSecClassGenericPassword, kSecAttrService: service, kSecAttrAccount: account]
        if SecItemUpdate(key as CFDictionary, [kSecValueData: data] as CFDictionary) == errSecItemNotFound {
            SecItemAdd(key.merging([kSecValueData: data, kSecAttrAccessible: kSecAttrAccessibleAfterFirstUnlock]) { $1 } as CFDictionary, nil)
        }
    }

    func delete(account: String? = nil) {
        var query: [CFString: Any] = [kSecClass: kSecClassGenericPassword, kSecAttrService: service]
        if let account { query[kSecAttrAccount] = account }
        SecItemDelete(query as CFDictionary)
    }
}

/// Lato iPhone: le chiavi dei Mac abbinati.
enum PhoneKeys {
    static var vault = Vault<PairingKey>(service: "it.joe.pocketdisplay.mac-keys")
    static var all: [PairingKey] { vault.all() }
    static func add(_ key: PairingKey) { vault.save(key, account: key.id.map { String(format: "%02x", $0) }.joined()) }
    static func removeAll() { vault.delete() }
}

/// Lato Mac: gli iPhone abbinati.
enum PairedPhones {
    static var vault = Vault<PairedPhone>(service: "it.joe.pocketdisplay.phones")
    static var all: [PairedPhone] { vault.all() }

    /// Trova (o crea) l'abbinamento di un iPhone appena collegato via cavo; riesegue sempre il salvataggio
    /// per aggiornare il nome. Se l'iPhone ha dimenticato la chiave, il cavo la ripristina.
    static func ensure(id: UUID, name: String) -> PairingKey {
        let key = all.first { $0.id == id }?.key ?? .random()
        vault.save(PairedPhone(id: id, name: name, key: key), account: id.uuidString)
        return key
    }

    static func forget(_ id: UUID) { vault.delete(account: id.uuidString) }
}
