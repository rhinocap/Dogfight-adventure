//
//  MathUtils.swift
//  Dogfight Adventures
//
//  simd helpers shared across the flight model, camera, AI and weapons.
//

import simd
import SceneKit
import UIKit

typealias V3 = SIMD3<Float>

let WORLD_UP = V3(0, 1, 0)

extension SIMD3 where Scalar == Float {
    var length: Float { simd_length(self) }

    /// Normalized vector, or zero if the input is degenerate.
    var normalizedSafe: V3 {
        let l = simd_length(self)
        return l > 1e-6 ? self / l : V3(0, 0, 0)
    }
}

extension simd_quatf {
    var forward: V3 { simd_act(self, V3(0, 0, -1)) }
    var right: V3 { simd_act(self, V3(1, 0, 0)) }
    var up: V3 { simd_act(self, V3(0, 1, 0)) }
}

@inline(__always) func lerp(_ a: V3, _ b: V3, _ t: Float) -> V3 { a + (b - a) * t }
@inline(__always) func lerp(_ a: Float, _ b: Float, _ t: Float) -> Float { a + (b - a) * t }
@inline(__always) func clampf(_ x: Float, _ lo: Float, _ hi: Float) -> Float { min(max(x, lo), hi) }

extension SCNVector3 {
    // SCNVector3 components are Float on iOS.
    init(_ v: V3) { self.init(x: v.x, y: v.y, z: v.z) }
}

/// Angle (radians) between two direction vectors.
@inline(__always) func angleBetween(_ a: V3, _ b: V3) -> Float {
    let d = simd_dot(a.normalizedSafe, b.normalizedSafe)
    return acos(clampf(d, -1, 1))
}
