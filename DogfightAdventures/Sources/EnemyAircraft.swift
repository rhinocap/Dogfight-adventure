//
//  EnemyAircraft.swift
//  Dogfight Adventures
//
//  Simple pursue-and-shoot AI opponent. Steers its heading toward the player,
//  holds a sane altitude, and fires when the player is roughly in front and in
//  range. Intentionally beatable — MVP combat.
//

import SceneKit
import simd

final class EnemyAircraft {

    let node: SCNNode
    private(set) var position: V3
    private(set) var orientation: simd_quatf

    private let speed: Float
    private let turnSpeed: Float = 0.9       // how fast it can swing its nose (rad/s-ish)
    private let fireRange: Float = 900
    private let fireConeCos: Float = 0.95    // ~18° half-angle
    private var fireCooldown: Float = 0

    var health: Float = 60
    var isAlive: Bool { health > 0 }

    init(spawn: V3) {
        self.position = spawn
        self.orientation = simd_quatf(angle: 0, axis: WORLD_UP)
        self.speed = Float.random(in: 95...130)
        self.node = AircraftFactory.makeJet(
            bodyColor: UIColor(red: 0.55, green: 0.18, blue: 0.16, alpha: 1),
            accent: UIColor(red: 0.85, green: 0.30, blue: 0.20, alpha: 1))
        self.node.name = "enemy"
        self.node.simdPosition = position
        self.node.simdOrientation = orientation
    }

    var forward: V3 { orientation.forward }

    /// Returns a fire request (muzzle position + direction) if the AI shoots this frame.
    func update(dt: Float, playerPos: V3) -> (origin: V3, dir: V3)? {
        guard isAlive else { return nil }

        let toPlayer = playerPos - position
        let dist = toPlayer.length
        let dir = toPlayer.normalizedSafe

        // Steer heading toward the player, rate-limited via slerp.
        if dir.length > 0.5 {
            let desired = simd_quatf(from: V3(0, 0, -1), to: dir)
            orientation = simd_slerp(orientation, desired, clampf(turnSpeed * dt, 0, 1))
        }

        // Don't fly straight into the player; peel off if very close.
        var advance = orientation.forward * speed * dt
        if dist < 220 {
            advance += orientation.up * (40 * dt) // climb away
        }
        position += advance

        // Stay above terrain.
        if position.y < 80 { position.y = 80 }

        node.simdPosition = position
        node.simdOrientation = orientation

        // Firing logic.
        fireCooldown -= dt
        let aim = simd_dot(orientation.forward, dir)
        if fireCooldown <= 0, dist < fireRange, aim > fireConeCos {
            fireCooldown = Float.random(in: 0.7...1.4)
            let muzzle = position + orientation.forward * 9
            return (muzzle, orientation.forward)
        }
        return nil
    }

    func takeDamage(_ amount: Float) {
        health = max(0, health - amount)
    }
}
