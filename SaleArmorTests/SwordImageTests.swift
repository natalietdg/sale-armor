import XCTest
import SwiftUI
import UIKit

/// Guards the bug that made the shield screen never appear.
///
/// The sword used to be drawn with `ImageRenderer`, which is main-actor isolated, reached from the
/// shield extension through `MainActor.assumeIsolated`. `assumeIsolated` does not check — it
/// asserts. `ShieldConfigurationDataSource` callbacks are not guaranteed to run on the main actor,
/// so off the main thread that assertion was a trap, the extension died, and iOS silently drew its
/// own default panel. Nothing was logged and nothing failed to build; the feature simply looked as
/// though it had never been written.
///
/// So the property worth testing is not what the image looks like. It is that producing it does not
/// require the main actor at all.
final class SwordImageTests: XCTestCase {

    func testSwordRendersOffTheMainActor() async {
        let drawn = await Task.detached(priority: .background) { () -> Bool in
            XCTAssertFalse(Thread.isMainThread, "this test is pointless on the main thread")
            let image = SwordSprite.image()
            return image.size.width > 0 && image.size.height > 0
        }.value

        XCTAssertTrue(drawn, "the shield's sword must be renderable from a background thread")
    }

    func testSwordIsNotBlank() {
        // A blank image would have been the other silent failure: a shield with an empty space
        // where the sword should be, which no build step could have noticed either.
        let image = SwordSprite.image(pixel: 8, padding: 6)
        guard let cg = image.cgImage else { return XCTFail("no bitmap produced") }

        let width = cg.width, height = cg.height
        var pixels = [UInt8](repeating: 0, count: width * height * 4)
        let context = CGContext(data: &pixels, width: width, height: height,
                                bitsPerComponent: 8, bytesPerRow: width * 4,
                                space: CGColorSpaceCreateDeviceRGB(),
                                bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)
        context?.draw(cg, in: CGRect(x: 0, y: 0, width: width, height: height))

        let opaque = stride(from: 3, to: pixels.count, by: 4).filter { pixels[$0] > 200 }.count
        XCTAssertGreaterThan(opaque, width * height / 20,
                             "the sprite covers far too little of the canvas to be a sword")
    }

    func testGridIsRectangular() {
        let widths = Set(SwordSprite.art.map(\.count))
        XCTAssertEqual(widths.count, 1, "every row of the sprite must be the same length")
    }
}

/// Writes the shield artwork to /tmp so it can be looked at.
///
/// The shield screen cannot be seen anywhere except on a device with a guard armed, which makes it
/// the easiest thing in this project to ship broken. Rendering the same bitmap here means the
/// artwork can at least be reviewed without that round trip.
final class ShieldArtPreviewTests: XCTestCase {
    func testWriteShieldPanel() throws {
        let image = ShieldArt.panel()
        let data = try XCTUnwrap(image.pngData())
        try data.write(to: URL(fileURLWithPath: "/tmp/shield-panel.png"))
        XCTAssertGreaterThan(data.count, 1000)
    }
}

/// Renders the wall tile repeated, so the seams can be checked.
///
/// A tile that does not line up is only visible once it repeats, which on the shield means only on
/// a device with a guard armed. Tiling it here makes a broken bond obvious in a file.
final class WallTileTests: XCTestCase {
    func testWallTiles() throws {
        let tile = ShieldArt.wallTile()
        let size = CGSize(width: tile.size.width * 6, height: tile.size.height * 5)
        let sheet = UIGraphicsImageRenderer(size: size).image { ctx in
            UIColor(patternImage: tile).setFill()
            ctx.fill(CGRect(origin: .zero, size: size))
        }
        try XCTUnwrap(sheet.pngData()).write(to: URL(fileURLWithPath: "/tmp/wall-tiled.png"))
        XCTAssertEqual(tile.size.height, tile.size.width * 0.75, accuracy: 0.01,
                       "the repeat unit is one brick wide and two courses tall")
    }
}

/// Writes the shareable card to /tmp so the artwork can be reviewed without arming anything.
final class ShareCardTests: XCTestCase {
    func testWriteShareCards() throws {
        for (name, mode, saved) in [("standard", GuardMode.standard, 0.0),
                                    ("locked", GuardMode.locked, 1340.0)] {
            let window = ArmorWindow(name: "PAYDAY",
                                     pattern: .monthly(days: [25]),
                                     selection: .init(), mode: mode)
            let url = try XCTUnwrap(ShareCard.write(window: window, saved: saved, currency: "RM "))
            let data = try Data(contentsOf: url)
            try data.write(to: URL(fileURLWithPath: "/tmp/card-\(name).png"))
            XCTAssertGreaterThan(data.count, 5000)
        }
    }
}
