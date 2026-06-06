// Composes the nine icon PNGs into a labeled 3x3 contact sheet.
import AppKit
import CoreGraphics

let dir = CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : "/tmp/dogfight/icons"
let names = ["01_minimal_blue","02_golden_gate","03_tactical_side","04_vapor_trails",
             "05_roundel","06_hud_crosshair","07_sunset_bank","08_bold_flat","09_steel_sky"]
let cell: CGFloat = 380, pad: CGFloat = 28, label: CGFloat = 44, corner: CGFloat = 84
let cols = 3, rows = 3
let W = pad + (cell + pad) * CGFloat(cols)
let H = pad + (cell + label + pad) * CGFloat(rows)
let c = CGContext(data: nil, width: Int(W), height: Int(H), bitsPerComponent: 8, bytesPerRow: 0,
                  space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
c.setFillColor(CGColor(red: 0.10, green: 0.11, blue: 0.13, alpha: 1)); c.fill(CGRect(x: 0, y: 0, width: W, height: H))

func loadCG(_ path: String) -> CGImage? {
    guard let d = NSImage(contentsOfFile: path) else { return nil }
    var r = CGRect(x: 0, y: 0, width: d.size.width, height: d.size.height)
    return d.cgImage(forProposedRect: &r, context: nil, hints: nil)
}

for (i, name) in names.enumerated() {
    let col = i % cols, row = i / cols
    let x = pad + CGFloat(col) * (cell + pad)
    // top row visually = highest y
    let y = H - (CGFloat(row + 1) * (cell + label + pad))
    let rect = CGRect(x: x, y: y + label, width: cell, height: cell)
    // rounded clip to preview the iOS mask
    c.saveGState()
    let rr = CGPath(roundedRect: rect, cornerWidth: corner, cornerHeight: corner, transform: nil)
    c.addPath(rr); c.clip()
    if let img = loadCG("\(dir)/\(name).png") { c.draw(img, in: rect) }
    c.restoreGState()
    // label
    let num = String(format: "%d", i + 1)
    let attrs: [NSAttributedString.Key: Any] = [
        .font: NSFont.systemFont(ofSize: 26, weight: .semibold),
        .foregroundColor: NSColor.white
    ]
    let nsctx = NSGraphicsContext(cgContext: c, flipped: false)
    NSGraphicsContext.saveGraphicsState(); NSGraphicsContext.current = nsctx
    let txt = "\(num).  \(name.dropFirst(3).replacingOccurrences(of: "_", with: " "))"
    (txt as NSString).draw(at: CGPoint(x: x + 6, y: y + 6), withAttributes: attrs)
    NSGraphicsContext.restoreGraphicsState()
}

let img = c.makeImage()!
let url = URL(fileURLWithPath: "\(dir)/_contact_sheet.png")
let dest = CGImageDestinationCreateWithURL(url as CFURL, "public.png" as CFString, 1, nil)!
CGImageDestinationAddImage(dest, img, nil)
CGImageDestinationFinalize(dest)
print("wrote _contact_sheet.png  (\(Int(W))x\(Int(H)))")
