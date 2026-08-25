import SwiftUI
import UIKit

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
    /// The emeralds in the crossguard. Jewel-tone rather than mint: a deep stone reads as set into
    /// metal, where a bright one reads as painted onto it.
    static let emerald    = Color(hex: 0x146B45)
    static let emeraldLit = Color(hex: 0x2FA86E)

    /// The shaded sides. One light source means every material needs one.
    /// Panel edges. A surface needs both or it is a rectangle with a line on it.
    static let panelLit   = Color(hex: 0x34344F)
    static let panelShade = Color(hex: 0x0A0A12)

    static let goldShade   = Color(hex: 0xB0862B)
    static let silverShade = Color(hex: 0x8B93AD)
    static let rubyShade   = Color(hex: 0x8E1C2C)
    static let rubyGlint   = Color(hex: 0xFFFFFF)
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
            .pxBevel(light: Px.panelLit, shade: Px.panelShade)
    }
}


/// A one-unit bevel, lit from the upper left.
///
/// The sword reads as three-dimensional because every material has a lit edge and an unlit one and
/// they all agree about where the light is. This is the same rule for flat interface surfaces:
/// a bright line along the top and left, a dark line along the bottom and right. It is the oldest
/// trick in interface drawing — every 8-bit menu and every Win95 button is exactly this — and it
/// costs two rectangles.
///
/// `inset` inverts the light, which is what a pressed control does: a thing pushed in is lit from
/// below. That, and nothing else, is why a pressed button looks pressed.
struct PxBevel: ViewModifier {
    var light: Color
    var shade: Color
    var inset: Bool = false

    private func edge(_ colour: Color) -> some View {
        Rectangle().fill(colour).allowsHitTesting(false)
    }

    func body(content: Content) -> some View {
        let top = inset ? shade : light
        let bottom = inset ? light : shade
        // `allowsHitTesting(false)` on all four, and it is not optional. These are lit and shaded
        // edges — decoration — but an overlay is hit-testable by default, so without this they sit
        // in front of whatever they are decorating and eat taps along every panel and button edge.
        // A tap that lands a few points inside the border of a button simply does nothing, which
        // is indistinguishable from the button being broken.
        return content
            .overlay(alignment: .top)     { edge(top).frame(height: Px.unit / 2) }
            .overlay(alignment: .leading)  { edge(top).frame(width: Px.unit / 2) }
            .overlay(alignment: .bottom)  { edge(bottom).frame(height: Px.unit / 2) }
            .overlay(alignment: .trailing) { edge(bottom).frame(width: Px.unit / 2) }
    }
}

extension Color {
    /// Mixes toward another colour, so a button's lit edge comes from its own tint instead of a
    /// hardcoded highlight per button colour.
    func blend(over other: Color, amount: Double = 0.45) -> Color {
        Color(uiColor: UIColor(self).blended(with: UIColor(other), amount: amount))
    }
}

private extension UIColor {
    func blended(with other: UIColor, amount: CGFloat) -> UIColor {
        var r1: CGFloat = 0, g1: CGFloat = 0, b1: CGFloat = 0, a1: CGFloat = 0
        var r2: CGFloat = 0, g2: CGFloat = 0, b2: CGFloat = 0, a2: CGFloat = 0
        getRed(&r1, green: &g1, blue: &b1, alpha: &a1)
        other.getRed(&r2, green: &g2, blue: &b2, alpha: &a2)
        return UIColor(red: r1 + (r2 - r1) * amount,
                       green: g1 + (g2 - g1) * amount,
                       blue: b1 + (b2 - b1) * amount,
                       alpha: 1)
    }
}

extension View {
    func pxBevel(light: Color, shade: Color, inset: Bool = false) -> some View {
        modifier(PxBevel(light: light, shade: shade, inset: inset))
    }
}

/// **Apple's 44x44pt minimum touch target, added around a control without redrawing it.**
///
/// Small type is part of this alphabet — the footer links are 10pt, which renders about 18pt tall.
/// That is 41% of the minimum, and App Review rejected build 20 for exactly it: "Terms of use and
/// privacy policy links were unresponsive when we tapped them". So the *target* grows and the type
/// does not.
///
/// `contentShape` is the half that is easy to miss. Padding alone is empty space that hit-testing
/// falls straight through, which leaves the target the size of the glyphs it was already too small
/// for. And it has to wrap the control's **label**, not the control: a frame applied outside a
/// `Button` or a `Link` moves the control, it does not widen what the control will accept.
struct PxTapTarget: ViewModifier {
    /// Human Interface Guidelines, not a house preference.
    static let minimum: CGFloat = 44

    func body(content: Content) -> some View {
        content
            .frame(minWidth: Self.minimum, minHeight: Self.minimum)
            .contentShape(Rectangle())
    }
}

extension View {
    /// Apply to a control's label — or, for a `TextField`, to the field itself, which has no
    /// separate label to wrap. See `PxTapTarget`.
    ///
    /// **Apply it after the control's `background`, not before.** The painted chip then keeps the
    /// exact size, colour and type it already had, and only the box the control accepts a finger in
    /// grows. Applied before the background, the gold would grow with the target and every segmented
    /// row in the app would change shape.
    func pxTapTarget() -> some View { modifier(PxTapTarget()) }
}

/// **A screen that centres when it fits and scrolls when it does not.**
///
/// `ArmedView` and `PermissionView` are `Spacer`-centred columns, which is right in portrait at the
/// default text size and has no answer at all to the opposite case. On an iPad in landscape at the
/// largest accessibility text size the column was taller than the screen, so the `VStack` compressed
/// its children, truncated their text, and pushed the tab bar to y −115 and the Terms and Privacy
/// links to y 1154 on a 1024pt screen — off both ends, with no gesture that could reach either.
/// That is build 20's unreachable-policy-links rejection (2.1(a), 3.1.2(c)) through a second door.
///
/// A plain `ScrollView` fixes reachability and breaks the portrait look, because a `Spacer` inside
/// one has no height to claim and the content collects at the top of the screen. So the content is
/// handed the viewport's height as a **minimum**: it still centres while there is room, and grows
/// past the fold — scrollable — once there is not.
struct PxCenteredScroll<Content: View>: View {
    @ViewBuilder var content: Content

    var body: some View {
        GeometryReader { viewport in
            ScrollView {
                content.frame(maxWidth: .infinity, minHeight: viewport.size.height)
            }
        }
    }
}

/// **A mark the typeface cannot draw.**
///
/// Pixelify Sans has no padlock and no right-pointing triangle, so `Text("🔒")` and `Text("▶")` came
/// out as the missing-character box in every orientation — and shipped that way into the App Store
/// screenshots. It is the same failure the mode checkbox hit with ◼/◻ (see `ArmView.modeOption`),
/// and it takes the same answer: draw the mark on the grid rather than borrowing a system font,
/// which would be the only un-pixelated glyph on the screen.
///
/// The art is a character grid so it stays legible in source and editable without a tool, exactly
/// like `SwordSprite.art`. `#` is a filled pixel, `.` is empty.
struct PxGlyph: View {
    enum Mark {
        case lock, play

        var art: [[Character]] {
            switch self {
            case .lock: [
                "..###..",
                ".##.##.",
                ".#...#.",
                ".#...#.",
                "#######",
                "###.###",
                "###.###",
                "#######"
            ].map(Array.init)
            case .play: [
                "#....",
                "##...",
                "###..",
                "####.",
                "#####",
                "####.",
                "###..",
                "##...",
                "#...."
            ].map(Array.init)
            }
        }
    }

    let mark: Mark
    let colour: Color
    /// How tall the mark is drawn at the default text size. `ScaledMetric` grows it with Dynamic
    /// Type, so it keeps pace with the word beside it instead of shrinking into a speck.
    @ScaledMetric private var height: CGFloat

    init(_ mark: Mark, height: CGFloat, colour: Color) {
        self.mark = mark
        self.colour = colour
        _height = ScaledMetric(wrappedValue: height)
    }

    var body: some View {
        let art = mark.art
        // Snapped to half a point — a whole device pixel at both 2x and 3x. A fractional one is the
        // only way to blur pixel art.
        let pixel = max(0.5, (height / CGFloat(art.count) * 2).rounded() / 2)
        Canvas { ctx, _ in
            for (y, row) in art.enumerated() {
                for (x, ch) in row.enumerated() where ch == "#" {
                    ctx.fill(Path(CGRect(x: CGFloat(x) * pixel, y: CGFloat(y) * pixel,
                                         width: pixel, height: pixel)),
                             with: .color(colour))
                }
            }
        }
        .frame(width: pixel * CGFloat(art[0].count), height: pixel * CGFloat(art.count))
        // The words beside every one of these already carry the meaning — "LOCKED", "Choose apps" —
        // so reading the mark aloud as well would only be noise.
        .accessibilityHidden(true)
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
            .pxBevel(light: tint.opacity(0.55).blend(over: Px.silverShine),
                     shade: Px.bg.opacity(0.42), inset: down)
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
                    .lineLimit(1)
                    .fixedSize(horizontal: true, vertical: false)
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
/// One light source, upper left, and every material gets a lit edge and an unlit one — that is
/// the whole of what makes a flat grid read as three-dimensional.
///
/// `H` gold highlight, `#` gold, `+` gold shadow. `=` the blade's lit core, `w` its shaded side.
/// `*` the ruby's white glint, `O` ruby, `o` ruby shadow. `E`/`e` emerald and its lit facet.
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

    /// The 8×8 ordered-dither threshold matrix.
    ///
    /// This was 4×4, and 4×4 is why the glow looked patchy. Sixteen thresholds means the blend
    /// between two adjacent shades of the ramp can only be made in sixteenths, so a region whose
    /// true brightness sits between two shades gets a coarse checker — and where the lower shade
    /// is "nothing at all", that checker is a hole. At the scale this glow is drawn, a repeating
    /// 4×4 cell is large enough to read as a blotch rather than as a texture.
    ///
    /// 8×8 gives sixty-four thresholds. The same fade now has four times the gradation and the
    /// repeating unit is small enough to disappear, which is the entire job of a dither.
    private static let bayerMatrix: [[Double]] = [
        [ 0, 32,  8, 40,  2, 34, 10, 42],
        [48, 16, 56, 24, 50, 18, 58, 26],
        [12, 44,  4, 36, 14, 46,  6, 38],
        [60, 28, 52, 20, 62, 30, 54, 22],
        [ 3, 35, 11, 43,  1, 33,  9, 41],
        [51, 19, 59, 27, 49, 17, 57, 25],
        [15, 47,  7, 39, 13, 45,  5, 37],
        [63, 31, 55, 23, 61, 29, 53, 21]
    ].map { $0.map { ($0 + 0.5) / 64 } }

    static func bayer(_ x: Int, _ y: Int) -> Double {
        bayerMatrix[y % 8][x % 8]
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

    static func colour(_ ch: Character, gleaming: Bool, lit: Bool) -> Color {
        switch ch {
        case "=": gleaming ? Px.silverShine : Px.silver
        case "w": gleaming ? Px.silver : Px.silverShade
        case "H": Px.goldShine
        case "+": Px.goldShade
        case "*": Px.rubyGlint           // the white catchlight — a gem without one looks painted
        case "O": lit ? Px.rubyLit : Px.ruby
        case "o": Px.rubyShade
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

    static let art: [[Character]] = [
        ".....H+.....",
        ".....H+.....",
        "....H=w+....",
        "....H=w+....",
        "....H=w+....",
        "....H=w+....",
        "....H=w+....",
        "....H=w+....",
        "....H=w+....",
        "....H=w+....",
        "....H=w+....",
        "H#eEH*OHeE#+",
        "++EE#Oo#EE++",
        ".....H+.....",
        ".....H+.....",
        ".....H+.....",
        "....H##+....",
        "....#++#...."
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

/// The sword as a plain image, drawn with Core Graphics.
///
/// **Why not `ImageRenderer`.** The shield extension needs this sprite, and it runs inside a
/// sandboxed XPC service whose data-source callbacks are not guaranteed to be on the main actor.
/// `ImageRenderer` is main-actor isolated, so reaching it from there meant `MainActor.assumeIsolated`
/// — which does not check, it *asserts*. Off the main thread that is a trap, a trap is a crash, and
/// a shield extension that crashes is not reported anywhere: iOS quietly draws its own default
/// screen instead. The symptom is a missing feature with no error attached to it.
///
/// `UIGraphicsImageRenderer` has no actor requirement, so this is callable from anywhere. It also
/// draws from the same `art` grid and the same palette as the animated view, which is the property
/// that mattered about `ImageRenderer` in the first place.

/// The shield screen's artwork, composed into a single bitmap.
///
/// **Why everything is one image.** `ShieldConfiguration` exposes a flat `backgroundColor`, a
/// `UIImage` icon, and labels that carry a string and a colour and nothing else — no font, no
/// background image, no layout. So the wall, the glow, the sword and the word ARMED cannot be
/// separate elements the way they are in the app. Either they are painted together into the one
/// bitmap the API accepts, or the screen is a system font on a flat colour.
///
/// The subtitle stays a real label: it changes with the armed window, and text baked into a bitmap
/// cannot be read by VoiceOver. The headline is baked because it never changes and because it is
/// the word the whole screen is for.
enum ShieldArt {

    /// Only exists so `Bundle(for:)` can find the bundle this code was compiled into.
    private final class BundleToken {}

    /// Bricks, glow, sword and headline, at the proportions the shield draws an icon.
    static func panel(width: CGFloat = 380, height: CGFloat = 380) -> UIImage {
        // The wall goes back inside the icon, because iOS discards `backgroundColor` on this screen
        // entirely — a screenshot of the shipped shield measured #222224 at every corner while the
        // colour passed was #0F0F1B. A pattern colour is discarded for the same reason a flat one
        // is. The icon is the only surface this extension actually controls, so everything the
        // screen shows of Sale Armor has to be painted into it.
        let format = UIGraphicsImageRendererFormat.default()
        format.opaque = true
        format.scale = 3

        return UIGraphicsImageRenderer(size: CGSize(width: width, height: height),
                                       format: format).image { ctx in
            let cg = ctx.cgContext
            UIColor(Px.bg).setFill()
            cg.fill(CGRect(x: 0, y: 0, width: width, height: height))
            wall(cg, width, height)
            halo(cg, width, height)
            blade(cg, width, height, centreY: 0.5, fill: 0.78)
            headline(cg, width, height)
        }
    }

    /// The app's wall, at the app's own brick size relative to this bitmap.
    static func wall(_ cg: CGContext, _ w: CGFloat, _ h: CGFloat) {
        let bw = Px.unit * 8, bh = Px.unit * 3, mortar = Px.unit / 2
        for row in 0...Int(h / bh) + 1 {
            let shift = row % 2 == 0 ? 0 : bw / 2
            for col in -1...Int(w / bw) + 1 {
                let odd = (row &* 7 &+ col &* 13) % 9 == 0
                UIColor(odd ? Px.brickOdd : Px.brick).setFill()
                cg.fill(CGRect(x: CGFloat(col) * bw + shift + mortar, y: CGFloat(row) * bh + mortar,
                               width: bw - mortar, height: bh - mortar))
            }
        }
    }

    /// The dithered halo, on the same 8×8 threshold matrix the animated version uses, drawn at its
    /// brightest frame. A still image cannot pulse, so it takes the top of the flare rather than an
    /// average — a glow caught mid-fade just looks dim.
    static func halo(_ cg: CGContext, _ w: CGFloat, _ h: CGFloat, centreY: Double = 0.46) {
        let cell: CGFloat = 8
        let cols = Int(w / cell), rows = Int(h / cell)
        let cx = Double(cols - 1) / 2, cy = Double(rows - 1) * centreY
        let maxR = Double(cols) / 2.6

        for gy in 0..<rows {
            for gx in 0..<cols {
                let dx = Double(gx) - cx, dy = (Double(gy) - cy) * 0.92
                let d = (dx * dx + dy * dy).squareRoot() / maxR
                guard d < 1 else { continue }

                let core = 0.14
                let t = max(0, (d - core) / (1 - core))
                let intensity = min(0.78, pow(1 - t, 1.05)) * 1.35
                let level = intensity * Double(Px.glowRamp.count)
                let base = Int(level)
                let index = (level - Double(base)) > SwordSprite.bayer(gx, gy) ? base + 1 : base
                guard index > 0 else { continue }

                UIColor(Px.glowRamp[min(index - 1, Px.glowRamp.count - 1)]).setFill()
                cg.fill(CGRect(x: CGFloat(gx) * cell, y: CGFloat(gy) * cell,
                               width: cell, height: cell))
            }
        }
    }

    /// ARMED, in the app's own face.
    ///
    /// `ShieldConfiguration.Label` carries a string and a colour and no font, so the only way to
    /// set this word in Pixelify Sans is to draw it into the bitmap and leave the real title nil.
    /// Only the headline is treated this way: the subtitle changes with the armed window and stays
    /// a proper label, because text painted into an image cannot be read aloud by VoiceOver.
    private static func headline(_ cg: CGContext, _ w: CGFloat, _ h: CGFloat) {
        let text = "ARMED."
        let font = pixelFont(52)
        let attributes: [NSAttributedString.Key: Any] = [
            .font: font,
            .foregroundColor: UIColor(Px.gold),
            .kern: 2
        ]
        let size = (text as NSString).size(withAttributes: attributes)
        (text as NSString).draw(at: CGPoint(x: (w - size.width) / 2, y: h - size.height - 18),
                                withAttributes: attributes)
    }

    /// Pixelify Sans, registered from this bundle rather than assumed to be present.
    ///
    /// Two traps sit here. The face is a **variable** font whose only named instance is Regular, so
    /// asking for "PixelifySans-Bold" returns nil and UIKit substitutes the system font without
    /// saying so — the failure looks like "the font didn't apply". And `UIAppFonts` registers fonts
    /// for the bundle that declares it, so a font that works in the app is simply absent in an
    /// extension or a test bundle. Registering explicitly removes both, and the weight comes from
    /// the variable axis afterwards.
    private static let pixelFontRegistered: Bool = {
        for bundle in [Bundle(for: BundleToken.self), Bundle.main] {
            guard let url = bundle.url(forResource: "PixelifySans", withExtension: "ttf"),
                  let data = try? Data(contentsOf: url),
                  let provider = CGDataProvider(data: data as CFData),
                  let font = CGFont(provider) else { continue }
            var error: Unmanaged<CFError>?
            if CTFontManagerRegisterGraphicsFont(font, &error) { return true }
            // Already registered by UIAppFonts is a success, not a failure.
            if let code = error?.takeUnretainedValue(), CFErrorGetCode(code) == 105 { return true }
        }
        return false
    }()

    /// The same weight the app draws, not merely the same family.
    ///
    /// `Font.px` asks SwiftUI for `.weight(.bold)`, and on a variable font that drives the `wght`
    /// axis. The UIKit equivalent — a weight *trait* on the descriptor — does not: it picks or
    /// synthesises a face instead, which is why the shield's ARMED came out in visibly different
    /// letterforms from every other pixel word in the app. Setting the axis explicitly is what
    /// makes the two identical.
    static func pixelFont(_ size: CGFloat) -> UIFont {
        _ = pixelFontRegistered
        guard UIFont(name: "PixelifySans-Regular", size: size) != nil else {
            return .systemFont(ofSize: size, weight: .black)
        }
        let wght = 2_003_265_652   // the four-character axis tag 'wght'
        let descriptor = UIFontDescriptor(fontAttributes: [
            .name: "PixelifySans-Regular",
            kCTFontVariationAttribute as UIFontDescriptor.AttributeName: [wght: 700]
        ])
        return UIFont(descriptor: descriptor, size: size)
    }

    /// The wall, as a tile that can be used as a pattern colour.
    ///
    /// **This is how the shield gets a background at all.** `ShieldConfiguration.backgroundColor`
    /// takes a `UIColor`, and a `UIColor` can be a *pattern* — so a seamlessly tiling brick image
    /// becomes a full-screen wall rather than a flat fill. Without it the wall could only ever be
    /// the small square the system allots the icon.
    ///
    /// The tile is one brick wide and two courses tall, with the second course offset by half a
    /// brick, which is exactly the repeat unit of a running bond. The app's one-in-nine shade
    /// variation is left out here: in a tile it would repeat on a grid and read as a pattern
    /// rather than as masonry.
    static func wallTile() -> UIImage {
        // Exactly the app's brick, not a bigger one. `PxBricks` uses Px.unit * 8 by Px.unit * 3
        // with a half-unit mortar; at Px.unit = 4 that is 32 by 12 points. The first version of
        // this tile was 64 by 24 — double — and a pattern colour tiles at the image's *point* size,
        // so the shield's wall came out at twice the scale of the wall in the app it interrupts.
        let bw = Px.unit * 8, bh = Px.unit * 3, mortar = Px.unit / 2
        let format = UIGraphicsImageRendererFormat.default()
        format.opaque = true
        format.scale = 3

        return UIGraphicsImageRenderer(size: CGSize(width: bw, height: bh * 2),
                                       format: format).image { ctx in
            let cg = ctx.cgContext
            UIColor(Px.bg).setFill()
            cg.fill(CGRect(x: 0, y: 0, width: bw, height: bh * 2))
            UIColor(Px.brick).setFill()

            // Course one, flush. Course two, offset by half a brick and drawn three times so the
            // halves at either edge meet their partners when the tile repeats.
            cg.fill(CGRect(x: mortar, y: mortar, width: bw - mortar, height: bh - mortar))
            for dx in [-bw / 2, bw / 2] {
                cg.fill(CGRect(x: dx + mortar, y: bh + mortar, width: bw - mortar, height: bh - mortar))
            }
        }
    }

    /// The sprite, centred, at the largest whole-pixel size that fits the panel. Whole pixels
    /// matter more here than filling the space: a fractional size is what turns pixel art to mush.
    static func blade(_ cg: CGContext, _ w: CGFloat, _ h: CGFloat,
                      centreY: Double = 0.5, fill: CGFloat = 0.78) {
        let rows = SwordSprite.art
        let unit = floor(min(w / CGFloat(rows[0].count) * fill, h / CGFloat(rows.count) * fill))
        let originX = (w - CGFloat(rows[0].count) * unit) / 2
        let originY = h * CGFloat(centreY) - CGFloat(rows.count) * unit / 2

        for (y, row) in rows.enumerated() {
            for (x, ch) in row.enumerated() where ch != "." {
                UIColor(SwordSprite.colour(ch, gleaming: false, lit: false)).setFill()
                cg.fill(CGRect(x: originX + CGFloat(x) * unit, y: originY + CGFloat(y) * unit,
                               width: unit, height: unit))
            }
        }
    }
}

extension SwordSprite {
    static func image(pixel: CGFloat = 8, padding: CGFloat = 6, lit: Bool = false) -> UIImage {
        let rows = art
        let w = CGFloat(rows[0].count) * pixel + padding * 2
        let h = CGFloat(rows.count) * pixel + padding * 2

        let format = UIGraphicsImageRendererFormat.default()
        format.opaque = false
        format.scale = 3          // whole squares: a fractional scale is the only way to blur this

        return UIGraphicsImageRenderer(size: CGSize(width: w, height: h), format: format).image { ctx in
            for (y, row) in rows.enumerated() {
                for (x, ch) in row.enumerated() where ch != "." {
                    UIColor(colour(ch, gleaming: false, lit: lit)).setFill()
                    ctx.fill(CGRect(x: padding + CGFloat(x) * pixel,
                                    y: padding + CGFloat(y) * pixel,
                                    width: pixel, height: pixel))
                }
            }
        }
    }
}

/// A shareable card, drawn rather than typed.
///
/// **What it deliberately cannot say.** It never names an app. iOS gives this app opaque
/// `ApplicationToken` values and no way to resolve them, so "which apps you tried to open" does not
/// exist anywhere in the system for us to put on a card — and the privacy claim on the website and
/// in the App Store listing rests on exactly that. What it can show is the part that is ours: the
/// guard, when it ends, and what has stayed in the account.
enum ShareCard {

    /// The card, as an image rather than a file.
    ///
    /// Sharing a file URL was the first attempt and it is wrong: Messages and WhatsApp treat a
    /// `.png` on disk as a **document** and send it as an attachment tile with a filename, not as a
    /// picture in the conversation. SwiftUI's `Image` is `Transferable` as image data, which is
    /// what those apps inline. Same bitmap, entirely different result at the other end.
    static func image(window: ArmorWindow, saved: Double, currency: String) -> UIImage {
        render(window: window, saved: saved, currency: currency)
    }

    /// Still useful for writing a copy out in tests, where a file is the point.
    static func write(window: ArmorWindow, saved: Double, currency: String) -> URL? {
        guard let data = render(window: window, saved: saved, currency: currency).pngData() else { return nil }
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("sale-armor-guard.png")
        do { try data.write(to: url); return url } catch { return nil }
    }

    private static func render(window: ArmorWindow, saved: Double, currency: String) -> UIImage {
        let w: CGFloat = 540, h: CGFloat = 540
        let format = UIGraphicsImageRendererFormat.default()
        format.opaque = true
        format.scale = 3

        return UIGraphicsImageRenderer(size: CGSize(width: w, height: h), format: format).image { ctx in
            let cg = ctx.cgContext
            UIColor(Px.bg).setFill()
            cg.fill(CGRect(x: 0, y: 0, width: w, height: h))
            ShieldArt.wall(cg, w, h)

            // Sword and halo, reusing the shield's composition so a shared card and a blocked
            // screen are recognisably the same object.
            ShieldArt.halo(cg, w, h, centreY: 0.34)
            ShieldArt.blade(cg, w, h, centreY: 0.34, fill: 0.30)

            let gold = UIColor(Px.gold), dim = UIColor(Px.dim), ink = UIColor(Px.ink)
            line(window.mode == .locked ? "LOCKED" : "ARMED",
                 font: ShieldArt.pixelFont(44), colour: gold, y: h * 0.60, width: w)
            line(window.name.isEmpty ? "THE GUARD" : window.name.uppercased(),
                 font: ShieldArt.pixelFont(24), colour: ink, y: h * 0.685, width: w)
            line(until(window), font: ShieldArt.pixelFont(17), colour: dim, y: h * 0.745, width: w)

            if saved > 0 {
                line(currency + amount(saved), font: ShieldArt.pixelFont(30), colour: gold,
                     y: h * 0.800, width: w)
                line("NOT SPENT", font: ShieldArt.pixelFont(15), colour: dim, y: h * 0.862, width: w)
            }
            line("SALE ARMOR", font: ShieldArt.pixelFont(13), colour: dim, y: h - 34, width: w)
        }
    }

    private static func line(_ text: String, font: UIFont, colour: UIColor, y: CGFloat, width: CGFloat) {
        let attributes: [NSAttributedString.Key: Any] = [.font: font, .foregroundColor: colour, .kern: 1.5]
        let size = (text as NSString).size(withAttributes: attributes)
        (text as NSString).draw(at: CGPoint(x: (width - size.width) / 2, y: y), withAttributes: attributes)
    }

    private static func until(_ window: ArmorWindow) -> String {
        switch window.pattern {
        case let .daily(from, to):     return "EVERY DAY \(from.text)-\(to.text)"
        case let .weekly(_, from, to): return "SOME DAYS \(from.text)-\(to.text)"
        case .monthly:                 return "THE DAYS MY MONEY LANDS"
        case .doubleDates:             return "EVERY DOUBLE-DATE SALE"
        case .dateRange:               return "UNTIL IT ENDS"
        }
    }

    private static func amount(_ value: Double) -> String {
        let f = NumberFormatter()
        f.numberStyle = .decimal
        f.maximumFractionDigits = 0
        return f.string(from: NSNumber(value: value)) ?? "0"
    }
}
