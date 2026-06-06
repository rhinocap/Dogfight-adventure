// Turns the downloaded SF Bay tiles into game assets:
//   - bay_texture.jpg   : stitched satellite imagery (top-left origin)
//   - bay_heightmap.f32 : GRID*GRID Float32 elevations (meters), row 0 = north
//   - bay_meta.json     : grid size, elevation range, geo mapping
// Run: swift scripts/geo_build.swift
import AppKit
import CoreGraphics
import Foundation

let GEO = "/tmp/dogfight/geo"
let OUT = "\(FileManager.default.currentDirectoryPath)/DogfightAdventures/Resources"
try? FileManager.default.createDirectory(atPath: OUT, withIntermediateDirectories: true)
let GRID = 256

let meta = try JSONSerialization.jsonObject(with: Data(contentsOf: URL(fileURLWithPath: "\(GEO)/meta.json"))) as! [String: Any]
let z = meta["z"] as! Int, x0 = meta["x0"] as! Int, y0 = meta["y0"] as! Int
let nx = meta["nx"] as! Int, ny = meta["ny"] as! Int, tile = meta["tileSize"] as! Int
let MW = nx * tile, MH = ny * tile
print("mosaic \(MW)x\(MH) from \(nx)x\(ny) tiles @ z\(z)")

// Decode an image file to top-left-origin RGBA bytes.
func rgbaTopLeft(_ path: String) -> [UInt8]? {
    guard let nsimg = NSImage(contentsOfFile: path) else { return nil }
    var r = CGRect(x: 0, y: 0, width: nsimg.size.width, height: nsimg.size.height)
    guard let img = nsimg.cgImage(forProposedRect: &r, context: nil, hints: nil) else { return nil }
    let w = img.width, h = img.height
    var bottomLeft = [UInt8](repeating: 0, count: w * h * 4)
    let ctx = CGContext(data: &bottomLeft, width: w, height: h, bitsPerComponent: 8, bytesPerRow: w * 4,
                        space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
    ctx.draw(img, in: CGRect(x: 0, y: 0, width: w, height: h))
    var top = [UInt8](repeating: 0, count: w * h * 4)
    for y in 0..<h {
        let src = (h - 1 - y) * w * 4, dst = y * w * 4
        top[dst..<dst + w * 4] = bottomLeft[src..<src + w * 4]
    }
    return top
}

// ---- Satellite texture mosaic ----
var tex = [UInt8](repeating: 255, count: MW * MH * 4)
for cx in 0..<nx {
    for cy in 0..<ny {
        let path = "\(GEO)/imgry/\(x0 + cx)_\(y0 + cy).jpg"
        guard let px = rgbaTopLeft(path) else { print("miss img \(path)"); continue }
        for ty in 0..<tile {
            let dstRow = ((cy * tile + ty) * MW + cx * tile) * 4
            let srcRow = (ty * tile) * 4
            tex[dstRow..<dstRow + tile * 4] = px[srcRow..<srcRow + tile * 4]
        }
    }
}
let texProvider = CGDataProvider(data: Data(tex) as CFData)!
let texImg = CGImage(width: MW, height: MH, bitsPerComponent: 8, bitsPerPixel: 32, bytesPerRow: MW * 4,
                     space: CGColorSpaceCreateDeviceRGB(),
                     bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.premultipliedLast.rawValue),
                     provider: texProvider, decode: nil, shouldInterpolate: false, intent: .defaultIntent)!
let texURL = URL(fileURLWithPath: "\(OUT)/bay_texture.jpg")
let texDest = CGImageDestinationCreateWithURL(texURL as CFURL, "public.jpeg" as CFString, 1, nil)!
CGImageDestinationAddImage(texDest, texImg, [kCGImageDestinationLossyCompressionQuality: 0.85] as CFDictionary)
CGImageDestinationFinalize(texDest)
print("wrote bay_texture.jpg (\(MW)x\(MH))")

// ---- Elevation mosaic -> heightmap grid ----
var elev = [Float](repeating: 0, count: MW * MH)
for cx in 0..<nx {
    for cy in 0..<ny {
        let path = "\(GEO)/elev/\(x0 + cx)_\(y0 + cy).png"
        guard let px = rgbaTopLeft(path) else { print("miss elev \(path)"); continue }
        for ty in 0..<tile {
            for tx in 0..<tile {
                let s = (ty * tile + tx) * 4
                let r = Float(px[s]), g = Float(px[s + 1]), b = Float(px[s + 2])
                let e = (r * 256 + g + b / 256) - 32768
                let gx = cx * tile + tx, gy = cy * tile + ty
                elev[gy * MW + gx] = e
            }
        }
    }
}

// Downsample to GRID x GRID (area average) + record range.
var height = [Float](repeating: 0, count: GRID * GRID)
var minE: Float = 1e9, maxE: Float = -1e9
let sx = Float(MW) / Float(GRID), sy = Float(MH) / Float(GRID)
for r in 0..<GRID {
    for c in 0..<GRID {
        let px = Int((Float(c) + 0.5) * sx), py = Int((Float(r) + 0.5) * sy)
        let e = elev[min(MH - 1, py) * MW + min(MW - 1, px)]
        height[r * GRID + c] = e
        minE = min(minE, e); maxE = max(maxE, e)
    }
}
height.withUnsafeBytes { raw in
    try! Data(raw).write(to: URL(fileURLWithPath: "\(OUT)/bay_heightmap.f32"))
}
print("wrote bay_heightmap.f32 (\(GRID)x\(GRID))  elev \(Int(minE))..\(Int(maxE)) m")

// Ground span in meters (Web Mercator tile ground size at center latitude).
let bbox = meta["bbox"] as! [String: Double]
let centerLat = (bbox["minLat"]! + bbox["maxLat"]!) / 2
let metersPerTile = 40075016.686 * cos(centerLat * .pi / 180) / pow(2.0, Double(z))
let groundMeters = metersPerTile * Double(nx)
let outMeta: [String: Any] = [
    "grid": GRID, "minElev": minE, "maxElev": maxE,
    "groundMeters": groundMeters, "z": z, "x0": x0, "y0": y0, "nx": nx, "ny": ny,
    "mosaicW": MW, "mosaicH": MH, "bbox": bbox,
]
try! JSONSerialization.data(withJSONObject: outMeta, options: .prettyPrinted)
    .write(to: URL(fileURLWithPath: "\(OUT)/bay_meta.json"))
print(String(format: "wrote bay_meta.json  ground=%.1f km", groundMeters / 1000))
