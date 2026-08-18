import SwiftUI

/// **The 8-bit look, in one file.**
///
/// Two rules make this read as 8-bit rather than "flat design with a retro font":
///
/// 1. **Nothing is round and nothing is soft.** No corner radius, no blur, no gradient, no shadow.
///    A 1980s tile engine could not draw any of them.
/// 2. **Every edge is a hard step.** Borders are drawn as stacked rectangles, and the shield sprite
///    is a literal grid of squares, so it stays crisp at any size instead of being a scaled asset.
///
/// **The typeface is Pixelify Sans**, bundled under the SIL Open Font Licence — free for
/// commercial use. An earlier version argued that a bitmap font was a licence to track and used the
/// system monospace instead. That was wrong: OFL fonts cost nothing to ship, and the type is the
/// largest surface on every screen.
enum Px {
    /// A deliberately small palette. Picking from a fixed set is most of what makes art look 8-bit.
    static let bg      = Color(hex: 0x0F0F1B)   // near-black, faintly blue
    static let panel   = Color(hex: 0x1D1D2E)
    static let ink     = Color(hex: 0xE8E6F0)
    static let dim     = Color(hex: 0x8A87A8)
    /// **Used for exactly one thing: the shield is up.** Every choice, selection and pressable
    /// surface is gold. Reserving a colour to a single meaning is what lets it mean anything.
    static let armor   = Color(hex: 0x4CC9A4)
    static let alert   = Color(hex: 0xE85D75)   // spending danger
    static let gold    = Color(hex: 0xF2C14E)   // the money colour
    static let line    = Color(hex: 0x3A3A55)

    // The sword's own metals. Kept apart from the UI palette because they belong to the sprite,
    // not to the interface, and a button should never be able to borrow "ruby".
    //
    // **There is no dimmed set.** An earlier version drained the sword to grey when idle and it
    // read as brown, which is a logo that stops working half the time. The sword is always gold;
    // being armed is said by the words instead.
    static let goldMetal  = Color(hex: 0xF7CC5E)
    static let silver     = Color(hex: 0xD3D8E6)
    static let ruby       = Color(hex: 0xD62F45)
    static let rubyLit    = Color(hex: 0xFF6B7E)
    // The emeralds in the guard and pommel. Two tones, so a two-cell gem reads as faceted.
    static let emerald    = Color(hex: 0x2E9E6B)
    static let emeraldLit = Color(hex: 0x7BE8A8)
    /// What a pixel turns into as the gleam passes over it. Two extra colours, not a gradient.
    static let goldShine  = Color(hex: 0xFFF3C4)
    static let silverShine = Color(hex: 0xFFFFFF)

    /// The glow's palette, dimmest to brightest. **Solid colours, never transparent** — gold at low
    /// alpha over near-black turns brown, which reads as a coin rather than as light.
    ///
    /// Five steps rather than two, because a gradient in a fixed palette is a *ramp of shades*; the
    /// dither then only has to blend each neighbouring pair, which is what makes the fade look
    /// continuous instead of like two zones meeting.
    ///
    /// **Every shade sits well below the sword in value.** The source has to stay the brightest
    /// thing in frame or it stops looking like the source.
    ///
    /// Brightness and size are separate dials here, which is worth knowing before touching either:
    /// the *intensity* function decides how many cells light up at all — that is the glow's size
    /// and spread — while this palette decides how bright those cells are. Dimming the intensity
    /// shrinks the glow; dimming the palette does not.
    /// The hot centre: a small, brighter glow sitting inside the broad dim one, tighter than the
    /// sword itself. Two light sources rather than one gradient — the wide one says *there is
    /// light here*, this one says *it is coming from the blade*.
    static let coreRamp: [Color] = [
        Color(hex: 0x6E4A1C),
        Color(hex: 0x9A6624),
        Color(hex: 0xC2842E)
    ]

    static let glowRamp: [Color] = [
        Color(hex: 0x171006),
        Color(hex: 0x281B0A),
        Color(hex: 0x3E2A10),
        Color(hex: 0x573A16),
        Color(hex: 0x6E4A1C)
    ]


    /// The wall. Three shades a hair apart, because a brick pattern you can actually *read* is a
    /// pattern competing with the text on top of it — this one is meant to be felt, not looked at.
    /// Tier colours, borrowed from loot rarity because everyone already reads them.
    static let tierNormal = Color(hex: 0x9AA0B5)   // common
    static let tierElite  = Color(hex: 0x5FA8E8)   // rare
    static let tierBoss   = Color(hex: 0xD8524F)   // the one you do not want

    static let mortar   = Color(hex: 0x0B0B13)
    static let brick    = Color(hex: 0x15151F)
    static let brickOdd = Color(hex: 0x1A1A26)

    /// One unit of the grid. Every size in the app is a multiple of it, which is what keeps the
    /// spacing feeling snapped rather than arbitrary.
    static let unit: CGFloat = 4
}

extension Color {
    init(hex: UInt32) {
        self.init(.sRGB,
                  red:   Double((hex >> 16) & 0xFF) / 255,
                  green: Double((hex >> 8) & 0xFF) / 255,
                  blue:  Double(hex & 0xFF) / 255,
                  opacity: 1)
    }
}

extension Font {
    /// **Pixelify Sans**, bundled under the SIL Open Font Licence.
    ///
    /// The system monospace read as *terminal*, not 8-bit — it was the largest un-pixelated surface
    /// in the app and everything else was downstream of it. Press Start 2P is the more famous
    /// choice and was rejected: this app has real sentences in it, and Press Start is unreadable
    /// below about 14pt.
    ///
    /// Falls back to the system monospace if the font ever fails to load, so a missing file is a
    /// duller app rather than a blank one.
    /// Pixelify Sans draws small for its point size — the glyphs sit low in the em box and the
    /// counters are tight — so every size the app asks for is scaled up. On a 6.9-inch simulator
    /// this was merely cosy; on a phone in a hand it was too small to read.
    private static let pixelScale: CGFloat = 1.5

    static func px(_ size: CGFloat, _ weight: Font.Weight = .bold) -> Font {
        let size = (size * pixelScale).rounded()
        // **One PostScript name, not one per weight.** Pixelify Sans is a variable font with a
        // single weight axis, so `PixelifySans-Bold` does not exist — asking for it returned nil
        // and every bold call in the app silently fell back to the system monospace. The weight is
        // applied to the font instead, which drives the axis.
        let name = "PixelifySans-Regular"
        guard UIFont(name: name, size: size) != nil else {
            return .system(size: size, weight: weight, design: .monospaced)
        }
        return .custom(name, size: size).weight(weight)
    }
}

extension View {
    /// Uppercase, spaced, monospaced: the label voice.
    func pxLabel(_ size: CGFloat = 11) -> some View {
        self.font(.px(size, .black)).tracking(size * 0.18).textCase(.uppercase)
    }
}

/// A dungeon wall, tiled in the same blocks as everything else.
///
/// Drawn once and rasterised rather than re-evaluated: it never changes, and it sits behind every
/// screen. The variation is a hash of the brick's position, not a random number — a sprite sheet
/// had no RNG, and a wall that reshuffles on every redraw would shimmer.
struct PxBricks: View {
    var body: some View {
        Canvas { ctx, size in
            let bw = Px.unit * 8, bh = Px.unit * 3, mortar = Px.unit / 2
            let rows = Int(size.height / bh) + 2
            let cols = Int(size.width / bw) + 2

            for row in 0..<rows {
                // every other course is offset by half a brick — the thing that makes it a wall
                let shift = row % 2 == 0 ? 0 : bw / 2
                for col in -1..<cols {
                    let x = CGFloat(col) * bw + shift
                    let y = CGFloat(row) * bh
                    let odd = (row &* 7 &+ col &* 13) % 9 == 0
                    ctx.fill(Path(CGRect(x: x + mortar, y: y + mortar,
                                         width: bw - mortar, height: bh - mortar)),
                             with: .color(odd ? Px.brickOdd : Px.brick))
                }
            }
        }
        .background(Px.mortar)
        .drawingGroup()
        .ignoresSafeArea()
        .accessibilityHidden(true)
    }
}

// MARK: - chrome

/// A panel with a stepped double border. The inner offset is what sells the depth without a shadow.
struct PxPanel<Content: View>: View {
    var stroke: Color = Px.line
    var fill: Color = Px.panel
    @ViewBuilder var content: Content

    var body: some View {
        content
            .padding(Px.unit * 4)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(fill)
            .overlay(Rectangle().strokeBorder(stroke, lineWidth: Px.unit / 2))
            .overlay(alignment: .topLeading) {
                // the highlight edge, two pixels in — a tile-engine bevel
                Rectangle().fill(stroke.opacity(0.35))
                    .frame(height: Px.unit / 2)
                    .padding(.horizontal, Px.unit / 2)
                    .padding(.top, Px.unit / 2)
            }
    }
}

/// A hard-edged button that visibly *depresses* by one grid unit rather than fading or scaling.
///
/// **Gold, not teal.** The palette splits by meaning: gold is *the thing you press*, teal is *the
/// thing that is true* — armed, on guard, the selected tab. A teal button on the permission screen
/// was an orphan hue, the only cool colour in a scene made of gold, silver and ruby.
///
/// The press is an instant one-unit offset rather than a 160ms scale. A scale would be the more
/// conventional answer, but easing is a modern affordance and this whole file is arguing that it
/// is not one — the offset gives the same "the interface heard you" feedback in the right idiom.
struct PxButtonStyle: ButtonStyle {
    var tint: Color = Px.goldMetal
    var text: Color = Px.bg

    func makeBody(configuration: Configuration) -> some View {
        let down = configuration.isPressed
        return configuration.label
            .font(.px(14, .black))
            .tracking(1.4)
            .textCase(.uppercase)
            .foregroundStyle(text)
            .padding(.vertical, Px.unit * 3)
            .frame(maxWidth: .infinity)
            .background(tint)
            .overlay(Rectangle().strokeBorder(Px.bg.opacity(0.35), lineWidth: Px.unit / 2))
            // the "shadow" is a solid offset block, the only kind an 8-bit renderer had
            .background(
                Rectangle().fill(tint.opacity(0.45))
                    .offset(x: Px.unit, y: Px.unit)
            )
            .offset(x: down ? Px.unit : 0, y: down ? Px.unit : 0)
            .animation(nil, value: down)   // instant. Easing is a modern affordance.
    }
}

/// A date, stepped rather than spun.
///
/// `DatePicker` is the least pixelated thing in the app: an iOS wheel or calendar popover with
/// system chrome, sub-pixel type and rounded corners, sitting inside a screen made of hard squares.
/// This is three steppers made of the same blocks as everything else.
struct PxDateField: View {
    @Binding var date: Date
    /// Dates before this are refused, so an end can never precede a start.
    var notBefore: Date?

    private var calendar: Calendar { .current }

    var body: some View {
        HStack(spacing: Px.unit * 2) {
            unit("Day", .day, format: "dd")
            unit("Month", .month, format: "MMM")
            unit("Year", .year, format: "yyyy")
        }
    }

    private func unit(_ label: String, _ component: Calendar.Component, format: String) -> some View {
        VStack(alignment: .leading, spacing: Px.unit) {
            Text(label).pxLabel(9).foregroundStyle(Px.dim)
            HStack(spacing: Px.unit) {
                Button("−") { step(component, -1) }
                    .buttonStyle(PxButtonStyle(tint: Px.panel, text: Px.ink))
                Text(text(format))
                    .font(.px(14, .black)).foregroundStyle(Px.ink)
                    .frame(minWidth: Px.unit * 11)
                Button("+") { step(component, 1) }
                    .buttonStyle(PxButtonStyle(tint: Px.panel, text: Px.ink))
            }
        }
    }

    private func text(_ format: String) -> String {
        let f = DateFormatter()
        f.dateFormat = format
        return f.string(from: date).uppercased()
    }

    /// Stepping a month past a short month's end is clamped by `Calendar`, so 31 Jan + 1 month
    /// lands on 28 Feb rather than failing.
    private func step(_ component: Calendar.Component, _ delta: Int) {
        guard let next = calendar.date(byAdding: component, value: delta, to: date) else { return }
        if let notBefore, next < calendar.startOfDay(for: notBefore) { return }
        date = next
    }
}

// MARK: - the sprite

/// The sword, drawn as a literal pixel grid, with light coming off it.
///
/// Stored as rows of characters so the art is legible in source and editable without a tool:
/// `#` is gold, `=` the silver core of the blade, `o` the ruby set into the hilt, `E`/`e` the
/// emerald body and its lit facet, `.` empty.
/// Edit the art, not a PNG.
///
/// A sword rather than a shield because a **vertical silhouette survives being small** — at 40pt
/// in a header a shield is a lump, and a blade with a crossguard is still unmistakably a blade.
///
/// **The sprite is hard-edged and the light is not.** The bloom is the one soft thing in this file,
/// and it is deliberate: dithered pixel rings were tried first and read as a crusty outline welded
/// to the silhouette. Pixel art over a soft bloom is its own look rather than a compromise.
struct SwordSprite: View {
    /// Armed. The sword shines either way — this only changes the colour of the glints.
    var lit: Bool
    /// The bloom and the glitter. Off for the small header sword.
    var glow: Bool = true

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    /// 12 frames a second, because sprite animation was never smooth and smoothness reads as CSS.
    private static let fps: Double = 12
    /// One full cycle: the gleam sweeps, then the blade rests. A constant shimmer is jewellery,
    /// an occasional one is metal.
    private static let cycle = 54

    var body: some View {
        TimelineView(.animation(minimumInterval: 1 / Self.fps, paused: reduceMotion)) { timeline in
            let frame = reduceMotion ? -1 : Self.frame(at: timeline.date, lit: lit)

            ZStack {
                // **The glow is its own layer, and it only redraws when its brightness *step*
                // changes.** Its intensity is already quantised by the dither, so re-running a
                // 3,400-cell Canvas on all 12 frames a second bought nothing. `Equatable` lets
                // SwiftUI skip the body while the step is unchanged, turning ~54 full repaints per
                // cycle into ~14.
                if glow {
                    GlowLayer(step: Self.glowStep(frame, lit: lit), fieldW: fieldW, fieldH: fieldH)
                        .equatable()
                }

                // The sprite, the gleam and the glitter: a few dozen cells, cheap to redraw.
                Canvas { ctx, size in
                    let px = min(size.width / CGFloat(fieldW), size.height / CGFloat(fieldH))
                    let xPad = (size.width - px * CGFloat(fieldW)) / 2
                    let yPad = (size.height - px * CGFloat(fieldH)) / 2

                    func fill(_ x: Int, _ y: Int, _ colour: Color) {
                        ctx.fill(Path(CGRect(x: xPad + CGFloat(x) * px, y: yPad + CGFloat(y) * px,
                                             width: px, height: px)), with: .color(colour))
                    }

                    let band = frame * 2 - 6   // the gleam runs along x+y, so it lies diagonally
                    for cell in Self.body {
                        let gleaming = frame >= 0 && cell.x + cell.y >= band && cell.x + cell.y < band + 3
                        fill(originX + cell.x, originY + cell.y,
                             Self.colour(cell.ch, gleaming: gleaming, lit: lit))
                    }

                    guard glow, frame >= 0 else { return }
                    for star in Self.glitter where Self.isTwinkling(star, frame) {
                        let colour = lit ? Px.silverShine : Px.goldShine
                        fill(star.x, star.y, colour)
                        for (dx, dy) in [(0, -1), (0, 1), (-1, 0), (1, 0)] {
                            fill(star.x + dx, star.y + dy, colour.opacity(0.55))
                        }
                    }
                }
            }
        }
        .aspectRatio(CGFloat(fieldW) / CGFloat(fieldH), contentMode: .fit)
        .accessibilityHidden(true)
    }

    // MARK: timing

    /// The classic 4×4 ordered-dither threshold matrix. Values spread 0–1 so that as intensity
    /// rises, cells switch on in a fixed scattered order rather than in rings.
    private static let bayerMatrix: [[Double]] = [
        [ 0,  8,  2, 10],
        [12,  4, 14,  6],
        [ 3, 11,  1,  9],
        [15,  7, 13,  5]
    ].map { $0.map { ($0 + 0.5) / 16 } }

    static func bayer(_ x: Int, _ y: Int) -> Double {
        bayerMatrix[y % 4][x % 4]
    }

    /// On guard, the flare comes round faster. The sword is doing something, and it says so.
    private static func cycle(lit: Bool) -> Int { lit ? 34 : 54 }

    private static func frame(at date: Date, lit: Bool) -> Int {
        Int(date.timeIntervalSinceReferenceDate * fps) % cycle(lit: lit)
    }

    /// The glow's brightness, snapped to steps so its layer can skip redraws.
    static func glowStep(_ frame: Int, lit: Bool) -> Int { Int(pulse(frame, lit: lit) * 10) }

    /// How strong the light is this frame — a **flare, not a breathe**.
    ///
    /// Rises over a fifth of a second, then falls away for the rest of the cycle. A symmetric
    /// rise-and-fall reads as something alive and inhaling; light flares and fades. The range is
    /// deliberately wide, roughly 0.3 → 1.6, because the dither threshold turns brightness into
    /// *how many cells are lit* — so the glow visibly swells and shrinks rather than just changing
    /// shade.
    /// **Armed burns brighter and never falls as dark.** The glow stops being decoration and
    /// starts saying whether the guard is up — the one thing it was not carrying before.
    static func pulse(_ frame: Int, lit: Bool) -> Double {
        guard frame >= 0 else { return lit ? 1.35 : 1.0 }
        let span = cycle(lit: lit)
        let t = Double((frame - 8 + span) % span) / Double(span)
        let rise = 0.11
        let shape = t < rise ? (t / rise) : pow(1 - (t - rise) / (1 - rise), 1.9)
        return lit ? 0.55 + 1.55 * shape : 0.30 + 1.32 * shape
    }

    private static func isTwinkling(_ star: (x: Int, y: Int, at: Int), _ frame: Int) -> Bool {
        let d = (frame - star.at + 54) % 54
        return d < 3
    }

    private static func colour(_ ch: Character, gleaming: Bool, lit: Bool) -> Color {
        switch ch {
        case "=": gleaming ? Px.silverShine : Px.silver
        case "o": lit ? Px.rubyLit : Px.ruby
        case "E": lit ? Px.emeraldLit : Px.emerald
        case "e": Px.emeraldLit
        default:  gleaming ? Px.goldShine : Px.goldMetal
        }
    }

    // MARK: the field

    /// The sword sits inside a much larger field so the bloom has somewhere to go. The glow can
    /// only ever be as big as the canvas — a radius past the edge gets clipped into a rectangle —
    /// so making the light bigger means making the field bigger, not the radius.
    ///
    /// `glow: false` shrinks the field to the blade itself, for the small header sword where a
    /// halo three times its width would be absurd.
    private var originX: Int { glow ? 16 : 1 }
    private var originY: Int { glow ? 16 : 1 }
    private var fieldW: Int { glow ? 44 : 14 }
    private var fieldH: Int { glow ? 50 : 20 }

    private static let art: [[Character]] = [
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
        "##eE#oo#Ee##",
        "##EE#oo#EE##",
        ".....##.....",
        ".....##.....",
        ".....##.....",
        "....#eE#....",
        "....#EE#...."
    ].map(Array.init)

    /// Every filled cell of the sword, in **sprite** coordinates. The field origin is added when
    /// drawing, because the field size now depends on whether this instance glows.
    private static let body: [(x: Int, y: Int, ch: Character)] = {
        var out: [(x: Int, y: Int, ch: Character)] = []
        for (y, row) in art.enumerated() {
            for (x, ch) in row.enumerated() where ch != "." {
                out.append((x, y, ch))
            }
        }
        return out
    }()



    /// Glitter sits in the empty margin, never on the blade — fixed positions, staggered through
    /// the cycle. A sprite sheet had no random number generator, and a repeating twinkle is what
    /// reads as animation rather than noise.
    private static let glitter: [(x: Int, y: Int, at: Int)] = [
        (7, 11, 2), (38, 16, 11), (5, 28, 19), (39, 35, 27),
        (10, 43, 34), (36, 45, 41), (22, 4, 47), (32, 7, 15)
    ]
}


/// The dithered light, on its own layer.
///
/// `Equatable` on the quantised brightness step is the whole point: SwiftUI re-evaluates this only
/// when the step actually changes, so the expensive fill loop runs a handful of times per cycle
/// rather than on every animation frame.
private struct GlowLayer: View, Equatable {
    let step: Int
    let fieldW: Int
    let fieldH: Int

    static func == (a: GlowLayer, b: GlowLayer) -> Bool {
        a.step == b.step && a.fieldW == b.fieldW && a.fieldH == b.fieldH
    }

    var body: some View {
        Canvas { ctx, size in
            let px = min(size.width / CGFloat(fieldW), size.height / CGFloat(fieldH))
            let xPad = (size.width - px * CGFloat(fieldW)) / 2
            let yPad = (size.height - px * CGFloat(fieldH)) / 2

            let brightness = Double(step) / 10
            let cx = Double(fieldW - 1) / 2, cy = Double(fieldH - 1) * 0.46
            let maxR = Double(fieldW) / 2

            for gy in 0..<fieldH {
                for gx in 0..<fieldW {
                    let dx = Double(gx) - cx, dy = (Double(gy) - cy) * 0.92
                    let d = (dx * dx + dy * dy).squareRoot() / maxR
                    guard d < 1 else { continue }

                    // A plateau, then a falloff — a real bright mass around the blade rather than
                    // scatter that is as sparse in the middle as it is at the edge.
                    let core = 0.14
                    let t = max(0, (d - core) / (1 - core))
                    let intensity = min(0.78, pow(1 - t, 1.05)) * brightness

                    // Ordered dithering *between adjacent shades* of the ramp: the exact brightness
                    // falls between two palette entries and the Bayer threshold picks which one this
                    // cell takes. Across an area the mix reads as the shade in between.
                    let level = intensity * Double(Px.glowRamp.count)
                    let base = Int(level)
                    let index = (level - Double(base)) > SwordSprite.bayer(gx, gy) ? base + 1 : base
                    guard index > 0 else { continue }

                    ctx.fill(Path(CGRect(x: xPad + CGFloat(gx) * px, y: yPad + CGFloat(gy) * px,
                                         width: px, height: px)),
                             with: .color(Px.glowRamp[min(index - 1, Px.glowRamp.count - 1)]))
                }
            }

            // The hot centre, drawn over the broad glow. Radius is under half the sword's width on
            // purpose: a bright patch smaller than the object reads as the object being the source,
            // whereas a bright patch larger than it reads as a lamp behind it.
            let coreR = Double(fieldW) * 0.085
            for gy in 0..<fieldH {
                for gx in 0..<fieldW {
                    let dx = Double(gx) - cx, dy = (Double(gy) - cy) * 0.92
                    let d = (dx * dx + dy * dy).squareRoot() / coreR
                    guard d < 1 else { continue }

                    let intensity = pow(1 - d, 0.9) * brightness
                    let level = intensity * Double(Px.coreRamp.count)
                    let base = Int(level)
                    let index = (level - Double(base)) > SwordSprite.bayer(gx, gy) ? base + 1 : base
                    guard index > 0 else { continue }

                    ctx.fill(Path(CGRect(x: xPad + CGFloat(gx) * px, y: yPad + CGFloat(gy) * px,
                                         width: px, height: px)),
                             with: .color(Px.coreRamp[min(index - 1, Px.coreRamp.count - 1)]))
                }
            }
        }
        .drawingGroup()   // rasterise once per step, then composite on the GPU
    }
}
