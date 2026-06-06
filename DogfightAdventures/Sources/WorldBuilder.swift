//
//  WorldBuilder.swift
//  Dogfight Adventures
//
//  Procedurally builds a stylized — but recognizable — San Francisco Bay Area:
//  the bay, the headlands, downtown skyline, and the signature landmarks
//  (Golden Gate Bridge, Bay Bridge, Transamerica Pyramid, Salesforce Tower,
//  Alcatraz). Geometry is built from SceneKit primitives so the project has
//  zero binary-asset dependencies and stays light on the build.
//
//  Marketplace .usdz/.dae city assets (Sketchfab / TurboSquid) can be dropped
//  into Resources/ and loaded here in place of `buildLandmarks()` later — the
//  rest of the game references nothing in this file except `build(into:)`.
//

import SceneKit
import UIKit

enum WorldBuilder {

    // MARK: Public

    /// Builds the entire world into `scene` and returns the player's spawn transform.
    @discardableResult
    static func build(into scene: SCNScene) -> (position: V3, heading: simd_quatf) {
        configureEnvironment(scene)
        addLighting(scene)
        scene.rootNode.addChildNode(buildBay())
        scene.rootNode.addChildNode(buildLandmasses())
        scene.rootNode.addChildNode(buildLandmarks())

        // Spawn south of downtown, a few hundred metres up, facing north (-Z) toward the city.
        let spawnPos = V3(0, 450, 2600)
        let heading = simd_quatf(angle: 0, axis: WORLD_UP) // forward is -Z
        return (spawnPos, heading)
    }

    // MARK: Environment

    private static func configureEnvironment(_ scene: SCNScene) {
        // Sky gradient.
        scene.background.contents = skyGradient()

        // Atmospheric haze so distant terrain fades — also hides the world edge.
        scene.fogStartDistance = 2500
        scene.fogEndDistance = 14000
        scene.fogDensityExponent = 1.4
        scene.fogColor = UIColor(red: 0.74, green: 0.82, blue: 0.90, alpha: 1.0)
    }

    private static func skyGradient() -> UIImage {
        let size = CGSize(width: 4, height: 256)
        let renderer = UIGraphicsImageRenderer(size: size)
        return renderer.image { ctx in
            let colors = [
                UIColor(red: 0.36, green: 0.58, blue: 0.86, alpha: 1).cgColor, // top
                UIColor(red: 0.74, green: 0.85, blue: 0.95, alpha: 1).cgColor  // horizon
            ] as CFArray
            let space = CGColorSpaceCreateDeviceRGB()
            let grad = CGGradient(colorsSpace: space, colors: colors, locations: [0, 1])!
            ctx.cgContext.drawLinearGradient(grad,
                                             start: CGPoint(x: 0, y: 0),
                                             end: CGPoint(x: 0, y: size.height),
                                             options: [])
        }
    }

    private static func addLighting(_ scene: SCNScene) {
        let sun = SCNNode()
        sun.light = SCNLight()
        sun.light!.type = .directional
        sun.light!.color = UIColor(white: 1.0, alpha: 1.0)
        sun.light!.intensity = 1100
        sun.light!.castsShadow = true
        sun.light!.shadowMode = .deferred
        sun.light!.shadowSampleCount = 8
        sun.light!.shadowColor = UIColor(white: 0, alpha: 0.35)
        sun.eulerAngles = SCNVector3(-Float.pi / 3.2, Float.pi / 5, 0)
        scene.rootNode.addChildNode(sun)

        let ambient = SCNNode()
        ambient.light = SCNLight()
        ambient.light!.type = .ambient
        ambient.light!.intensity = 420
        ambient.light!.color = UIColor(red: 0.62, green: 0.68, blue: 0.78, alpha: 1)
        scene.rootNode.addChildNode(ambient)
    }

    // MARK: Geometry helpers

    private static func box(_ w: Float, _ h: Float, _ l: Float,
                            color: UIColor, chamfer: Float = 0,
                            roughness: CGFloat = 0.8) -> SCNNode {
        let g = SCNBox(width: CGFloat(w), height: CGFloat(h), length: CGFloat(l),
                       chamferRadius: CGFloat(chamfer))
        let m = SCNMaterial()
        m.diffuse.contents = color
        m.roughness.contents = roughness
        m.metalness.contents = 0.0
        g.firstMaterial = m
        return SCNNode(geometry: g)
    }

    private static func cylinder(radius: Float, height: Float, color: UIColor) -> SCNNode {
        let g = SCNCylinder(radius: CGFloat(radius), height: CGFloat(height))
        let m = SCNMaterial()
        m.diffuse.contents = color
        m.roughness.contents = 0.85
        g.firstMaterial = m
        return SCNNode(geometry: g)
    }

    // MARK: Bay water

    private static func buildBay() -> SCNNode {
        let plane = SCNFloor()
        plane.reflectivity = 0.08
        plane.width = 30000
        plane.length = 30000
        let m = SCNMaterial()
        m.diffuse.contents = UIColor(red: 0.10, green: 0.27, blue: 0.42, alpha: 1)
        m.roughness.contents = 0.25
        m.metalness.contents = 0.0
        m.specular.contents = UIColor(white: 0.6, alpha: 1)
        plane.firstMaterial = m
        let node = SCNNode(geometry: plane)
        node.name = "bay"
        node.position = SCNVector3(0, 0, 0)
        return node
    }

    // MARK: Landmasses (peninsula, Marin, East Bay, hills)

    private static func buildLandmasses() -> SCNNode {
        let root = SCNNode()
        root.name = "land"

        let landColor = UIColor(red: 0.42, green: 0.50, blue: 0.30, alpha: 1)
        let hillColor = UIColor(red: 0.46, green: 0.53, blue: 0.33, alpha: 1)

        func landmass(_ x: Float, _ z: Float, _ w: Float, _ l: Float, h: Float = 18) {
            let n = box(w, h, l, color: landColor, chamfer: 6, roughness: 0.95)
            n.position = SCNVector3(x, h / 2 + 1, z)
            root.addChildNode(n)
        }

        func hill(_ x: Float, _ z: Float, radius: Float, height: Float) {
            let g = SCNCone(topRadius: 0, bottomRadius: CGFloat(radius), height: CGFloat(height))
            let m = SCNMaterial()
            m.diffuse.contents = hillColor
            m.roughness.contents = 0.95
            g.firstMaterial = m
            let n = SCNNode(geometry: g)
            n.position = SCNVector3(x, height / 2, z)
            root.addChildNode(n)
        }

        // SF peninsula (downtown sits near origin, city extends south).
        landmass(0, 1600, 2600, 5200)
        // Marin headlands to the north.
        landmass(-600, -2600, 3400, 2600, h: 26)
        // East Bay.
        landmass(3400, 400, 2600, 6000, h: 22)

        // Hills for relief.
        hill(-300, 900, radius: 420, height: 280)   // Twin Peaks-ish
        hill(-1500, -2600, radius: 700, height: 520) // Marin headland
        hill(-900, -2400, radius: 500, height: 360)
        hill(3600, -900, radius: 600, height: 440)   // East Bay hills
        hill(3500, 1800, radius: 650, height: 480)

        return root
    }

    // MARK: Landmarks

    private static func buildLandmarks() -> SCNNode {
        let root = SCNNode()
        root.name = "landmarks"

        root.addChildNode(downtownSkyline())
        root.addChildNode(transamericaPyramid(at: V3(-40, 0, 120)))
        root.addChildNode(salesforceTower(at: V3(140, 0, 260)))
        root.addChildNode(goldenGateBridge(at: V3(-1700, 0, -1500)))
        root.addChildNode(bayBridge(at: V3(1700, 0, 300)))
        root.addChildNode(alcatraz(at: V3(-150, 0, -1400)))

        return root
    }

    private static func downtownSkyline() -> SCNNode {
        let root = SCNNode()
        root.name = "downtown"
        // A deterministic cluster of office towers around the financial district.
        let glass = UIColor(red: 0.55, green: 0.62, blue: 0.68, alpha: 1)
        let glass2 = UIColor(red: 0.62, green: 0.66, blue: 0.70, alpha: 1)
        let layout: [(Float, Float, Float, Float)] = [
            // x, z, footprint, height
            (-120, 60, 46, 150), (-60, 30, 40, 120), (10, 80, 52, 180),
            (70, 40, 44, 130), (130, 90, 48, 165), (-40, 180, 40, 110),
            (40, 200, 46, 140), (-160, 160, 38, 95), (110, 220, 42, 125),
            (-100, 300, 50, 160), (30, 320, 44, 135), (180, 180, 40, 105),
            (-200, 80, 36, 88), (200, 60, 38, 100), (-30, -40, 42, 115)
        ]
        for (i, t) in layout.enumerated() {
            let n = box(t.2, t.3, t.2, color: i % 2 == 0 ? glass : glass2,
                        chamfer: 1.5, roughness: 0.5)
            n.position = SCNVector3(t.0, t.3 / 2, t.1)
            root.addChildNode(n)
        }
        return root
    }

    private static func transamericaPyramid(at p: V3) -> SCNNode {
        let root = SCNNode()
        root.name = "transamerica"
        let height: Float = 260
        let g = SCNPyramid(width: 52, height: CGFloat(height), length: 52)
        let m = SCNMaterial()
        m.diffuse.contents = UIColor(red: 0.86, green: 0.86, blue: 0.84, alpha: 1)
        m.roughness.contents = 0.6
        g.firstMaterial = m
        let n = SCNNode(geometry: g)
        n.position = SCNVector3(p.x, 0, p.z)
        root.addChildNode(n)
        return root
    }

    private static func salesforceTower(at p: V3) -> SCNNode {
        let root = SCNNode()
        root.name = "salesforce"
        let height: Float = 326
        // Tapered rounded tower.
        let g = SCNTube(innerRadius: 0, outerRadius: 24, height: CGFloat(height))
        let m = SCNMaterial()
        m.diffuse.contents = UIColor(red: 0.66, green: 0.72, blue: 0.78, alpha: 1)
        m.roughness.contents = 0.4
        m.metalness.contents = 0.2
        g.firstMaterial = m
        let n = SCNNode(geometry: g)
        n.position = SCNVector3(p.x, height / 2, p.z)
        n.scale = SCNVector3(1.0, 1.0, 1.0)
        root.addChildNode(n)
        // Tapered cap.
        let cap = SCNNode(geometry: SCNCone(topRadius: 4, bottomRadius: 24, height: 60))
        cap.geometry!.firstMaterial = m
        cap.position = SCNVector3(p.x, height + 30, p.z)
        root.addChildNode(cap)
        return root
    }

    private static func goldenGateBridge(at p: V3) -> SCNNode {
        let root = SCNNode()
        root.name = "golden_gate"
        let orange = UIColor(red: 0.78, green: 0.30, blue: 0.18, alpha: 1) // International Orange
        let span: Float = 1280
        let towerH: Float = 230
        let deckH: Float = 70

        // Deck.
        let deck = box(36, 6, span, color: UIColor(red: 0.32, green: 0.18, blue: 0.14, alpha: 1))
        deck.position = SCNVector3(p.x, deckH, p.z)
        root.addChildNode(deck)

        // Two towers.
        for dz in [-span * 0.32, span * 0.32] {
            let tower = box(20, towerH, 20, color: orange, chamfer: 1)
            tower.position = SCNVector3(p.x, towerH / 2, p.z + dz)
            root.addChildNode(tower)
            // Cross-beams.
            for y in [towerH * 0.55, towerH * 0.85] {
                let beam = box(20, 8, 8, color: orange)
                beam.position = SCNVector3(p.x, y, p.z + dz)
                root.addChildNode(beam)
            }
        }

        // Main suspension cables (approximated as angled cylinders from tower tops to deck ends).
        let towerTopY = towerH
        func cable(from a: V3, to b: V3) {
            let mid = (a + b) * 0.5
            let dir = b - a
            let len = dir.length
            let c = cylinder(radius: 1.4, height: len, color: orange)
            c.position = SCNVector3(mid)
            // Align cylinder's local +Y with `dir`.
            let up = V3(0, 1, 0)
            let q = simd_quatf(from: up, to: dir.normalizedSafe)
            c.simdOrientation = q
            root.addChildNode(c)
        }
        let tA = V3(p.x, towerTopY, p.z - span * 0.32)
        let tB = V3(p.x, towerTopY, p.z + span * 0.32)
        let endN = V3(p.x, deckH + 6, p.z - span * 0.5)
        let endS = V3(p.x, deckH + 6, p.z + span * 0.5)
        cable(from: endN, to: tA)
        cable(from: tA, to: tB)
        cable(from: tB, to: endS)

        return root
    }

    private static func bayBridge(at p: V3) -> SCNNode {
        let root = SCNNode()
        root.name = "bay_bridge"
        let grey = UIColor(red: 0.72, green: 0.74, blue: 0.76, alpha: 1)
        let span: Float = 1400
        let towerH: Float = 160
        let deckH: Float = 60

        let deck = box(28, 5, span, color: UIColor(white: 0.5, alpha: 1))
        deck.position = SCNVector3(p.x, deckH, p.z)
        deck.eulerAngles = SCNVector3(0, Float.pi / 2, 0) // run east-west
        root.addChildNode(deck)

        for dx in [-span * 0.3, 0, span * 0.3] {
            let tower = box(16, towerH, 16, color: grey, chamfer: 1)
            tower.position = SCNVector3(p.x + dx, towerH / 2, p.z)
            root.addChildNode(tower)
        }
        return root
    }

    private static func alcatraz(at p: V3) -> SCNNode {
        let root = SCNNode()
        root.name = "alcatraz"
        // Rocky island.
        let island = cylinder(radius: 90, height: 30,
                              color: UIColor(red: 0.45, green: 0.44, blue: 0.40, alpha: 1))
        island.position = SCNVector3(p.x, 14, p.z)
        root.addChildNode(island)
        // Main cellhouse building.
        let bldg = box(110, 26, 40, color: UIColor(white: 0.78, alpha: 1), chamfer: 1)
        bldg.position = SCNVector3(p.x, 30 + 13, p.z)
        root.addChildNode(bldg)
        // Lighthouse.
        let light = cylinder(radius: 5, height: 40, color: UIColor.white)
        light.position = SCNVector3(p.x + 40, 30 + 20, p.z - 10)
        root.addChildNode(light)
        return root
    }
}
