import Foundation
import Testing

@Suite struct WireTests {
    private func roundTrip(_ message: Message) -> Message? {
        let frame = message.encoded()
        var header = ByteReader(frame)
        #expect(Int(header.get(UInt32.self) ?? 0) == frame.count - 4)
        return Message(payload: frame.dropFirst(4))
    }

    @Test func hello() {
        let m = Message.hello(Hello(width: 2622, height: 1206, supportsHEVC: true, id: UUID(), name: "iPhone di Giò"))
        #expect(roundTrip(m) == m)
    }
    @Test func pair() { let m = Message.pair(.random()); #expect(roundTrip(m) == m) }
    @Test func pairingKeysAreRandomAndSized() {
        let a = PairingKey.random(), b = PairingKey.random()
        #expect(a != b)
        #expect(a.id.count == PairingKey.idSize && a.secret.count == PairingKey.secretSize)
    }
    @Test func vaultRoundTrip() {
        let vault = Vault<PairedPhone>(service: "it.joe.pocketdisplay.tests.\(UUID())")
        defer { vault.delete() }
        let phone = PairedPhone(id: UUID(), name: "Test", key: .random())
        vault.save(phone, account: "a")
        vault.save(PairedPhone(id: phone.id, name: "Rinominato", key: phone.key), account: "a")   // aggiorna, non duplica
        #expect(vault.all().map(\.name) == ["Rinominato"])
        vault.delete(account: "a")
        #expect(vault.all().isEmpty)
    }
    @Test func config() { let m = Message.config(StreamConfig(codec: .hevc, width: 2556, height: 1206, fps: 60)); #expect(roundTrip(m) == m) }
    @Test func parameterSets() { let m = Message.parameterSets([Data([1, 2, 3]), Data(repeating: 9, count: 300)]); #expect(roundTrip(m) == m) }
    @Test func frame() { let m = Message.frame(Data((0..<255).map { UInt8($0) }), keyframe: true, time: 1_234_567_890_123); #expect(roundTrip(m) == m) }
    @Test func touch() { let m = Message.touch(Touch(phase: .scroll, x: 0.25, y: 0.75, dx: -3.5, dy: 12)); #expect(roundTrip(m) == m) }
    @Test func keyframeRequest() { #expect(roundTrip(.keyframeRequest) == .keyframeRequest) }
    @Test func malformed() {
        #expect(Message(payload: Data()) == nil)
        #expect(Message(payload: Data([99])) == nil)
        #expect(Message(payload: Data([5, 0])) == nil)   // touch troncato
    }
}
