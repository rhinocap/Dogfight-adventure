//
//  GameViewController.swift
//  Dogfight Adventures
//
//  Owns the SceneKit view, the world, the player, the AI flight, the weapons,
//  and the HUD. A CADisplayLink drives a fixed game loop on the main thread so
//  reading touch state and mutating nodes is race-free.
//

import UIKit
import SceneKit
import simd

final class GameViewController: UIViewController {

    private let scnView = SCNView()
    private let scene = SCNScene()
    private let cameraNode = SCNNode()

    private var player: PlayerAircraft!
    private var enemies: [EnemyAircraft] = []
    private var weapons: WeaponSystem!
    private let hud = FlightHUD()

    private var displayLink: CADisplayLink?
    private var lastTime: CFTimeInterval = 0
    private var playerFireCooldown: Float = 0
    private var camPos = V3(0, 500, 3000)
    private var gameOver = false
    private var spawn: (position: V3, heading: simd_quatf) = (V3(0, 450, 2600), simd_quatf(angle: 0, axis: WORLD_UP))

    private let enemyTarget = 4
    private let playerDamage: Float = 14
    private let enemyDamage: Float = 7

    override var prefersStatusBarHidden: Bool { true }
    override var prefersHomeIndicatorAutoHidden: Bool { true }
    override var supportedInterfaceOrientations: UIInterfaceOrientationMask { .landscape }

    // MARK: Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()
        setupScene()
        setupCamera()
        setupGame()
        setupHUD()
        startLoop()
    }

    private func setupScene() {
        scnView.frame = view.bounds
        scnView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        scnView.scene = scene
        scnView.backgroundColor = .black
        scnView.antialiasingMode = .multisampling4X
        scnView.preferredFramesPerSecond = 60
        scnView.rendersContinuously = true
        view.addSubview(scnView)

        spawn = WorldBuilder.build(into: scene)
    }

    private func setupCamera() {
        let cam = SCNCamera()
        cam.zNear = 1
        cam.zFar = 30000          // covers the full 16km Bay world; fog hides the far edge
        cam.fieldOfView = 65
        cameraNode.camera = cam
        scene.rootNode.addChildNode(cameraNode)
        scnView.pointOfView = cameraNode
    }

    private func setupGame() {
        player = PlayerAircraft(spawn: spawn.position, heading: spawn.heading)
        scene.rootNode.addChildNode(player.node)

        weapons = WeaponSystem(root: scene.rootNode)
        spawnEnemies(enemyTarget)

        camPos = player.position - player.forward * 24 + WORLD_UP * 8
    }

    private func setupHUD() {
        hud.frame = view.bounds
        hud.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        view.addSubview(hud)
        hud.showBanner("DOGFIGHT — BAY AREA", color: .white)
    }

    // MARK: Enemies

    private func spawnEnemies(_ count: Int) {
        for _ in 0..<count { spawnOneEnemy() }
    }

    private func spawnOneEnemy() {
        let angle = Float.random(in: 0..<(2 * .pi))
        let radius = Float.random(in: 1400...2200)
        let offset = V3(cos(angle) * radius, Float.random(in: 250...850), sin(angle) * radius)
        let pos = player.position + offset
        let e = EnemyAircraft(spawn: V3(pos.x, max(150, pos.y), pos.z))
        enemies.append(e)
        scene.rootNode.addChildNode(e.node)
    }

    // MARK: Game loop

    private func startLoop() {
        let link = CADisplayLink(target: self, selector: #selector(step))
        link.preferredFrameRateRange = CAFrameRateRange(minimum: 30, maximum: 60, preferred: 60)
        link.add(to: .main, forMode: .common)
        displayLink = link
    }

    @objc private func step(_ link: CADisplayLink) {
        if lastTime == 0 { lastTime = link.timestamp; return }
        let dt = Float(min(0.05, link.timestamp - lastTime))
        lastTime = link.timestamp
        guard dt > 0 else { return }

        if !gameOver { updateGame(dt: dt) }
        updateCamera(dt: dt)
        updateReadouts()
    }

    private func updateGame(dt: Float) {
        // Feed controls into the player.
        player.rollInput = hud.rollInput
        player.pitchInput = hud.pitchInput
        player.throttle = hud.throttle
        player.update(dt: dt)

        // Player guns.
        playerFireCooldown -= dt
        if hud.firing, player.isAlive, playerFireCooldown <= 0 {
            playerFireCooldown = 0.11
            let muzzle = player.position + player.forward * 10
            weapons.fire(from: muzzle, dir: player.forward,
                         inheritedVelocity: player.velocity,
                         friendly: true, damage: playerDamage)
        }

        // Enemy AI.
        for e in enemies {
            if let shot = e.update(dt: dt, playerPos: player.position) {
                weapons.fire(from: shot.origin, dir: shot.dir,
                             inheritedVelocity: V3(0, 0, 0),
                             friendly: false, damage: enemyDamage)
            }
        }

        // Resolve projectiles.
        let hits = weapons.update(dt: dt, player: player, enemies: enemies)
        if hits.playerDamage > 0 {
            player.takeDamage(hits.playerDamage)
            flashDamage()
            if !player.isAlive { triggerGameOver() }
        }
        for h in hits.enemyHits where h.index < enemies.count {
            let e = enemies[h.index]
            e.takeDamage(h.damage)
            if !e.isAlive { destroyEnemy(e) }
        }

        // Cull dead enemies and keep the skies populated.
        enemies.removeAll { !$0.isAlive }
        while enemies.count < enemyTarget { spawnOneEnemy() }
    }

    private func destroyEnemy(_ e: EnemyAircraft) {
        spawnExplosion(at: e.position)
        e.node.removeFromParentNode()
        hud.showBanner("BANDIT DOWN", color: UIColor(red: 0.4, green: 1, blue: 0.6, alpha: 1))
    }

    private func spawnExplosion(at p: V3) {
        let n = SCNNode()
        n.simdPosition = p
        n.addParticleSystem(AircraftFactory.makeExplosion())
        scene.rootNode.addChildNode(n)
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) { n.removeFromParentNode() }
    }

    private func flashDamage() {
        let overlay = UIView(frame: view.bounds)
        overlay.backgroundColor = UIColor(red: 1, green: 0, blue: 0, alpha: 0.25)
        overlay.isUserInteractionEnabled = false
        overlay.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        view.insertSubview(overlay, belowSubview: hud)
        UIView.animate(withDuration: 0.3, animations: { overlay.alpha = 0 }) { _ in
            overlay.removeFromSuperview()
        }
    }

    // MARK: Camera (stable damped chase)

    private func updateCamera(dt: Float) {
        let back = -player.forward
        // Blend world-up with the aircraft's up so the camera banks a little but never rolls fully.
        let camUp = simd_normalize(lerp(WORLD_UP, player.orientation.up, 0.30))
        let desired = player.position + back * 24 + camUp * 8
        let k = clampf(6 * dt, 0, 1)
        camPos = lerp(camPos, desired, k)
        cameraNode.simdPosition = camPos
        let lookTarget = player.position + player.forward * 40
        cameraNode.look(at: SCNVector3(lookTarget), up: SCNVector3(camUp), localFront: SCNVector3(0, 0, -1))
    }

    // MARK: Readouts

    private func updateReadouts() {
        let speedKt = Int(player.speed * 1.94384)            // m/s → knots
        let altFt = Int(max(0, player.position.y) * 3.28084) // m → feet
        hud.setReadouts(speedKt: speedKt, altitudeFt: altFt,
                        health: Int(max(0, player.health)),
                        enemies: enemies.count)
    }

    // MARK: Game over / restart

    private func triggerGameOver() {
        gameOver = true
        spawnExplosion(at: player.position)
        player.node.isHidden = true
        hud.showBanner("AIRCRAFT DOWN — TAP TO RESPAWN",
                       color: UIColor(red: 1, green: 0.4, blue: 0.35, alpha: 1), persist: true)
        let tap = UITapGestureRecognizer(target: self, action: #selector(restart))
        view.addGestureRecognizer(tap)
        restartTap = tap
    }

    private var restartTap: UITapGestureRecognizer?

    @objc private func restart() {
        guard gameOver else { return }
        if let t = restartTap { view.removeGestureRecognizer(t); restartTap = nil }
        weapons.reset()
        enemies.forEach { $0.node.removeFromParentNode() }
        enemies.removeAll()

        let spawn = (position: V3(0, 450, 2600), heading: simd_quatf(angle: 0, axis: WORLD_UP))
        player.node.removeFromParentNode()
        player = PlayerAircraft(spawn: spawn.position, heading: spawn.heading)
        scene.rootNode.addChildNode(player.node)
        spawnEnemies(enemyTarget)
        camPos = player.position - player.forward * 24 + WORLD_UP * 8
        gameOver = false
        hud.hideBanner()
    }
}
