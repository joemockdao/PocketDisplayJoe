import Foundation

/// Scrittore big-endian minimale per il protocollo binario.
struct ByteWriter {
    private(set) var data = Data()

    mutating func put<T: FixedWidthInteger>(_ value: T) {
        withUnsafeBytes(of: value.bigEndian) { data.append(contentsOf: $0) }
    }
    mutating func put(_ value: Float) { put(value.bitPattern) }
    mutating func put(_ bytes: Data) { data.append(bytes) }
}

/// Lettore big-endian; ogni `get` restituisce nil se i dati sono troppo corti.
struct ByteReader {
    private let data: Data
    private var position = 0

    init(_ data: Data) { self.data = data }

    var remaining: Int { data.count - position }

    mutating func get<T: FixedWidthInteger>(_ type: T.Type = T.self) -> T? {
        let size = MemoryLayout<T>.size
        guard remaining >= size else { return nil }
        defer { position += size }
        return T(bigEndian: data.withUnsafeBytes { $0.loadUnaligned(fromByteOffset: position, as: T.self) })
    }

    mutating func float() -> Float? { get(UInt32.self).map(Float.init(bitPattern:)) }

    mutating func bytes(_ count: Int) -> Data? {
        guard remaining >= count else { return nil }
        defer { position += count }
        let start = data.startIndex + position
        return data.subdata(in: start..<start + count)
    }

    mutating func rest() -> Data { bytes(remaining) ?? Data() }
}
