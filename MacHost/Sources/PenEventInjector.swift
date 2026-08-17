import AppKit
import CoreGraphics
import Foundation

struct PenEventValues: Equatable {
    let pressure: Double
    let tiltX: Double
    let tiltY: Double
    let rotationDegrees: Double
    let tabletButtons: Int64
}

final class PenEventInjector {
    private let eventSource = CGEventSource(stateID: .hidSystemState)
    private var penDown = false
    private var auxiliaryButtonDown = false
    private var auxiliaryAction: PenButtonAction?
    private var lastPoint = CGPoint.zero
    private var sampleCount: UInt64 = 0

    func handle(packet: PenPacket, displayBounds: CGRect, buttonAction: PenButtonAction = .native) {
        for sample in packet.samples {
            handle(sample: sample, displayBounds: displayBounds, buttonAction: buttonAction)
        }
    }

    func cancelActiveStroke() {
        if penDown {
            post(sample: nil, type: .leftMouseUp, at: lastPoint, values: nil)
            penDown = false
            print("✏️ Pen V1 forced mouse-up during teardown")
        }
        if auxiliaryButtonDown, let action = auxiliaryAction {
            postAuxiliary(action: action, phase: .up, sample: nil, at: lastPoint, values: nil)
            auxiliaryButtonDown = false
            auxiliaryAction = nil
            print("✏️ Pen V1 forced auxiliary-button up during teardown")
        }
    }

    static func values(for sample: PenSample, contact: Bool) -> PenEventValues {
        let pressure = Double(sample.pressure).clamped(to: 0...1)
        let normalizedTilt = (Double(sample.tiltRadians) / (.pi / 2)).clamped(to: 0...1)
        let orientation = Double(sample.orientationRadians)
        // Android measures stylus orientation clockwise from screen-up:
        // 0 = up, -pi/2 = left, pi/2 = right, +/-pi = down.
        // CoreGraphics exposes the injected tablet X tilt with the opposite sign
        // from Android's clockwise screen azimuth (verified on Galaxy Tab S8+).
        // Its Y tilt uses negative values for screen-up.
        let tiltX = (-normalizedTilt * sin(orientation)).clamped(to: -1...1)
        let tiltY = (-normalizedTilt * cos(orientation)).clamped(to: -1...1)
        var buttons: Int64 = contact ? 1 : 0
        if sample.buttons & 32 != 0 { buttons |= 2 } // MotionEvent.BUTTON_STYLUS_PRIMARY
        if sample.buttons & 64 != 0 { buttons |= 4 } // MotionEvent.BUTTON_STYLUS_SECONDARY
        return PenEventValues(
            pressure: pressure,
            tiltX: tiltX,
            tiltY: tiltY,
            // AXIS_ORIENTATION is azimuth, not barrel rotation (PointerEvent.twist).
            rotationDegrees: 0,
            tabletButtons: buttons
        )
    }

    private func handle(sample: PenSample, displayBounds: CGRect, buttonAction: PenButtonAction) {
        let point = CGPoint(
            x: displayBounds.origin.x + CGFloat(sample.x) * displayBounds.width,
            y: displayBounds.origin.y + CGFloat(sample.y) * displayBounds.height
        )
        lastPoint = point
        sampleCount &+= 1
        let values = Self.values(for: sample, contact: penDown)

        if auxiliaryButtonDown, auxiliaryAction != buttonAction {
            if let previousAction = auxiliaryAction {
                postAuxiliary(action: previousAction, phase: .up, sample: sample, at: point, values: values)
            }
            auxiliaryButtonDown = false
            auxiliaryAction = nil
        }

        if buttonAction != .native {
            let primaryButtonPressed = sample.buttons & 32 != 0
            if primaryButtonPressed {
                if penDown {
                    post(sample: sample, type: .leftMouseUp, at: point, values: Self.values(for: sample, contact: false))
                    penDown = false
                }
                if !auxiliaryButtonDown {
                    auxiliaryButtonDown = true
                    auxiliaryAction = buttonAction
                    postAuxiliary(action: buttonAction, phase: .down, sample: sample, at: point, values: values)
                    print("✏️ S Pen button down mapped to (buttonAction.rawValue)")
                } else {
                    postAuxiliary(action: buttonAction, phase: .dragged, sample: sample, at: point, values: values)
                }
                return
            } else if auxiliaryButtonDown, let action = auxiliaryAction {
                postAuxiliary(action: action, phase: .up, sample: sample, at: point, values: values)
                auxiliaryButtonDown = false
                auxiliaryAction = nil
                print("✏️ S Pen button up mapped to (action.rawValue)")
            }
        }

        switch sample.phase {
        case .proximityEnter:
            post(sample: sample, type: .mouseMoved, at: point, values: Self.values(for: sample, contact: false))
            print("✏️ Pen V1 proximity enter tool=\(sample.tool)")
        case .hover:
            post(sample: sample, type: .mouseMoved, at: point, values: Self.values(for: sample, contact: false))
        case .down:
            if penDown { cancelActiveStroke() }
            penDown = true
            post(sample: sample, type: .leftMouseDown, at: point, values: Self.values(for: sample, contact: true))
            print("✏️ Pen V1 down pressure=\(sample.pressure) buttons=\(sample.buttons)")
        case .move:
            let type: CGEventType = penDown ? .leftMouseDragged : .mouseMoved
            post(sample: sample, type: type, at: point, values: Self.values(for: sample, contact: penDown))
        case .up:
            let type: CGEventType = penDown ? .leftMouseUp : .mouseMoved
            post(sample: sample, type: type, at: point, values: Self.values(for: sample, contact: false))
            penDown = false
            print("✏️ Pen V1 up pressure=\(sample.pressure) samples=\(sampleCount)")
        case .cancel:
            cancelActiveStroke()
        case .proximityExit:
            cancelActiveStroke()
            post(sample: sample, type: .mouseMoved, at: point, values: Self.values(for: sample, contact: false))
            print("✏️ Pen V1 proximity exit samples=\(sampleCount)")
        }
    }

    private enum AuxiliaryPhase {
        case down
        case dragged
        case up
    }

    private func postAuxiliary(
        action: PenButtonAction,
        phase: AuxiliaryPhase,
        sample: PenSample?,
        at point: CGPoint,
        values: PenEventValues?
    ) {
        let mapping: (type: CGEventType, button: CGMouseButton)
        switch (action, phase) {
        case (.rightClick, .down): mapping = (.rightMouseDown, .right)
        case (.rightClick, .dragged): mapping = (.rightMouseDragged, .right)
        case (.rightClick, .up): mapping = (.rightMouseUp, .right)
        case (.panCanvas, .down): mapping = (.otherMouseDown, .center)
        case (.panCanvas, .dragged): mapping = (.otherMouseDragged, .center)
        case (.panCanvas, .up): mapping = (.otherMouseUp, .center)
        case (.native, _): return
        }
        post(sample: sample, type: mapping.type, at: point, values: values, button: mapping.button)
    }

    private func post(
        sample: PenSample?,
        type: CGEventType,
        at point: CGPoint,
        values: PenEventValues?,
        button: CGMouseButton = .left
    ) {
        guard let event = CGEvent(
            mouseEventSource: eventSource,
            mouseType: type,
            mouseCursorPosition: point,
            mouseButton: button
        ) else { return }

        if button == .center {
            event.setIntegerValueField(.mouseEventButtonNumber, value: 2)
        }

        event.setIntegerValueField(.mouseEventSubtype, value: 1) // NX_SUBTYPE_TABLET_POINT
        if let values {
            event.setDoubleValueField(.tabletEventPointPressure, value: values.pressure)
            event.setDoubleValueField(.mouseEventPressure, value: values.pressure)
            event.setDoubleValueField(.tabletEventTiltX, value: values.tiltX)
            event.setDoubleValueField(.tabletEventTiltY, value: values.tiltY)
            event.setDoubleValueField(.tabletEventRotation, value: values.rotationDegrees)
            event.setIntegerValueField(.tabletEventPointButtons, value: values.tabletButtons)
            event.setIntegerValueField(.tabletEventDeviceID, value: 1)
        }
        event.post(tap: .cghidEventTap)
    }
}

private extension Comparable {
    func clamped(to range: ClosedRange<Self>) -> Self {
        min(max(self, range.lowerBound), range.upperBound)
    }
}
