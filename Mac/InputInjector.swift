import CoreGraphics
import Foundation

/// Trasforma i tocchi dell'iPhone in eventi mouse/scroll sul display virtuale (richiede Accessibilità).
final class InputInjector {
    private let bounds: () -> CGRect
    private var clickCount: Int64 = 0
    private var lastDown = (time: Date.distantPast, point: CGPoint.zero)

    init(bounds: @escaping () -> CGRect) { self.bounds = bounds }

    func handle(_ touch: Touch) {
        let b = bounds()
        let point = CGPoint(x: b.minX + CGFloat(touch.x) * b.width, y: b.minY + CGFloat(touch.y) * b.height)
        switch touch.phase {
        case .began:
            post(.mouseMoved, at: point)
            let isRepeat = Date().timeIntervalSince(lastDown.time) < 0.35 && hypot(point.x - lastDown.point.x, point.y - lastDown.point.y) < 12
            clickCount = isRepeat ? clickCount + 1 : 1
            lastDown = (Date(), point)
            post(.leftMouseDown, at: point)
        case .moved: post(.leftMouseDragged, at: point)
        case .ended: post(.leftMouseUp, at: point)
        case .scroll:
            post(.mouseMoved, at: point)
            CGEvent(scrollWheelEvent2Source: nil, units: .pixel, wheelCount: 2,
                    wheel1: Int32(touch.dy), wheel2: Int32(touch.dx), wheel3: 0)?.post(tap: .cghidEventTap)
        }
    }

    private func post(_ type: CGEventType, at point: CGPoint) {
        let event = CGEvent(mouseEventSource: nil, mouseType: type, mouseCursorPosition: point, mouseButton: .left)
        event?.setIntegerValueField(.mouseEventClickState, value: clickCount)
        event?.post(tap: .cghidEventTap)
    }
}
