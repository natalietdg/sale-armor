// Renders the app icon from the SAME pixel art the app draws, so the icon and the in-app sprite
// can never drift apart. Run:  swift icon/make-icon.swift
//
// 8-bit rules kept: no gradients, no anti-aliasing, no rounded corners. Every pixel is a hard
// square, drawn at an exact multiple of the grid so the edges stay crisp at 1024 and at 60.

import AppKit

// The sword, identical to `SwordSprite.art` in Pixels.swift.
let art: [[Character]] = [
    ".....##.....",
    ".....##.....",
    "....#==#....",
    "....#==#....",
    "....#==#....",
    "....#==#....",
    "....#==#....",
    "....#==#....",
    "....#==#....",
    "....#==#....",
    "....#==#....",
    "#####oo#####",
    "#####oo#####",
    ".....##.....",
    ".....##.....",
    ".....##.....",
    "....####....",
    "....####...."
].map(Array.init)

func rgb(_ hex: UInt32) -> NSColor {
    NSColor(srgbRed: CGFloat((hex >> 16) & 0xFF) / 255,
            green:   CGFloat((hex >> 8) & 0xFF) / 255,
            blue:    CGFloat(hex & 0xFF) / 255, alpha: 1)
}

let bg     = rgb(0x0F0F1B)   // Px.bg
let gold   = rgb(0xE8B44A)   // Px.goldMetal
let silver = rgb(0xD3D8E6)   // Px.silver
let ruby   = rgb(0xD62F45)   // Px.ruby

let size = 1024
let image = NSImage(size: NSSize(width: size, height: size))
image.lockFocus()
NSGraphicsContext.current?.shouldAntialias = false

bg.setFill()
NSRect(x: 0, y: 0, width: size, height: size).fill()

// The sprite occupies the middle ~62%, leaving the margin iOS masks into a rounded square.
let cols = art[0].count, rows = art.count
let px = floor(Double(size) * 0.62 / Double(rows))
let drawW = px * Double(cols), drawH = px * Double(rows)
let originX = (Double(size) - drawW) / 2
let originY = (Double(size) - drawH) / 2

for (y, row) in art.enumerated() {
    for (x, ch) in row.enumerated() where ch != "." {
        switch ch {
        case "=": silver.setFill()
        case "o": ruby.setFill()
        default:  gold.setFill()
        }
        // AppKit's origin is bottom-left, the art reads top-down, so the row is flipped.
        NSRect(x: originX + Double(x) * px,
               y: originY + Double(rows - 1 - y) * px,
               width: px, height: px).fill()
    }
}

image.unlockFocus()

guard let tiff = image.tiffRepresentation,
      let rep = NSBitmapImageRep(data: tiff),
      let png = rep.representation(using: .png, properties: [:]) else {
    fatalError("could not render the icon")
}

let out = URL(fileURLWithPath: "icon/appicon.png")
try! png.write(to: out)
print("wrote \(out.path) at \(size)×\(size)")
