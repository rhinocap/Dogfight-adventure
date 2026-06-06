//
//  FlightHUD.swift
//  Dogfight Adventures
//
//  iPad touch controls + heads-up display, drawn with CALayers for crispness.
//  Right thumb: virtual stick (roll + pitch). Left thumb: vertical throttle.
//  Fire button sits inboard of the stick. Multi-touch so all three work at once.
//

import UIKit

final class FlightHUD: UIView {

    // MARK: Control outputs (read by the game loop each frame)
    private(set) var rollInput: Float = 0    // -1 ... +1
    private(set) var pitchInput: Float = 0   // -1 ... +1  (drag down = nose up)
    private(set) var throttle: Float = 0.6   // 0 ... 1
    private(set) var firing: Bool = false
    private(set) var aiming: Bool = false   // hold AIM → slow-motion

    var onRestart: (() -> Void)?
    var onToggleView: (() -> Void)?         // tap VIEW → switch camera

    // MARK: Layout constants
    private let stickRadius: CGFloat = 92
    private let knobRadius: CGFloat = 40
    private let throttleSize = CGSize(width: 78, height: 260)
    private let fireRadius: CGFloat = 58
    private let aimRadius: CGFloat = 48
    private let viewRadius: CGFloat = 44

    // MARK: Layers
    private let stickBase = CAShapeLayer()
    private let stickKnob = CAShapeLayer()
    private let throttleTrack = CAShapeLayer()
    private let throttleFill = CAShapeLayer()
    private let throttleKnob = CAShapeLayer()
    private let fireRing = CAShapeLayer()
    private let aimRing = CAShapeLayer()
    private let viewRing = CAShapeLayer()
    private let crosshair = CAShapeLayer()

    // MARK: Readout labels
    private let speedLabel = HUDLabel()
    private let altLabel = HUDLabel()
    private let healthLabel = HUDLabel()
    private let enemiesLabel = HUDLabel()
    private let banner = HUDLabel(size: 34, weight: .bold)
    private let hint = HUDLabel(size: 14, weight: .regular)
    private let fireLabel = HUDLabel(size: 16, weight: .bold)
    private let aimLabel = HUDLabel(size: 15, weight: .bold)
    private let viewLabel = HUDLabel(size: 14, weight: .bold)

    // MARK: Geometry (recomputed on layout)
    private var stickCenter: CGPoint = .zero
    private var fireCenter: CGPoint = .zero
    private var aimCenter: CGPoint = .zero
    private var viewCenter: CGPoint = .zero
    private var throttleRect: CGRect = .zero

    // MARK: Touch routing
    private enum Control { case stick, throttle, fire, aim, view }
    private var assignments: [Int: Control] = [:] // ObjectIdentifier hash → control

    override init(frame: CGRect) {
        super.init(frame: frame)
        isMultipleTouchEnabled = true
        backgroundColor = .clear
        setupLayers()
        setupLabels()
    }

    required init?(coder: NSCoder) { fatalError() }

    // MARK: Setup

    private func setupLayers() {
        func style(_ l: CAShapeLayer, fill: UIColor, stroke: UIColor, lineWidth: CGFloat = 2) {
            l.fillColor = fill.cgColor
            l.strokeColor = stroke.cgColor
            l.lineWidth = lineWidth
            layer.addSublayer(l)
        }
        let glass = UIColor(white: 1, alpha: 0.10)
        let edge = UIColor(white: 1, alpha: 0.55)

        style(stickBase, fill: glass, stroke: edge)
        style(stickKnob, fill: UIColor(white: 1, alpha: 0.28), stroke: edge, lineWidth: 2.5)
        style(throttleTrack, fill: glass, stroke: edge)
        style(throttleFill, fill: UIColor(red: 0.20, green: 0.55, blue: 0.95, alpha: 0.40), stroke: .clear, lineWidth: 0)
        style(throttleKnob, fill: UIColor(white: 1, alpha: 0.30), stroke: edge, lineWidth: 2.5)
        style(fireRing, fill: UIColor(red: 0.95, green: 0.25, blue: 0.20, alpha: 0.28),
              stroke: UIColor(red: 1, green: 0.5, blue: 0.45, alpha: 0.9), lineWidth: 2.5)
        style(aimRing, fill: UIColor(red: 1.0, green: 0.82, blue: 0.20, alpha: 0.24),
              stroke: UIColor(red: 1.0, green: 0.88, blue: 0.4, alpha: 0.95), lineWidth: 2.5)
        style(viewRing, fill: UIColor(red: 0.30, green: 0.70, blue: 1.0, alpha: 0.22),
              stroke: UIColor(red: 0.6, green: 0.85, blue: 1.0, alpha: 0.95), lineWidth: 2.5)
        style(crosshair, fill: .clear, stroke: UIColor(red: 0.4, green: 1, blue: 0.6, alpha: 0.85), lineWidth: 2)
    }

    private func setupLabels() {
        [speedLabel, altLabel, healthLabel, enemiesLabel, banner, hint,
         fireLabel, aimLabel, viewLabel].forEach { addSubview($0) }
        banner.textAlignment = .center
        banner.alpha = 0
        hint.textAlignment = .center
        hint.alpha = 0.85
        hint.text = "Right thumb: steer  ·  Left: throttle  ·  FIRE shoots  ·  AIM slows time  ·  VIEW changes camera"
        for l in [fireLabel, aimLabel, viewLabel] { l.textAlignment = .center }
        fireLabel.text = "FIRE"; aimLabel.text = "AIM"; viewLabel.text = "VIEW"
    }

    // MARK: Layout

    override func layoutSubviews() {
        super.layoutSubviews()
        let b = bounds
        let inset: CGFloat = 56

        stickCenter = CGPoint(x: b.maxX - inset - stickRadius, y: b.maxY - inset - stickRadius)
        fireCenter = CGPoint(x: stickCenter.x - stickRadius - fireRadius - 36, y: b.maxY - inset - fireRadius)
        // AIM sits above FIRE; VIEW sits above the throttle on the left.
        aimCenter = CGPoint(x: fireCenter.x, y: fireCenter.y - fireRadius - aimRadius - 30)
        throttleRect = CGRect(x: inset, y: b.maxY - inset - throttleSize.height,
                              width: throttleSize.width, height: throttleSize.height)
        viewCenter = CGPoint(x: throttleRect.midX, y: throttleRect.minY - viewRadius - 34)

        stickBase.path = UIBezierPath(ovalIn: circleRect(stickCenter, stickRadius)).cgPath
        positionKnob(.zero)

        throttleTrack.path = UIBezierPath(roundedRect: throttleRect, cornerRadius: throttleSize.width / 2).cgPath
        updateThrottleVisual()

        fireRing.path = UIBezierPath(ovalIn: circleRect(fireCenter, fireRadius)).cgPath
        aimRing.path = UIBezierPath(ovalIn: circleRect(aimCenter, aimRadius)).cgPath
        viewRing.path = UIBezierPath(ovalIn: circleRect(viewCenter, viewRadius)).cgPath
        fireLabel.frame = CGRect(x: fireCenter.x - 40, y: fireCenter.y - 11, width: 80, height: 22)
        aimLabel.frame = CGRect(x: aimCenter.x - 40, y: aimCenter.y - 11, width: 80, height: 22)
        viewLabel.frame = CGRect(x: viewCenter.x - 40, y: viewCenter.y - 11, width: 80, height: 22)

        crosshair.path = crosshairPath(center: CGPoint(x: b.midX, y: b.midY))

        // Labels.
        speedLabel.frame = CGRect(x: 40, y: 34, width: 260, height: 28)
        altLabel.frame = CGRect(x: 40, y: 66, width: 260, height: 28)
        healthLabel.frame = CGRect(x: b.maxX - 300, y: 34, width: 260, height: 28)
        healthLabel.textAlignment = .right
        enemiesLabel.frame = CGRect(x: b.maxX - 300, y: 66, width: 260, height: 28)
        enemiesLabel.textAlignment = .right
        banner.frame = CGRect(x: b.midX - 320, y: b.midY - 140, width: 640, height: 48)
        hint.frame = CGRect(x: b.midX - 300, y: 24, width: 600, height: 20)
    }

    private func circleRect(_ c: CGPoint, _ r: CGFloat) -> CGRect {
        CGRect(x: c.x - r, y: c.y - r, width: r * 2, height: r * 2)
    }

    private func crosshairPath(center c: CGPoint) -> CGPath {
        let p = UIBezierPath()
        let gap: CGFloat = 8, len: CGFloat = 18
        p.move(to: CGPoint(x: c.x - gap - len, y: c.y)); p.addLine(to: CGPoint(x: c.x - gap, y: c.y))
        p.move(to: CGPoint(x: c.x + gap, y: c.y)); p.addLine(to: CGPoint(x: c.x + gap + len, y: c.y))
        p.move(to: CGPoint(x: c.x, y: c.y - gap - len)); p.addLine(to: CGPoint(x: c.x, y: c.y - gap))
        p.move(to: CGPoint(x: c.x, y: c.y + gap)); p.addLine(to: CGPoint(x: c.x, y: c.y + gap + len))
        p.append(UIBezierPath(ovalIn: circleRect(c, 3)))
        return p.cgPath
    }

    private func positionKnob(_ offset: CGPoint) {
        let c = CGPoint(x: stickCenter.x + offset.x, y: stickCenter.y + offset.y)
        CATransaction.begin(); CATransaction.setDisableActions(true)
        stickKnob.path = UIBezierPath(ovalIn: circleRect(c, knobRadius)).cgPath
        CATransaction.commit()
    }

    private func updateThrottleVisual() {
        let h = throttleRect.height * CGFloat(throttle)
        let fillRect = CGRect(x: throttleRect.minX, y: throttleRect.maxY - h,
                              width: throttleRect.width, height: h)
        CATransaction.begin(); CATransaction.setDisableActions(true)
        throttleFill.path = UIBezierPath(roundedRect: fillRect, cornerRadius: throttleSize.width / 2).cgPath
        let knobY = throttleRect.maxY - h
        let kc = CGPoint(x: throttleRect.midX, y: knobY)
        throttleKnob.path = UIBezierPath(ovalIn: circleRect(kc, throttleSize.width / 2 + 4)).cgPath
        CATransaction.commit()
    }

    // MARK: Public readout API

    func setReadouts(speedKt: Int, altitudeFt: Int, health: Int, enemies: Int) {
        speedLabel.text = "SPD  \(speedKt) kt"
        altLabel.text = "ALT  \(altitudeFt) ft"
        healthLabel.text = "HULL  \(health)%"
        healthLabel.textColor = health < 30
            ? UIColor(red: 1, green: 0.4, blue: 0.35, alpha: 1) : .white
        enemiesLabel.text = "BANDITS  \(enemies)"
    }

    func showBanner(_ text: String, color: UIColor = .white, persist: Bool = false) {
        banner.text = text
        banner.textColor = color
        banner.layer.removeAllAnimations()
        banner.alpha = 1
        if !persist {
            UIView.animate(withDuration: 0.6, delay: 1.2, options: []) {
                self.banner.alpha = 0
            }
        }
    }

    func hideBanner() {
        banner.layer.removeAllAnimations()
        banner.alpha = 0
    }

    // MARK: Touch handling

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        for t in touches {
            let p = t.location(in: self)
            let key = t.hash
            if distance(p, fireCenter) <= fireRadius + 10 {
                assignments[key] = .fire
                firing = true
                pulse(fireRing)
            } else if distance(p, aimCenter) <= aimRadius + 10 {
                assignments[key] = .aim
                aiming = true
                aimRing.fillColor = UIColor(red: 1.0, green: 0.82, blue: 0.20, alpha: 0.55).cgColor
            } else if distance(p, viewCenter) <= viewRadius + 10 {
                assignments[key] = .view
                pulse(viewRing)
                onToggleView?()
            } else if throttleRect.insetBy(dx: -40, dy: -40).contains(p) {
                assignments[key] = .throttle
                updateThrottle(p)
            } else if p.x > bounds.midX {
                // Right half → stick (re-centre the stick under the thumb is nicer, but
                // we keep a fixed base for predictability).
                assignments[key] = .stick
                updateStick(p)
            }
        }
    }

    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
        for t in touches {
            guard let control = assignments[t.hash] else { continue }
            let p = t.location(in: self)
            switch control {
            case .stick: updateStick(p)
            case .throttle: updateThrottle(p)
            case .fire, .aim, .view: break
            }
        }
    }

    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) { endTouches(touches) }
    override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) { endTouches(touches) }

    private func endTouches(_ touches: Set<UITouch>) {
        for t in touches {
            guard let control = assignments[t.hash] else { continue }
            switch control {
            case .stick:
                rollInput = 0; pitchInput = 0; positionKnob(.zero)
            case .fire:
                firing = false
            case .aim:
                aiming = false
                aimRing.fillColor = UIColor(red: 1.0, green: 0.82, blue: 0.20, alpha: 0.24).cgColor
            case .throttle, .view:
                break
            }
            assignments[t.hash] = nil
        }
    }

    private func updateStick(_ p: CGPoint) {
        var dx = p.x - stickCenter.x
        var dy = p.y - stickCenter.y
        let dist = max(0.0001, hypot(dx, dy))
        if dist > stickRadius {
            dx = dx / dist * stickRadius
            dy = dy / dist * stickRadius
        }
        positionKnob(CGPoint(x: dx, y: dy))
        rollInput = Float(dx / stickRadius)
        pitchInput = Float(dy / stickRadius) // drag down (positive dy) → nose up
    }

    private func updateThrottle(_ p: CGPoint) {
        let clampedY = min(max(p.y, throttleRect.minY), throttleRect.maxY)
        throttle = Float(1 - (clampedY - throttleRect.minY) / throttleRect.height)
        updateThrottleVisual()
    }

    private func pulse(_ layer: CAShapeLayer) {
        let a = CABasicAnimation(keyPath: "opacity")
        a.fromValue = 1; a.toValue = 0.5; a.duration = 0.12
        a.autoreverses = true
        layer.add(a, forKey: "pulse")
    }

    private func distance(_ a: CGPoint, _ b: CGPoint) -> CGFloat { hypot(a.x - b.x, a.y - b.y) }
}

// MARK: - Styled label

final class HUDLabel: UILabel {
    init(size: CGFloat = 19, weight: UIFont.Weight = .semibold) {
        super.init(frame: .zero)
        font = UIFont.monospacedDigitSystemFont(ofSize: size, weight: weight)
        textColor = .white
        shadowColor = UIColor(white: 0, alpha: 0.6)
        shadowOffset = CGSize(width: 0, height: 1)
        text = ""
    }
    required init?(coder: NSCoder) { fatalError() }
}
