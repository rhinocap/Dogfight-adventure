//
//  PlayerAircraft.swift
//  Dogfight Adventures
//
//  Quaternion-based arcade flight model tuned for touchscreen play:
//  stick = pitch + roll, banking induces a coordinated turn, throttle sets
//  airspeed. Forward axis is -Z.
//

import SceneKit
import simd

final class PlayerAircraft {

    let node: SCNNode

    // Kinematic state.
    private(set) var position: V3
    private(set) var orientation: simd_quatf
    private(set) var speed: Float

    // Control inputs (set by the HUD each frame).
    var pitchInput: Float = 0   // -1 (nose down) ... +1 (nose up)
    var rollInput: Float = 0    // -1 (roll left) ... +1 (roll right)
    var throttle: Float = 0.6   // 0 ... 1

    // Tuning.
    let minSpeed: Float = 55
    let maxSpeed: Float = 240
    private let pitchRate: Float = 1.5   // rad/s at full input
    private let rollRate: Float = 2.6
    private let turnFactor: Float = 1.7  // bank → yaw coupling
    let minAltitude: Float = 12
    let maxAltitude: Float = 5000

    // Combat.
    var health: Float = 100
    var isAlive: Bool { health > 0 }

    init(spawn: V3, heading: simd_quatf) {
        self.position = spawn
        self.orientation = heading
        self.speed = 130
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

        let right = orientation.right
        let fwd = orientation.forward

        // Pitch about local right axis, roll about local forward axis.
        let qPitch = simd_quatf(angle: pitchInput * pitchRate * dt, axis: right)
        let qRoll = simd_quatf(angle: -rollInput * rollRate * dt, axis: fwd)
        orientation = simd_normalize(qRoll * qPitch * orientation)

        // Coordinated turn: a right bank dips the right wing (right·up < 0) and
        // should yaw the nose right (negative yaw about world up).
        let bank = simd_dot(orientation.right, WORLD_UP)
        let qYaw = simd_quatf(angle: bank * turnFactor * dt, axis: WORLD_UP)
        orientation = simd_normalize(qYaw * orientation)

        // Airspeed from throttle, with a touch of gravity sag when climbing.
        let targetSpeed = lerp(minSpeed, maxSpeed, clampf(throttle, 0, 1))
        speed = lerp(speed, targetSpeed, clampf(2.0 * dt, 0, 1))

        position += orientation.forward * speed * dt

        // Keep above the bay and below the ceiling; flatten climb at limits.
        if position.y < minAltitude { position.y = minAltitude }
        if position.y > maxAltitude { position.y = maxAltitude }

        node.simdPosition = position
        node.simdOrientation = orientation
    }

    func takeDamage(_ amount: Float) {
        health = max(0, health - amount)
    }
}
