//
//  WorldBuilder.swift
//  Dogfight Adventures
//
//  Builds the world from REAL San Francisco Bay data:
//   - bay_heightmap.f32 : real elevations (Terrarium / AWS terrain tiles)
//   - bay_texture.jpg   : real satellite imagery (Esri World Imagery), draped
//   - bay_meta.json     : grid + geo mapping
//
//  The terrain is a custom SCNGeometry mesh; the bay is filled by a water plane
//  at sea level, so the real coastline emerges where land rises above 0 m.
//  Golden Gate + Bay Bridge are placed at their true lat/lon, scaled to size.
//
//  If the baked assets are missing, falls back to a simple procedural world.
//

import SceneKit
import UIKit
import Foundation
import simd

enum WorldBuilder {

    // World sizing.
    static let worldSize: Float = 16000          // world is 16km across
    static let elevationExaggeration: Float = 3.0

    private struct GeoMeta {
        let grid: Int
        let minElev, maxElev: Float
        let groundMeters: Double
        let z, x0, y0, nx: Int
        let mosaicW, mosaicH: Int
        var unitsPerMeter: Float { Float(Double(worldSize) / groundMeters) }
    }

    @discardableResult
    static func build(into scene: SCNScene) -> (position: V3, heading: simd_quatf) {
        configureEnvironment(scene)
        addLighting(scene)

        guard let (meta, heights) = loadBayData() else {
            return buildFallback(scene)
        }

        let unitsPerMeter = meta.unitsPerMeter
        let vScale = unitsPerMeter * elevationExaggeration

        scene.rootNode.addChildNode(buildTerrain(meta: meta, heights: heights, vScale: vScale))
        scene.rootNode.addChildNode(buildWater())

        // Landmarks at true positions, sized in real metres.
        let ggPos = geoToWorld(lon: -122.4783, lat: 37.8199, meta: meta)
        let bbPos = geoToWorld(lon: -122.3733, lat: 37.7983, meta: meta)
        scene.rootNode.addChildNode(goldenGate(at: ggPos, unitsPerMeter: unitsPerMeter))
        scene.rootNode.addChildNode(bayBridge(at: bbPos, unitsPerMeter: unitsPerMeter))

        // Spawn out over the Pacific, heading east straight through the Golden
        // Gate toward downtown SF — flies the player over the bridge into the bay.
        let spawn = geoToWorld(lon: -122.540, lat: 37.818, meta: meta)
        let target = geoToWorld(lon: -122.430, lat: 37.805, meta: meta)
        var dir = V3(target.x - spawn.x, 0, target.z - spawn.z).normalizedSafe
        if dir.length < 0.5 { dir = V3(0, 0, -1) }
        let heading = simd_quatf(from: V3(0, 0, -1), to: dir)
        return (V3(spawn.x, 900, spawn.z), heading)
    }

    // MARK: Asset loading

    private static func loadBayData() -> (GeoMeta, [Float])? {
        guard
            let metaURL = Bundle.main.url(forResource: "bay_meta", withExtension: "json"),
            let hURL = Bundle.main.url(forResource: "bay_heightmap", withExtension: "f32"),
            let metaData = try? Data(contentsOf: metaURL),
            let json = try? JSONSerialization.jsonObject(with: metaData) as? [String: Any],
            let hData = try? Data(contentsOf: hURL)
        else { return nil }

        func f(_ k: String) -> Float { (json[k] as? NSNumber)?.floatValue ?? 0 }
        func i(_ k: String) -> Int { (json[k] as? NSNumber)?.intValue ?? 0 }
        let meta = GeoMeta(
            grid: i("grid"), minElev: f("minElev"), maxElev: f("maxElev"),
            groundMeters: (json["groundMeters"] as? NSNumber)?.doubleValue ?? 23000,
            z: i("z"), x0: i("x0"), y0: i("y0"), nx: i("nx"),
            mosaicW: i("mosaicW"), mosaicH: i("mosaicH"))

        let count = meta.grid * meta.grid
        guard hData.count >= count * 4 else { return nil }
        var heights = [Float](repeating: 0, count: count)
        _ = heights.withUnsafeMutableBytes { hData.copyBytes(to: $0, count: count * 4) }
        return (meta, heights)
    }

    // MARK: Terrain mesh

    private static func buildTerrain(meta: GeoMeta, heights: [Float], vScale: Float) -> SCNNode {
        let g = meta.grid
        let cell = worldSize / Float(g - 1)
        let half = worldSize / 2

        @inline(__always) func y(_ r: Int, _ c: Int) -> Float {
            heights[r * g + c] * vScale
        }

        var verts = [SCNVector3](); verts.reserveCapacity(g * g)
        var norms = [SCNVector3](); norms.reserveCapacity(g * g)
        var uvs = [CGPoint](); uvs.reserveCapacity(g * g)

        for r in 0..<g {
            for c in 0..<g {
                let x = Float(c) * cell - half
                let z = Float(r) * cell - half
                verts.append(SCNVector3(x, y(r, c), z))
                uvs.append(CGPoint(x: CGFloat(c) / CGFloat(g - 1), y: CGFloat(r) / CGFloat(g - 1)))

                // Smooth normal from central differences.
                let hL = y(r, max(0, c - 1)), hR = y(r, min(g - 1, c + 1))
                let hU = y(max(0, r - 1), c), hD = y(min(g - 1, r + 1), c)
                let n = simd_normalize(V3(-(hR - hL) / (2 * cell), 1, -(hD - hU) / (2 * cell)))
                norms.append(SCNVector3(n))
            }
        }

        var idx = [Int32](); idx.reserveCapacity((g - 1) * (g - 1) * 6)
        for r in 0..<(g - 1) {
            for c in 0..<(g - 1) {
                let a = Int32(r * g + c), b = Int32(r * g + c + 1)
                let d = Int32((r + 1) * g + c), e = Int32((r + 1) * g + c + 1)
                idx.append(contentsOf: [a, d, b, b, d, e])
            }
        }

        let geo = SCNGeometry(sources: [
            SCNGeometrySource(vertices: verts),
            SCNGeometrySource(normals: norms),
            SCNGeometrySource(textureCoordinates: uvs),
        ], elements: [SCNGeometryElement(indices: idx, primitiveType: .triangles)])

        let m = SCNMaterial()
        if let texURL = Bundle.main.url(forResource: "bay_texture", withExtension: "jpg"),
           let img = UIImage(contentsOfFile: texURL.path) {
            m.diffuse.contents = img
        } else {
            m.diffuse.contents = UIColor(red: 0.42, green: 0.48, blue: 0.34, alpha: 1)
        }
        m.diffuse.wrapS = .clamp; m.diffuse.wrapT = .clamp
        m.roughness.contents = 0.95
        m.metalness.contents = 0.0
        geo.firstMaterial = m

        let node = SCNNode(geometry: geo)
        node.name = "terrain"
        node.castsShadow = false
        return node
    }

    // MARK: Water

    private static func buildWater() -> SCNNode {
        let plane = SCNFloor()
        plane.reflectivity = 0.06
        plane.width = CGFloat(worldSize * 2)
        plane.length = CGFloat(worldSize * 2)
        let m = SCNMaterial()
        m.diffuse.contents = UIColor(red: 0.09, green: 0.24, blue: 0.34, alpha: 0.86)
        m.roughness.contents = 0.2
        m.metalness.contents = 0.0
        m.specular.contents = UIColor(white: 0.8, alpha: 1)
        m.transparencyMode = .dualLayer
        plane.firstMaterial = m
        let node = SCNNode(geometry: plane)
        node.name = "water"
        node.position = SCNVector3(0, 0, 0)
        return node
    }

    // MARK: Geo → world mapping

    private static func geoToWorld(lon: Double, lat: Double, meta: GeoMeta) -> V3 {
        let n = pow(2.0, Double(meta.z))
        let tilex = (lon + 180.0) / 360.0 * n
        let rad = lat * .pi / 180.0
        let tiley = (1.0 - log(tan(rad) + 1.0 / cos(rad)) / .pi) / 2.0 * n
        let px = (tilex - Double(meta.x0)) * 256.0
        let py = (tiley - Double(meta.y0)) * 256.0
        let u = px / Double(meta.mosaicW)
        let v = py / Double(meta.mosaicH)
        let x = Float(u - 0.5) * worldSize
        let z = Float(v - 0.5) * worldSize
        return V3(x, 0, z)
    }

    // MARK: Landmarks (scaled to true metres)

    private static func box(_ w: Float, _ h: Float, _ l: Float, color: UIColor, chamfer: Float = 0) -> SCNNode {
        let g = SCNBox(width: CGFloat(w), height: CGFloat(h), length: CGFloat(l), chamferRadius: CGFloat(chamfer))
        let mat = SCNMaterial(); mat.diffuse.contents = color; mat.roughness.contents = 0.7
        g.firstMaterial = mat
        return SCNNode(geometry: g)
    }

    private static func goldenGate(at p: V3, unitsPerMeter upm: Float) -> SCNNode {
        // Real metres, then scale the whole node by unitsPerMeter.
        let root = SCNNode(); root.name = "golden_gate"
        let orange = UIColor(red: 0.78, green: 0.30, blue: 0.18, alpha: 1)
        let span: Float = 1280, towerH: Float = 227, deckH: Float = 67
        let deck = box(27, 6, span, color: UIColor(red: 0.30, green: 0.16, blue: 0.12, alpha: 1))
        deck.position = SCNVector3(0, deckH, 0); root.addChildNode(deck)
        for dz in [-span * 0.32, span * 0.32] {
            let t = box(18, towerH, 18, color: orange, chamfer: 1)
            t.position = SCNVector3(0, towerH / 2, dz); root.addChildNode(t)
        }
        // Suspension cables.
        func cable(_ a: V3, _ b: V3) {
            let mid = (a + b) * 0.5, dir = b - a, len = dir.length
            let cyl = SCNCylinder(radius: 1.5, height: CGFloat(len))
            let mt = SCNMaterial(); mt.diffuse.contents = orange; cyl.firstMaterial = mt
            let n = SCNNode(geometry: cyl); n.simdPosition = mid
            n.simdOrientation = simd_quatf(from: V3(0, 1, 0), to: dir.normalizedSafe)
            root.addChildNode(n)
        }
        let topY = towerH
        cable(V3(0, deckH + 6, -span * 0.5), V3(0, topY, -span * 0.32))
        cable(V3(0, topY, -span * 0.32), V3(0, topY, span * 0.32))
        cable(V3(0, topY, span * 0.32), V3(0, deckH + 6, span * 0.5))
        root.simdPosition = p
        root.scale = SCNVector3(upm, upm, upm)
        return root
    }

    private static func bayBridge(at p: V3, unitsPerMeter upm: Float) -> SCNNode {
        let root = SCNNode(); root.name = "bay_bridge"
        let grey = UIColor(red: 0.72, green: 0.74, blue: 0.76, alpha: 1)
        let span: Float = 1400, towerH: Float = 150, deckH: Float = 60
        let deck = box(span, 5, 24, color: UIColor(white: 0.55, alpha: 1)) // runs E-W (along X)
        deck.position = SCNVector3(0, deckH, 0); root.addChildNode(deck)
        for dx in [-span * 0.3, 0, span * 0.3] {
            let t = box(16, towerH, 16, color: grey, chamfer: 1)
            t.position = SCNVector3(dx, towerH / 2, 0); root.addChildNode(t)
        }
        root.simdPosition = p
        root.scale = SCNVector3(upm, upm, upm)
        return root
    }

    // MARK: Environment

    private static func configureEnvironment(_ scene: SCNScene) {
        scene.background.contents = skyGradient()
        scene.fogStartDistance = 5000
        scene.fogEndDistance = 22000
        scene.fogDensityExponent = 1.5
        scene.fogColor = UIColor(red: 0.74, green: 0.82, blue: 0.90, alpha: 1)
    }

    private static func skyGradient() -> UIImage {
        let size = CGSize(width: 4, height: 256)
        return UIGraphicsImageRenderer(size: size).image { ctx in
            let colors = [
                UIColor(red: 0.34, green: 0.56, blue: 0.85, alpha: 1).cgColor,
                UIColor(red: 0.76, green: 0.86, blue: 0.95, alpha: 1).cgColor,
            ] as CFArray
            let grad = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(), colors: colors, locations: [0, 1])!
            ctx.cgContext.drawLinearGradient(grad, start: .zero, end: CGPoint(x: 0, y: size.height), options: [])
        }
    }

    private static func addLighting(_ scene: SCNScene) {
        let sun = SCNNode()
        sun.light = SCNLight(); sun.light!.type = .directional
        sun.light!.intensity = 1050; sun.light!.castsShadow = true
        sun.light!.shadowMode = .deferred
        sun.light!.shadowColor = UIColor(white: 0, alpha: 0.28)
        sun.eulerAngles = SCNVector3(-Float.pi / 3.2, Float.pi / 5, 0)
        scene.rootNode.addChildNode(sun)
        let amb = SCNNode()
        amb.light = SCNLight(); amb.light!.type = .ambient; amb.light!.intensity = 480
        amb.light!.color = UIColor(red: 0.64, green: 0.70, blue: 0.80, alpha: 1)
        scene.rootNode.addChildNode(amb)
    }

    // MARK: Fallback (assets missing)

    private static func buildFallback(_ scene: SCNScene) -> (V3, simd_quatf) {
        let floor = SCNFloor()
        floor.firstMaterial?.diffuse.contents = UIColor(red: 0.10, green: 0.27, blue: 0.42, alpha: 1)
        scene.rootNode.addChildNode(SCNNode(geometry: floor))
        return (V3(0, 600, 2000), simd_quatf(angle: 0, axis: WORLD_UP))
    }
}
