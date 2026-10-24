import Cocoa

// ───────────────────────────────── view ───────────────────────────────────

final class GooseView: NSView {
    var goose: Goose!
    var anchor = ANCHOR
    var onGrab: ((NSPoint) -> Void)?
    var onDrag: ((NSPoint) -> Void)?
    var onRelease: (() -> Void)?

    override var isFlipped: Bool { false }
    override var acceptsFirstResponder: Bool { true }
    override func acceptsFirstMouse(for e: NSEvent?) -> Bool { true }

    /// Only this patch of the window is clickable; everything else stays click-through.
    var hitRect: NSRect {
        NSRect(x: anchor.x - 58 + goose.dir * 6, y: max(0, anchor.y - 16), width: 116, height: 120)
    }

    override func mouseDown(with e: NSEvent) { onGrab?(e.locationInWindow) }
    override func mouseDragged(with e: NSEvent) { onDrag?(NSEvent.mouseLocation) }
    override func mouseUp(with e: NSEvent) { onRelease?() }

    override func draw(_ dirty: NSRect) {
        paintGoose(goose, at: anchor)
    }
}

/// Same trick as GooseView: a window-sized view where only the fish takes clicks.
final class FishView: NSView {
    var fish: (() -> Fish?)!
    var onGrab: (() -> Void)?
    var onDrag: ((NSPoint) -> Void)?
    var onRelease: (() -> Void)?

    override var isFlipped: Bool { false }
    override func acceptsFirstMouse(for e: NSEvent?) -> Bool { true }

    var hitRect: NSRect {
        NSRect(x: FISH_ANCHOR.x - 26, y: 0, width: 52, height: 28)
    }

    override func mouseDown(with e: NSEvent) { onGrab?() }
    override func mouseDragged(with e: NSEvent) { onDrag?(NSEvent.mouseLocation) }
    override func mouseUp(with e: NSEvent) { onRelease?() }

    override func draw(_ dirty: NSRect) {
        guard let f = fish(), !f.gone else { return }
        paintFish(f, at: FISH_ANCHOR)
    }
}

/// Eggs and goslings get one of these each: draws itself, and optionally
/// reports a click on a small patch of the window.
final class PropView: NSView {
    var render: (() -> Void)?
    var hit: NSRect = .zero
    var onDown: (() -> Void)?
    var onDrag: ((NSPoint) -> Void)?
    var onUp: (() -> Void)?

    override var isFlipped: Bool { false }
    override func acceptsFirstMouse(for e: NSEvent?) -> Bool { true }
    override func mouseDown(with e: NSEvent) { onDown?() }
    override func mouseDragged(with e: NSEvent) { onDrag?(NSEvent.mouseLocation) }
    override func mouseUp(with e: NSEvent) { onUp?() }
    override func draw(_ dirty: NSRect) { render?() }
}

// ───────────────────────────────── sprite sheet preview ───────────────────

enum Sheet {
    static func render(to path: String) {
        let tileW = 180, tileH = 190
        struct Pose {
            let name: String
            let setup: (Goose) -> Void
            var fishAt: CGPoint? = nil          // offset from the goose's feet
            var fishHeld = false
        }
        let poses: [Pose] = [
            Pose(name: "idle",  setup: { $0.act = .idle }),
            Pose(name: "walk1", setup: { $0.act = .walk; $0.phase = 0.6 }),
            Pose(name: "walk2", setup: { $0.act = .walk; $0.phase = 1.7 }),
            Pose(name: "blink", setup: { $0.act = .idle; $0.blinkLeft = 0.1 }),
            Pose(name: "sit",   setup: { $0.act = .sit }),
            Pose(name: "peck",  setup: { $0.act = .peck; $0.headDip = 1 }),
            Pose(name: "honk",  setup: { $0.act = .honk; $0.beakOpen = 1; $0.bubbleText = "HONK!"; $0.bubbleLeft = 2 }),
            Pose(name: "fly",   setup: { $0.act = .fly; $0.clock = 0.09 }),
            Pose(name: "held",  setup: { $0.act = .held; $0.clock = 0.2; $0.bubbleText = "HEY!"; $0.bubbleLeft = 2 }),
            Pose(name: "pet",   setup: { $0.act = .idle; $0.blinkLeft = 0.1; $0.bubbleText = "\u{2665}"; $0.bubbleLeft = 2
                                         $0.hearts = [(x: -18, y: 62, life: 1), (x: 14, y: 78, life: 1), (x: 0, y: 96, life: 0.5)] }),
            Pose(name: "chase", setup: { $0.act = .run; $0.phase = 0.6 },
                 fishAt: CGPoint(x: 52, y: 70), fishHeld: true),
            Pose(name: "angry", setup: { $0.act = .idle; $0.anger = 1; $0.clock = 0.175 },
                 fishAt: CGPoint(x: 64, y: 104), fishHeld: true),
            Pose(name: "eat",   setup: { $0.act = .eat; $0.headDip = 1; $0.beakOpen = 0.6 },
                 fishAt: CGPoint(x: 30, y: 14)),
            Pose(name: "yum",   setup: { $0.act = .honk; $0.beakOpen = 1; $0.bubbleText = "YUM!"; $0.bubbleLeft = 2
                                         $0.hearts = [(x: -16, y: 66, life: 1), (x: 16, y: 84, life: 1)] })
        ]
        let cols = 5
        let rows = (poses.count + cols - 1) / cols
        let W = tileW * cols, H = tileH * rows

        guard let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: W, pixelsHigh: H,
                                         bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true,
                                         isPlanar: false, colorSpaceName: .deviceRGB,
                                         bytesPerRow: 0, bitsPerPixel: 0) else { return }
        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)

        NSColor(srgbRed: 0.13, green: 0.14, blue: 0.18, alpha: 1).setFill()
        NSRect(x: 0, y: 0, width: W, height: H).fill()

        for (i, pose) in poses.enumerated() {
            let cx = i % cols, cy = i / cols
            let ox = CGFloat(cx * tileW), oy = CGFloat(H - (cy + 1) * tileH)
            NSColor(srgbRed: 0.18, green: 0.19, blue: 0.24, alpha: 1).setFill()
            NSRect(x: ox + 2, y: oy + 2, width: CGFloat(tileW - 4), height: CGFloat(tileH - 4)).fill()

            let g = Goose()
            g.dir = 1
            pose.setup(g)
            let base = CGPoint(x: ox + CGFloat(tileW) / 2, y: oy + 24)
            paintGoose(g, at: base)
            if let fp = pose.fishAt {
                let f = Fish(x: base.x + fp.x, y: base.y + fp.y)
                f.held = pose.fishHeld
                f.resting = !pose.fishHeld
                f.clock = 0.08
                f.dir = -1
                paintFish(f, at: CGPoint(x: f.x, y: f.y))
            }

            let attrs: [NSAttributedString.Key: Any] = [
                .font: NSFont.monospacedSystemFont(ofSize: 11, weight: .medium),
                .foregroundColor: NSColor.white.withAlphaComponent(0.55)
            ]
            NSAttributedString(string: pose.name, attributes: attrs).draw(at: NSPoint(x: ox + 8, y: oy + 6))
        }

        NSGraphicsContext.restoreGraphicsState()
        if let data = rep.representation(using: .png, properties: [:]) {
            try? data.write(to: URL(fileURLWithPath: path))
        }
    }
}


// ───────────────────────────────── app icon ──────────────────────────────

enum Icon {
    /// One goose on a rounded sky-blue tile.
    static func rep(size: Int) -> NSBitmapImageRep? {
        guard let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: size, pixelsHigh: size,
                                         bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true,
                                         isPlanar: false, colorSpaceName: .deviceRGB,
                                         bytesPerRow: 0, bitsPerPixel: 0) else { return nil }
        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)

        let S = CGFloat(size)
        let inset = S * 0.055
        let tile = NSBezierPath(roundedRect: NSRect(x: inset, y: inset, width: S - inset * 2, height: S - inset * 2),
                                xRadius: S * 0.21, yRadius: S * 0.21)
        NSGradient(starting: NSColor(srgbRed: 0.64, green: 0.87, blue: 0.97, alpha: 1),
                   ending:   NSColor(srgbRed: 0.33, green: 0.62, blue: 0.87, alpha: 1))?.draw(in: tile, angle: -90)

        let g = Goose()
        g.act = .idle
        g.dir = 1
        let canvas = composeGoose(g)
        let scale = (S * 0.70) / CGFloat(CANVAS_H)
        canvas.render(at: CGPoint(x: (S - CGFloat(CANVAS_W) * scale) / 2,
                                  y: S * 0.17 - CGFloat(CANVAS_BOTTOM_PAD) * scale),
                      scale: scale, flip: false)

        NSGraphicsContext.restoreGraphicsState()
        return rep
    }

    static func writeIconset(_ dir: String) {
        let fm = FileManager.default
        try? fm.createDirectory(atPath: dir, withIntermediateDirectories: true)

        // render once at full size, downsample from it so small icons stay clean
        guard let big = rep(size: 1024) else { return }
        let bigImage = NSImage(size: NSSize(width: 1024, height: 1024))
        bigImage.addRepresentation(big)

        let wanted: [(String, Int)] = [
            ("icon_16x16", 16), ("icon_16x16@2x", 32),
            ("icon_32x32", 32), ("icon_32x32@2x", 64),
            ("icon_128x128", 128), ("icon_128x128@2x", 256),
            ("icon_256x256", 256), ("icon_256x256@2x", 512),
            ("icon_512x512", 512), ("icon_512x512@2x", 1024)
        ]
        for (name, px) in wanted {
            let out: NSBitmapImageRep
            if px == 1024 {
                out = big
            } else {
                guard let r = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: px, pixelsHigh: px,
                                               bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true,
                                               isPlanar: false, colorSpaceName: .deviceRGB,
                                               bytesPerRow: 0, bitsPerPixel: 0) else { continue }
                NSGraphicsContext.saveGraphicsState()
                NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: r)
                NSGraphicsContext.current?.imageInterpolation = .high
                bigImage.draw(in: NSRect(x: 0, y: 0, width: px, height: px))
                NSGraphicsContext.restoreGraphicsState()
                out = r
            }
            if let data = out.representation(using: .png, properties: [:]) {
                try? data.write(to: URL(fileURLWithPath: dir + "/" + name + ".png"))
            }
        }
    }
}
