// Finto iPhone per test automatici (non fa parte delle app).
// Build: swiftc -O Shared/ByteCoding.swift Shared/Wire.swift Shared/Link.swift Shared/Pairing.swift Tools/fakephone/main.swift -o fakephone
// Uso:   ./fakephone [larghezza altezza]   poi avvia l'app Mac con `-tcpHost 127.0.0.1`.
import CoreGraphics
import Foundation
import Network
import os

struct Stats {
    var config: StreamConfig?
    var frames: [(t: Double, bytes: Int, key: Bool)] = []
}
let stats = OSAllocatedUnfairLock(initialState: Stats())
func now() -> Double { Double(DispatchTime.now().uptimeNanoseconds) / 1e9 }
func pause(_ s: Double) async { try? await Task.sleep(for: .seconds(s)) }
func check(_ ok: Bool, _ what: String) { print(ok ? "PASS" : "FAIL", what); if !ok { failures += 1 } }
var failures = 0

let args = CommandLine.arguments.dropFirst().compactMap(Int.init)
let (w, h) = args.count == 2 ? (args[0], args[1]) : (2494, 1206)

let listener = try NWListener(using: Link.tcp(), on: NWEndpoint.Port(rawValue: Wire.port)!)
let link: Link = await withCheckedContinuation { cont in
    let taken = OSAllocatedUnfairLock(initialState: false)
    listener.newConnectionHandler = { c in
        if taken.withLock({ let was = $0; $0 = true; return was }) { c.cancel() } else { cont.resume(returning: Link(c)) }
    }
    listener.start(queue: .main)
    print("in attesa del Mac su :\(Wire.port) …")
}
try await link.start()
print("Mac connesso; hello \(w)x\(h)")
link.send(.hello(Hello(width: w, height: h, supportsHEVC: true, id: UUID(), name: "fakephone")))

Task {
    while let m = try? await link.receive() {
        switch m {
        case .config(let c): stats.withLock { $0.config = c }
        case .frame(let d, let key, _): stats.withLock { $0.frames.append((now(), d.count, key)) }
        default: break
        }
    }
}

// 1. config + primo keyframe
var waited = 0.0
while stats.withLock({ $0.frames.isEmpty }) && waited < 10 { await pause(0.1); waited += 0.1 }
let first = stats.withLock { $0 }
check(first.config != nil, "config ricevuta \(first.config.map { "\($0.codec) \($0.width)x\($0.height)@\($0.fps)" } ?? "-")")
check(first.frames.first?.key == true, "primo frame è un keyframe (\(first.frames.first?.bytes ?? 0) B)")

// 2. keyframe on demand
let before = now()
link.send(.keyframeRequest)
await pause(1.0)
check(stats.withLock { $0.frames.contains { $0.t > before && $0.key } }, "keyframeRequest → nuovo keyframe")

// 3. input: il cursore deve finire sul display virtuale
var n: UInt32 = 0; var ids = [CGDirectDisplayID](repeating: 0, count: 16); CGGetActiveDisplayList(16, &ids, &n)
guard let vd = ids.prefix(Int(n)).first(where: { $0 != CGMainDisplayID() && CGDisplayIsBuiltin($0) == 0 }) else {
    check(false, "display virtuale non trovato"); exit(1)
}
let b = CGDisplayBounds(vd)
print("display virtuale \(vd): \(Int(b.width))x\(Int(b.height)) pt @ (\(Int(b.minX)),\(Int(b.minY)))")
link.send(.touch(Touch(phase: .began, x: 0.25, y: 0.75)))
await pause(0.3)
let p = CGEvent(source: nil)!.location
let ex = CGPoint(x: b.minX + 0.25 * b.width, y: b.minY + 0.75 * b.height)
check(hypot(p.x - ex.x, p.y - ex.y) < 3, "tocco → cursore a (\(Int(p.x)),\(Int(p.y))), atteso (\(Int(ex.x)),\(Int(ex.y)))")

// 4. trascinamento a 120 Hz per 3 s: fps video e latenza tocco→frame
let dragStart = now()
var sends: [Double] = []
for i in 0..<360 {
    let a = Double(i) / 30
    sends.append(now())
    link.send(.touch(Touch(phase: .moved, x: Float(0.5 + 0.3 * cos(a)), y: Float(0.5 + 0.3 * sin(a)))))
    await pause(1.0 / 120)
}
link.send(.touch(Touch(phase: .ended, x: 0.5, y: 0.5)))
await pause(0.5)
let all = stats.withLock { $0.frames }.filter { $0.t >= dragStart }
let drag = all.filter { $0.t < dragStart + 3.2 }
let fps = Double(drag.count) / 3.0
let lat = sends.compactMap { t in all.first { $0.t > t }.map { ($0.t - t) * 1000 } }.sorted()
let mbps = Double(drag.reduce(0) { $0 + $1.bytes }) * 8 / 3 / 1e6
print(String(format: "durante il drag: %.1f fps, %.1f Mb/s, latenza tocco→frame mediana %.0f ms, p95 %.0f ms",
             fps, mbps, lat[lat.count / 2], lat[Int(Double(lat.count) * 0.95)]))
check(fps > 40, "≥ 40 fps durante il movimento")
check(lat[lat.count / 2] < 100, "latenza mediana < 100 ms")

if let hold = ProcessInfo.processInfo.environment["HOLD"].flatMap(Double.init) { await pause(hold) }
print(failures == 0 ? "TUTTO OK" : "\(failures) FALLITI")
exit(failures == 0 ? 0 : 1)
