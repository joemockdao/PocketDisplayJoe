import SwiftUI
import UIKit

/// Superficie video + input: un dito = mouse (click/trascinamento), due dita = scroll.
final class ScreenView: UIView {
    var onTouch: ((Touch) -> Void)?
    var onResize: ((CGSize) -> Void)?

    private let videoLayer: CALayer
    private var beginTask: DispatchWorkItem?   // il "mouse down" parte dopo 50 ms: se arriva un 2° dito è uno scroll
    private var isDown = false
    private var lastPoint = CGPoint.zero

    init(videoLayer: CALayer) {
        self.videoLayer = videoLayer
        super.init(frame: .zero)
        backgroundColor = .black
        layer.addSublayer(videoLayer)
        isMultipleTouchEnabled = true

        let scroll = UIPanGestureRecognizer(target: self, action: #selector(scrolled))
        scroll.minimumNumberOfTouches = 2
        scroll.maximumNumberOfTouches = 2
        addGestureRecognizer(scroll)
    }
    required init?(coder: NSCoder) { fatalError() }

    override func layoutSubviews() {
        super.layoutSubviews()
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        videoLayer.frame = bounds
        CATransaction.commit()
        let scale = window?.screen.nativeScale ?? UIScreen.main.nativeScale
        onResize?(CGSize(width: bounds.width * scale, height: bounds.height * scale))
    }

    /// Diagnostica: mostra le statistiche di ricezione in alto (avvio con `-showStats YES`).
    func showStats(from sink: VideoSink) {
        let label = UILabel()
        label.font = .monospacedSystemFont(ofSize: 13, weight: .medium)
        label.textColor = .yellow
        label.backgroundColor = UIColor.black.withAlphaComponent(0.6)
        label.frame = CGRect(x: 80, y: 8, width: 520, height: 22)
        label.autoresizingMask = [.flexibleBottomMargin]
        addSubview(label)
        sink.onStats = { label.text = " " + $0 }
    }

    // MARK: Un dito → mouse

    private func normalized(_ point: CGPoint) -> (Float, Float) {
        (Float(min(max(point.x / bounds.width, 0), 1)), Float(min(max(point.y / bounds.height, 0), 1)))
    }

    private func send(_ phase: Touch.Phase, at point: CGPoint) {
        let (x, y) = normalized(point)
        onTouch?(Touch(phase: phase, x: x, y: y))
    }

    private func beginNow() {
        beginTask?.cancel(); beginTask = nil
        guard !isDown else { return }
        isDown = true
        send(.began, at: lastPoint)
    }

    private func endNow() {
        beginTask?.cancel(); beginTask = nil
        if isDown { send(.ended, at: lastPoint); isDown = false }
    }

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        if (event?.allTouches?.count ?? 1) > 1 { endNow(); return }   // 2° dito: scroll, non click
        lastPoint = touches.first?.location(in: self) ?? .zero
        let work = DispatchWorkItem { [weak self] in self?.beginNow() }
        beginTask = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05, execute: work)
    }

    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard (event?.allTouches?.count ?? 1) == 1, let touch = touches.first else { return }
        lastPoint = touch.location(in: self)
        if isDown { send(.moved, at: lastPoint) }
    }

    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        if (event?.allTouches?.count ?? 1) == 1 { beginNow(); endNow() }   // tap veloce: down+up
    }

    override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) { endNow() }

    // MARK: Due dita → scroll

    @objc private func scrolled(_ pan: UIPanGestureRecognizer) {
        guard pan.state == .changed else { return }
        let delta = pan.translation(in: self)
        pan.setTranslation(.zero, in: self)
        let (x, y) = normalized(pan.location(in: self))
        onTouch?(Touch(phase: .scroll, x: x, y: y, dx: Float(delta.x), dy: Float(delta.y)))
    }
}

struct ScreenViewRepresentable: UIViewRepresentable {
    let receiver: Receiver

    func makeUIView(context: Context) -> ScreenView {
        let view = ScreenView(videoLayer: receiver.sink.layer)
        view.onTouch = { receiver.send(.touch($0)) }
        view.onResize = { receiver.viewSizeChanged($0) }
        if UserDefaults.standard.bool(forKey: "showStats") { view.showStats(from: receiver.sink) }
        return view
    }

    func updateUIView(_ view: ScreenView, context: Context) {}
}
