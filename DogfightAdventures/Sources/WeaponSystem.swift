//
//  WeaponSystem.swift
//  Dogfight Adventures
//
//  Lightweight projectile manager. Bullets are integrated manually (no physics
//  engine) and hit-tested by distance against the player or the live enemies.
//

import SceneKit
import simd

final class WeaponSystem {

    private struct Projectile {
        let node: SCNNode
        var position: V3
        let velocity: V3
        var life: Float
        let friendly: Bool   // true = fired by player, hits enemies
        let damage: Float
    }

    private let root: SCNNode
    private var projectiles: [Projectile] = []
    private let projectileSpeed: Float = 650
    private let lifeSpan: Float = 2.2

    init(root: SCNNode) {
        self.root = root
    }

    // MARK: Spawning

    func fire(from origin: V3, dir: V3, inheritedVelocity: V3, friendly: Bool, damage: Float) {
        let color: UIColor = friendly
            ? UIColor(red: 1.0, green: 0.95, blue: 0.4, alpha: 1)
            : UIColor(red: 1.0, green: 0.35, blue: 0.25, alpha: 1)
        let node = makeTracer(color: color)
        node.simdPosition = origin
        // Orient tracer along travel direction.
        node.simdOrientation = simd_quatf(from: V3(0, 1, 0), to: dir.normalizedSafe)
        root.addChildNode(node)

        let vel = dir.normalizedSafe * projectileSpeed + inheritedVelocity
        projectiles.append(Projectile(node: node, position: origin, velocity: vel,
                                      life: lifeSpan, friendly: friendly, damage: damage))
    }

    private func makeTracer(color: UIColor) -> SCNNode {
        let g = SCNCapsule(capRadius: 0.35, height: 6)
        let m = SCNMaterial()
        m.diffuse.contents = color
        m.emission.contents = color
        m.lightingModel = .constant
        g.firstMaterial = m
        return SCNNode(geometry: g)
    }

    // MARK: Update + collision

    struct HitResult {
        var playerDamage: Float = 0
        var enemyHits: [(index: Int, damage: Float, point: V3)] = []
    }

    /// Advances all projectiles and resolves hits.
    func update(dt: Float, player: PlayerAircraft, enemies: [EnemyAircraft]) -> HitResult {
        var result = HitResult()
        let playerHitR: Float = 9
        let enemyHitR: Float = 9

        var survivors: [Projectile] = []
        survivors.reserveCapacity(projectiles.count)

        for var p in projectiles {
            p.position += p.velocity * dt
            p.life -= dt
            p.node.simdPosition = p.position

            var consumed = false

            if p.life <= 0 || p.position.y < 1 {
                consumed = true
            } else if p.friendly {
                for (i, e) in enemies.enumerated() where e.isAlive {
                    if simd_distance(p.position, e.position) < enemyHitR {
                        result.enemyHits.append((i, p.damage, p.position))
                        consumed = true
                        break
                    }
                }
            } else {
                if player.isAlive, simd_distance(p.position, player.position) < playerHitR {
                    result.playerDamage += p.damage
                    consumed = true
                }
            }

            if consumed {
                p.node.removeFromParentNode()
            } else {
                survivors.append(p)
            }
        }
        projectiles = survivors
        return result
    }

    func reset() {
        for p in projectiles { p.node.removeFromParentNode() }
        projectiles.removeAll()
    }
}
