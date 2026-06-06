//
//  PlayerAircraft.swift
//  Dogfight Adventures
//
//  Kid-friendly "easy fly" flight model: the stick steers (turn left/right) and
//  climbs/dives directly. The plane CANNOT spin or flip — it banks just a little
//  into turns for looks and always levels back out. Pitch is limited so you
//  can't loop or nose-dive. Forward axis is -Z.
//

import SceneKit
import simd

final class PlayerAircraft {

    let node: SCNNode

    // Kinematic state.
    private(set) var position: V3
    private var yaw: Float          // heading (radians)
    private var pitchAngle: Float   // up/down (radians, clamped)
    private var bankAngle: Float    // cosmetic roll into turns
    private(set) var orientation: simd_quatf
    private(set) var speed: Float

    // Control inputs (set by the HUD each frame).
    var pitchInput: Float = 0   // -1 (nose down) ... +1 (nose up)
    var rollInput: Float = 0    // -1 (turn left) ... +1 (turn right)
    var throttle: Float = 0.6   // 0 ... 1

    // Tuning — gentle and forgiving.
    let minSpeed: Float = 55
    let maxSpeed: Float = 230
    private let turnRate: Float = 0.9    // rad/s at full stick (~51°/s)
    private let maxPitch: Float = 0.55   // ~31° climb/dive limit (no loops)
    private let maxBank: Float = 0.45    // ~26° cosmetic bank
    let minAltitude: Float = 60
    let maxAltitude: Float = 6000

    // Combat.
    var health: Float = 100
    var isAlive: Bool { health > 0 }

    init(spawn: V3, heading: simd_quatf) {
        self.position = spawn
        // Derive starting heading (yaw) from the spawn orientation's forward.
        let f = heading.forward
        self.yaw = atan2(-f.x, -f.z)
        self.pitchAngle = 0
        self.bankAngle = 0
        self.speed = 130
        self.orientation = simd_quatf(angle: yaw, axis: WORLD_UP)
        self.node = AircraftFactory.makeJet(
            bodyColor: UIColor(red: 0.55, green: 0.58, blue: 0.62, alpha: 1),
            accent: UIColor(red: 0.20, green: 0.45, blue: 0.75, alpha: 1))
        self.node.name = "player"
        self.node.simdPosition = position
        self.node.simdOrientation = orientation
    }

    var forward: V3 { orientation.forward }
    var velocity: V3 { orientation.forward * speed }

    func update(dt: Float) {
        guard isAlive else { return }

        // Steering: stick left/right turns the heading directly (no rolling over).
        yaw += -rollInput * turnRate * dt

        // Climb/dive: ease pitch toward the stick, hard-limited so you can't loop.
        let targetPitch = clampf(pitchInput, -1, 1) * maxPitch
        pitchAngle = lerp(pitchAngle, targetPitch, clampf(4 * dt, 0, 1))

        // Cosmetic bank into the turn, always easing back to level.
        let targetBank = -clampf(rollInput, -1, 1) * maxBank
        bankAngle = lerp(bankAngle, targetBank, clampf(5 * dt, 0, 1))

        // Build orientation: heading * pitch * (cosmetic) bank.
        let qYaw = simd_quatf(angle: yaw, axis: WORLD_UP)
        let qPitch = simd_quatf(angle: pitchAngle, axis: V3(1, 0, 0))
        let qBank = simd_quatf(angle: bankAngle, axis: V3(0, 0, 1))
        orientation = simd_normalize(qYaw * qPitch * qBank)

        // Airspeed from throttle.
        let targetSpeed = lerp(minSpeed, maxSpeed, clampf(throttle, 0, 1))
        speed = lerp(speed, targetSpeed, clampf(2.0 * dt, 0, 1))

        position += orientation.forward * speed * dt

        // Keep above the ground and below the ceiling.
        if position.y < minAltitude { position.y = minAltitude }
        if position.y > maxAltitude { position.y = maxAltitude }

        node.simdPosition = position
        node.simdOrientation = orientation
    }

    func takeDamage(_ amount: Float) {
        health = max(0, health - amount)
    }
}
