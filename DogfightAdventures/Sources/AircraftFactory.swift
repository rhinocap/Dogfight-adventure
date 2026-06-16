//
//  AircraftFactory.swift
//  Dogfight Adventures
//
//  Builds low-poly jet meshes from primitives (player + enemy variants) and
//  attaches an engine exhaust particle system.
//

import SceneKit
import UIKit

enum AircraftFactory {

    static func makeJet(bodyColor: UIColor, accent: UIColor) -> SCNNode {
        let jet = SCNNode()
        jet.name = "jet"

        func part(_ w: Float, _ h: Float, _ l: Float, _ color: UIColor,
                  chamfer: Float = 0.3) -> SCNNode {
            let g = SCNBox(width: CGFloat(w), height: CGFloat(h), length: CGFloat(l),
                           chamferRadius: CGFloat(chamfer))
            let m = SCNMaterial()
            m.diffuse.contents = color
            m.roughness.contents = 0.45
            m.metalness.contents = 0.25
            g.firstMaterial = m
            return SCNNode(geometry: g)
        }

        // Fuselage (forward is -Z).
        let fuselage = part(3.0, 2.4, 14.0, bodyColor, chamfer: 1.0)
        jet.addChildNode(fuselage)

        // Nose cone.
        let nose = SCNNode(geometry: SCNCone(topRadius: 0, bottomRadius: 1.4, height: 5))
        nose.geometry!.firstMaterial = fuselage.geometry!.firstMaterial
        nose.eulerAngles = SCNVector3(-Float.pi / 2, 0, 0) // point along -Z
        nose.position = SCNVector3(0, 0, -9)
        jet.addChildNode(nose)

        // Cockpit canopy.
        let canopy = part(2.0, 1.4, 4.0, UIColor(red: 0.2, green: 0.3, blue: 0.4, alpha: 0.9))
        canopy.position = SCNVector3(0, 1.4, -2.5)
        jet.addChildNode(canopy)

        // Main wings.
        let wing = part(20.0, 0.5, 5.0, accent, chamfer: 0.2)
        wing.position = SCNVector3(0, -0.2, 1.0)
        jet.addChildNode(wing)

        // Horizontal stabilizers.
        let tailplane = part(9.0, 0.4, 3.0, accent, chamfer: 0.2)
        tailplane.position = SCNVector3(0, 0.2, 6.5)
        jet.addChildNode(tailplane)

        // Vertical stabilizer.
        let fin = part(0.5, 4.0, 4.0, accent, chamfer: 0.2)
        fin.position = SCNVector3(0, 2.2, 6.0)
        jet.addChildNode(fin)

        // Engine exhaust.
        let exhaust = makeExhaust()
        let emitter = SCNNode()
        emitter.position = SCNVector3(0, 0, 7.5)
        emitter.addParticleSystem(exhaust)
        jet.addChildNode(emitter)

        return jet
    }

    static func makeExhaust() -> SCNParticleSystem {
        let ps = SCNParticleSystem()
        ps.birthRate = 90
        ps.particleLifeSpan = 0.22
        ps.particleSize = 0.45
        ps.particleSizeVariation = 0.2
        ps.particleVelocity = 9
        ps.particleVelocityVariation = 3
        ps.emittingDirection = SCNVector3(0, 0, 1) // out the back (+Z)
        ps.spreadingAngle = 5
        ps.particleColor = UIColor(red: 1.0, green: 0.7, blue: 0.3, alpha: 0.8)
        ps.particleColorVariation = SCNVector4(0.1, 0.1, 0.0, 0.2)
        ps.blendMode = .additive
        ps.isLightingEnabled = false
        ps.particleImage = softDot()
        return ps
    }

    static func makeExplosion() -> SCNParticleSystem {
        let ps = SCNParticleSystem()
        ps.birthRate = 4000
        ps.emissionDuration = 0.1
        ps.loops = false
        ps.particleLifeSpan = 0.8
        ps.particleLifeSpanVariation = 0.4
        ps.particleSize = 1.4
        ps.particleSizeVariation = 1.0
        ps.particleVelocity = 60
        ps.particleVelocityVariation = 30
        ps.emittingDirection = SCNVector3(0, 0, 0)
        ps.spreadingAngle = 180
        ps.particleColor = UIColor(red: 1.0, green: 0.55, blue: 0.15, alpha: 1.0)
        ps.particleColorVariation = SCNVector4(0.1, 0.2, 0.0, 0.1)
        ps.blendMode = .additive
        ps.isLightingEnabled = false
        ps.particleImage = softDot()
        ps.acceleration = SCNVector3(0, -20, 0)
        return ps
    }

    /// A soft circular sprite generated at runtime (no asset files).
    private static func softDot() -> UIImage {
        let size = CGSize(width: 32, height: 32)
        return UIGraphicsImageRenderer(size: size).image { ctx in
            let cg = ctx.cgContext
            let colors = [UIColor(white: 1, alpha: 1).cgColor,
                          UIColor(white: 1, alpha: 0).cgColor] as CFArray
            let grad = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(),
                                  colors: colors, locations: [0, 1])!
            cg.drawRadialGradient(grad,
                                  startCenter: CGPoint(x: 16, y: 16), startRadius: 0,
                                  endCenter: CGPoint(x: 16, y: 16), endRadius: 16,
                                  options: [])
        }
    }
}
