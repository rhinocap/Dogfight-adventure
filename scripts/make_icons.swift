// Renders nine jet-themed 1024x1024 app icon designs for Dogfight Adventures.
// Pure Core Graphics — no external assets. Run: swift scripts/make_icons.swift <outdir>
import AppKit
import CoreGraphics

let S: CGFloat = 1024
let outDir = CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : "/tmp/dogfight/icons"
try? FileManager.default.createDirectory(atPath: outDir, withIntermediateDirectories: true)

func ctx() -> CGContext {
    let c = CGContext(data: nil, width: Int(S), height: Int(S), bitsPerComponent: 8, bytesPerRow: 0,
                      space: CGColorSpaceCreateDeviceRGB(),
                      bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
    c.interpolationQuality = .high
    c.setAllowsAntialiasing(true)
    return c
}
func rgb(_ r: CGFloat, _ g: CGFloat, _ b: CGFloat, _ a: CGFloat = 1) -> CGColor {
    CGColor(red: r/255, green: g/255, blue: b/255, alpha: a)
}
func save(_ c: CGContext, _ name: String) {
    let img = c.makeImage()!
    let url = URL(fileURLWithPath: "\(outDir)/\(name).png")
    let dest = CGImageDestinationCreateWithURL(url as CFURL, "public.png" as CFString, 1, nil)!
    CGImageDestinationAddImage(dest, img, nil)
    CGImageDestinationFinalize(dest)
    print("wrote \(name).png")
}
func linearGradient(_ c: CGContext, _ colors: [CGColor], _ start: CGPoint, _ end: CGPoint) {
    let n = colors.count
    let locs = (0..<n).map { CGFloat($0) / CGFloat(n - 1) }
    let g = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(), colors: colors as CFArray, locations: locs)!
    c.drawLinearGradient(g, start: start, end: end, options: [])
}
func radialGradient(_ c: CGContext, _ colors: [CGColor], _ center: CGPoint, _ radius: CGFloat) {
    let n = colors.count
    let locs = (0..<n).map { CGFloat($0) / CGFloat(n - 1) }
    let g = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(), colors: colors as CFArray, locations: locs)!
    c.drawRadialGradient(g, startCenter: center, startRadius: 0, endCenter: center, endRadius: radius, options: [])
}
func fill(_ c: CGContext, _ color: CGColor) {
    c.setFillColor(color); c.fill(CGRect(x: 0, y: 0, width: S, height: S))
}

// MARK: Jet silhouettes

// Top-down swept-wing fighter, nose toward +y. Normalized ~[-0.55,0.55].
let jetTopHalf: [CGPoint] = [
    CGPoint(x: 0.00, y: 0.97), CGPoint(x: 0.045, y: 0.62), CGPoint(x: 0.075, y: 0.40),
    CGPoint(x: 0.55, y: 0.06), CGPoint(x: 0.52, y: -0.04), CGPoint(x: 0.115, y: 0.06),
    CGPoint(x: 0.10, y: -0.18), CGPoint(x: 0.31, y: -0.34), CGPoint(x: 0.27, y: -0.43),
    CGPoint(x: 0.075, y: -0.28), CGPoint(x: 0.065, y: -0.52), CGPoint(x: 0.00, y: -0.55)
]
func jetTopPath(center: CGPoint, scale: CGFloat, rotation: CGFloat = 0) -> CGPath {
    let p = CGMutablePath()
    var pts = jetTopHalf
    // mirror right side -> add left side reversed
    let left = jetTopHalf.dropFirst().dropLast().reversed().map { CGPoint(x: -$0.x, y: $0.y) }
    pts.append(contentsOf: left)
    var t = CGAffineTransform(translationX: center.x, y: center.y)
        .rotated(by: rotation).scaledBy(x: scale, y: scale)
    for (i, pt) in pts.enumerated() {
        if i == 0 { p.move(to: pt, transform: t) } else { p.addLine(to: pt, transform: t) }
    }
    p.closeSubpath()
    return p
}

// Side-profile jet, nose toward +x.
func jetSidePath(center: CGPoint, scale: CGFloat) -> CGPath {
    let pts: [CGPoint] = [
        CGPoint(x: 0.62, y: 0.02), CGPoint(x: 0.20, y: 0.10), CGPoint(x: 0.02, y: 0.10),
        CGPoint(x: -0.10, y: 0.30), CGPoint(x: -0.20, y: 0.30), CGPoint(x: -0.16, y: 0.08),
        CGPoint(x: -0.55, y: 0.07), CGPoint(x: -0.55, y: -0.05), CGPoint(x: -0.16, y: -0.05),
        CGPoint(x: -0.05, y: -0.16), CGPoint(x: 0.30, y: -0.10), CGPoint(x: 0.55, y: -0.06)
    ]
    let p = CGMutablePath()
    let t = CGAffineTransform(translationX: center.x, y: center.y).scaledBy(x: scale, y: scale)
    for (i, pt) in pts.enumerated() {
        if i == 0 { p.move(to: pt, transform: t) } else { p.addLine(to: pt, transform: t) }
    }
    p.closeSubpath()
    return p
}

func drawJet(_ c: CGContext, _ path: CGPath, fill: CGColor, stroke: CGColor? = nil,
             lineWidth: CGFloat = 0, shadow: Bool = true) {
    c.saveGState()
    if shadow {
        c.setShadow(offset: CGSize(width: 0, height: -18), blur: 40,
                    color: CGColor(red: 0, green: 0, blue: 0, alpha: 0.35))
    }
    c.addPath(path); c.setFillColor(fill); c.fillPath()
    c.restoreGState()
    if let s = stroke, lineWidth > 0 {
        c.addPath(path); c.setStrokeColor(s); c.setLineWidth(lineWidth)
        c.setLineJoin(.round); c.strokePath()
    }
}

let mid = CGPoint(x: S/2, y: S/2)

// MARK: 1 — Minimalist white jet on blue
do {
    let c = ctx()
    linearGradient(c, [rgb(58,110,196), rgb(120,170,230)], CGPoint(x: 0, y: S), CGPoint(x: 0, y: 0))
    drawJet(c, jetTopPath(center: mid, scale: S*0.46), fill: rgb(255,255,255))
    save(c, "01_minimal_blue")
}

// MARK: 2 — Jet over Golden Gate
do {
    let c = ctx()
    linearGradient(c, [rgb(255,150,90), rgb(255,205,150)], CGPoint(x: 0, y: S), CGPoint(x: 0, y: 0))
    // bridge towers + deck (International Orange)
    let orange = rgb(200,72,40)
    c.setFillColor(orange)
    c.fill(CGRect(x: 150, y: 120, width: 60, height: 520))
    c.fill(CGRect(x: 814, y: 120, width: 60, height: 520))
    c.setStrokeColor(orange); c.setLineWidth(28)
    c.move(to: CGPoint(x: 60, y: 300)); c.addLine(to: CGPoint(x: 180, y: 600))
    c.addLine(to: CGPoint(x: 844, y: 600)); c.addLine(to: CGPoint(x: 964, y: 300)); c.strokePath()
    c.setLineWidth(34); c.move(to: CGPoint(x: 90, y: 300)); c.addLine(to: CGPoint(x: 934, y: 300)); c.strokePath()
    drawJet(c, jetTopPath(center: CGPoint(x: S/2, y: S*0.52), scale: S*0.40), fill: rgb(245,245,245))
    save(c, "02_golden_gate")
}

// MARK: 3 — Tactical side profile (dark)
do {
    let c = ctx()
    linearGradient(c, [rgb(24,28,36), rgb(54,62,78)], CGPoint(x: 0, y: 0), CGPoint(x: S, y: S))
    drawJet(c, jetSidePath(center: CGPoint(x: S/2 - 20, y: S/2), scale: S*0.78),
            fill: rgb(190,198,210), stroke: rgb(70,78,92), lineWidth: 6)
    save(c, "03_tactical_side")
}

// MARK: 4 — Vapor trails climb
do {
    let c = ctx()
    linearGradient(c, [rgb(40,90,170), rgb(150,195,235)], CGPoint(x: 0, y: 0), CGPoint(x: 0, y: S))
    // two contrails behind a banking jet
    c.setStrokeColor(rgb(255,255,255,0.85)); c.setLineCap(.round)
    for dx in [CGFloat(-70), 70] {
        c.setLineWidth(26)
        c.move(to: CGPoint(x: S/2 + dx*0.5, y: 120))
        c.addQuadCurve(to: CGPoint(x: S/2 + dx, y: 520), control: CGPoint(x: S/2 + dx*1.3, y: 320))
        c.strokePath()
    }
    drawJet(c, jetTopPath(center: CGPoint(x: S/2, y: S*0.62), scale: S*0.40, rotation: 0.12),
            fill: rgb(255,255,255))
    save(c, "04_vapor_trails")
}

// MARK: 5 — Roundel badge
do {
    let c = ctx()
    fill(c, rgb(22,40,72))
    let center = mid
    let rings: [(CGFloat, CGColor)] = [(440, rgb(214,40,40)), (320, rgb(255,255,255)), (210, rgb(40,80,180))]
    for (r, col) in rings { c.setFillColor(col); c.addEllipse(in: CGRect(x: center.x-r, y: center.y-r, width: 2*r, height: 2*r)); c.fillPath() }
    drawJet(c, jetTopPath(center: center, scale: S*0.30), fill: rgb(255,255,255), shadow: false)
    save(c, "05_roundel")
}

// MARK: 6 — HUD / crosshair (game-y)
do {
    let c = ctx()
    radialGradient(c, [rgb(20,46,40), rgb(8,18,16)], mid, S*0.7)
    let green = rgb(70,230,140)
    c.setStrokeColor(green.copy(alpha: 0.9)!); c.setLineWidth(8)
    c.addEllipse(in: CGRect(x: 160, y: 160, width: 704, height: 704)); c.strokePath()
    // crosshair ticks
    c.setLineWidth(10)
    for a in stride(from: 0, to: 360, by: 90) {
        let rad = CGFloat(a) * .pi/180
        let p0 = CGPoint(x: mid.x + cos(rad)*300, y: mid.y + sin(rad)*300)
        let p1 = CGPoint(x: mid.x + cos(rad)*360, y: mid.y + sin(rad)*360)
        c.move(to: p0); c.addLine(to: p1); c.strokePath()
    }
    drawJet(c, jetTopPath(center: mid, scale: S*0.34), fill: green, shadow: false)
    save(c, "06_hud_crosshair")
}

// MARK: 7 — Sunset banking jet
do {
    let c = ctx()
    linearGradient(c, [rgb(255,94,98), rgb(255,177,108), rgb(255,221,148)],
                   CGPoint(x: 0, y: 0), CGPoint(x: 0, y: S))
    // soft sun glow, lower area
    let glow = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(),
                          colors: [rgb(255,255,255,0.9), rgb(255,255,255,0.0)] as CFArray,
                          locations: [0, 1])!
    let gc = CGPoint(x: S*0.32, y: S*0.30)
    c.drawRadialGradient(glow, startCenter: gc, startRadius: 0, endCenter: gc, endRadius: S*0.5, options: [])
    drawJet(c, jetTopPath(center: mid, scale: S*0.46, rotation: -0.5), fill: rgb(40,30,46))
    save(c, "07_sunset_bank")
}

// MARK: 8 — Bold flat (App Store friendly)
do {
    let c = ctx()
    linearGradient(c, [rgb(28,32,44), rgb(28,32,44)], CGPoint(x: 0, y: 0), CGPoint(x: 0, y: S))
    // accent chevron
    c.setFillColor(rgb(255,80,70))
    let chev = CGMutablePath()
    chev.move(to: CGPoint(x: S/2, y: 150)); chev.addLine(to: CGPoint(x: S-130, y: S-180))
    chev.addLine(to: CGPoint(x: S/2, y: S-300)); chev.addLine(to: CGPoint(x: 130, y: S-180))
    chev.closeSubpath(); c.addPath(chev); c.fillPath()
    drawJet(c, jetTopPath(center: CGPoint(x: S/2, y: S*0.54), scale: S*0.42), fill: rgb(255,255,255))
    save(c, "08_bold_flat")
}

// MARK: 9 — Steel jet, sky + cloud band
do {
    let c = ctx()
    linearGradient(c, [rgb(70,130,200), rgb(170,205,235)], CGPoint(x: 0, y: S), CGPoint(x: 0, y: 0))
    c.setFillColor(rgb(255,255,255,0.5))
    for (cx, cy, r) in [(CGFloat(260), CGFloat(360), CGFloat(120)), (520, 300, 150), (760, 380, 110)] {
        c.addEllipse(in: CGRect(x: cx-r, y: cy-r, width: 2*r, height: 2*r))
    }
    c.fillPath()
    let steel = CGMutablePath()
    drawJet(c, jetTopPath(center: CGPoint(x: S/2, y: S*0.56), scale: S*0.48),
            fill: rgb(120,132,150), stroke: rgb(60,68,84), lineWidth: 6)
    _ = steel
    save(c, "09_steel_sky")
}

print("done")
