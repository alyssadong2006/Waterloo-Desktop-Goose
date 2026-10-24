import Cocoa

let COYOTE_PIX: CGFloat = 1.65
let COYOTE_WIN_W: CGFloat = 190, COYOTE_WIN_H: CGFloat = 150
let COYOTE_ANCHOR = CGPoint(x: 95, y: 0)
let COYOTE_CAST_CHARGE: Double = 0.25
let COYOTE_CAST_JUMP: Double = 0.65
let COYOTE_CAST_TOTAL: Double = 1.05
let COYOTE_CAST_COOL: Double = 2.5
let COYOTE_STUCK_WAIT: Double = 0.85
let COYOTE_RETREAT_SPEED: CGFloat = 225 // just faster than mother's ~201 px/s charge

final class Coyote {
    var x: CGFloat, y: CGFloat
    var vx: CGFloat = 0, vy: CGFloat = 0, dir: CGFloat = 1
    var health = 10
    var support: Ledge?
    var grounded = false, held = false
    var clock: Double = 0, phase: Double = 0
    var biteCool: Double = 0, hurtCool: Double = 0, stuckFor: Double = 0
    var cast: Double = -1, castCool: Double = 0, wizardFade: Double = 0
    var jumped = false
    var destX: CGFloat = 0, destY: CGFloat = 0
    private var retreatDir: CGFloat = 0
    var casting: Bool { cast >= 0 }

    init(x: CGFloat, y: CGFloat) { self.x = x; self.y = y }

    func step(_ dt: Double, chicks: [Chick], goose: Goose, ledges: [Ledge], screen: NSScreen) {
        guard health > 0, !held else { return }
        clock += dt
        biteCool = max(0, biteCool - dt)
        hurtCool = max(0, hurtCool - dt)
        castCool = max(0, castCool - dt)
        if cast >= 0 {
            cast += dt
            if !jumped && cast >= COYOTE_CAST_JUMP {
                jumped = true
                x = destX; y = destY; vx = 0; vy = 0; grounded = false; support = nil
            }
            if cast >= COYOTE_CAST_TOTAL { cast = -1; jumped = false; castCool = COYOTE_CAST_COOL }
            return
        }
        if wizardFade > 0 { wizardFade = max(0, wizardFade - dt / HAT_FADE) }

        let living = chicks.filter { $0.health > 0 }
        let target = living.min { a, b in
            hypot(a.x - x, a.y - y) < hypot(b.x - x, b.y - y)
        }
        let gooseDistance = hypot(goose.x - x, goose.y - y)

        // Keep one escape direction while there is no prey. Recomputing it from
        // the actors' positions every frame makes the sign flip whenever mother
        // catches up, leaving both of them jittering around the same point.
        if target != nil {
            retreatDir = 0
        } else if retreatDir == 0 {
            retreatDir = x >= goose.x ? 1 : -1
        }
        let currentRetreatX = retreatDir > 0 ? screen.frame.maxX - 50 : screen.frame.minX + 50
        if target == nil, gooseDistance < 175, castCool <= 0, abs(x - currentRetreatX) < 70 {
            // Mother caught it at its chosen edge; cross to the other side once
            // magic is ready, rather than toggling direction while cornered.
            retreatDir *= -1
        }
        let retreatX = retreatDir > 0 ? screen.frame.maxX - 50 : screen.frame.minX + 50
        let targetX = target?.x ?? retreatX
        let targetY = target?.y ?? screen.visibleFrame.minY
        let preyDX = targetX - x, dy = targetY - y
        let motherBetween = target != nil
            && ((x < goose.x && goose.x < targetX) || (targetX < goose.x && goose.x < x))
            && abs(goose.y - y) < 120
        let threatened = gooseDistance < 175 || motherBetween
        let evading = target == nil || threatened

        // A wizard coyote does not keep charging directly through mother. Blink
        // to safety when she gets close; while magic is cooling down, sprint away.
        if threatened, castCool <= 0 {
            let targetSide: CGFloat = targetX >= goose.x ? 1 : -1
            cast = 0; jumped = false; wizardFade = 1; stuckFor = 0
            destX = min(max(targetX - targetSide * 55, screen.frame.minX + 50), screen.frame.maxX - 50)
            destY = targetY
            return
        }
        var moveX = targetX
        if evading {
            let away: CGFloat = target == nil ? retreatDir : (x >= goose.x ? 1 : -1)
            moveX = x + away * 400
        }
        let dx = moveX - x
        if abs(dx) > 5 { dir = dx > 0 ? 1 : -1 }

        if let ch = target, abs(preyDX) < 56, abs(dy) < 55, biteCool <= 0 {
            ch.health -= 1
            health = min(10, health + 1)
            biteCool = 1.15
            vx = -dir * 90
        }

        let unreachable = abs(preyDX) > 560 || abs(dy) > 150
        stuckFor = unreachable ? stuckFor + dt : max(0, stuckFor - dt * 2)
        if stuckFor > COYOTE_STUCK_WAIT, castCool <= 0 {
            stuckFor = 0; cast = 0; jumped = false; wizardFade = 1
            destX = min(max(targetX - dir * 65, screen.frame.minX + 50), screen.frame.maxX - 50)
            destY = targetY
            return
        }

        if grounded {
            // With no prey it only needs a small speed advantage over mother;
            // active hunts retain their existing chase and evade speeds.
            let speed = target == nil ? COYOTE_RETREAT_SPEED : (evading ? 310 : 265)
            vx = dir * speed
            phase += Double(abs(vx)) * dt * 0.075
            x += vx * CGFloat(dt)
            if let s = support, !s.contains(x) { grounded = false; support = nil; vy = 30 }
            if dy > 60 && abs(dx) < 150 { grounded = false; support = nil; vy = 560 }
        } else {
            let previousY = y
            vy -= GRAV * CGFloat(dt) * 0.9
            x += vx * CGFloat(dt); y += vy * CGFloat(dt)
            if vy < 0 {
                var best = Ledge.highestCrossed(in: ledges, from: previousY, to: y, at: x, padding: 4)
                if best == nil, y <= screen.visibleFrame.minY {
                    best = Ledge(y: screen.visibleFrame.minY, x0: screen.frame.minX, x1: screen.frame.maxX, ground: true)
                }
                if let ledge = best { y = ledge.y; vy = 0; support = ledge; grounded = true }
            }
        }
        x = min(max(x, screen.frame.minX + 45), screen.frame.maxX - 45)
    }
}

func paintHealth(_ value: Int, max maxValue: Int, at point: CGPoint, width: CGFloat) {
    let ratio = CGFloat(Swift.max(0, Swift.min(maxValue, value))) / CGFloat(maxValue)
    NSColor(srgbRed: 0.12, green: 0.11, blue: 0.16, alpha: 0.9).setFill()
    NSRect(x: point.x - width / 2 - 2, y: point.y - 2, width: width + 4, height: 9).fill()
    (ratio > 0.5 ? NSColor.systemGreen : (ratio > 0.25 ? NSColor.systemYellow : NSColor.systemRed)).setFill()
    NSRect(x: point.x - width / 2, y: point.y, width: width * ratio, height: 5).fill()
}

func coyoteCircles(_ coyote: Coyote) -> (near: (CGFloat, CGFloat), far: (CGFloat, CGFloat)) {
    guard coyote.cast >= 0 else { return ((0, 0), (0, 0)) }
    let t = coyote.cast
    let nearGrow = CGFloat(min(1, t / COYOTE_CAST_CHARGE))
    let nearAlpha = CGFloat(t < COYOTE_CAST_JUMP ? min(1, t / 0.15) : max(0, 1 - (t - COYOTE_CAST_JUMP) / (COYOTE_CAST_TOTAL - COYOTE_CAST_JUMP)))
    let farGrow = CGFloat(max(0, min(1, (t - COYOTE_CAST_CHARGE) / (COYOTE_CAST_JUMP - COYOTE_CAST_CHARGE))))
    let farAlpha = CGFloat(t < COYOTE_CAST_CHARGE ? 0 : (t < COYOTE_CAST_JUMP ? min(1, Double(farGrow) * 1.8) : max(0, 1 - (t - COYOTE_CAST_JUMP) / (COYOTE_CAST_TOTAL - COYOTE_CAST_JUMP))))
    return ((nearGrow, nearAlpha), (farGrow, farAlpha))
}

func paintCoyote(_ coyote: Coyote, at base: CGPoint) {
    let circles = coyoteCircles(coyote)
    let circleY = base.y + (coyote.support?.ground == true ? 20 : 5)
    paintMagic(at: CGPoint(x: base.x, y: circleY), grow: circles.near.0, alpha: circles.near.1)

    var canvas = Canvas(w: 72, h: 54, oy: 12)
    canvas.stamp(Int(coyote.phase / 0.5) % 2 == 0 ? Art.coyoteA : Art.coyoteB, 0, 0)
    canvas.render(at: CGPoint(x: base.x - 36 * COYOTE_PIX, y: base.y - 2 * COYOTE_PIX),
                  scale: COYOTE_PIX, flip: coyote.dir < 0)

    // Keep the crest readable, but smaller and shifted from the torso's center
    // toward the rump. Rendering it separately allows a fractional pixel scale.
    var tag = Canvas(w: 17, h: 17)
    tag.stamp(Art.torontoTag, 0, 0)
    let tagScale = COYOTE_PIX * 0.72
    let tagCenter = CGPoint(x: base.x - coyote.dir * 12, y: base.y + 28)
    tag.render(at: CGPoint(x: tagCenter.x - 8.5 * tagScale,
                           y: tagCenter.y - 8.5 * tagScale),
               scale: tagScale, flip: coyote.dir < 0)
    if coyote.wizardFade > 0 {
        var hat = Canvas(w: 11, h: 11)
        hat.stamp(Art.wizardHat, 0, 0)
        let scale = COYOTE_PIX * 1.30
        let headCenter = base.x + coyote.dir * 33
        hat.render(at: CGPoint(x: headCenter - 5.5 * scale, y: base.y + 50),
                   scale: scale, flip: coyote.dir < 0, alpha: CGFloat(coyote.wizardFade))
    }
}

enum CoyoteSheet {
    static func render(to path: String) {
        guard let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: 300, pixelsHigh: 170,
                                         bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true,
                                         isPlanar: false, colorSpaceName: .deviceRGB,
                                         bytesPerRow: 0, bitsPerPixel: 0) else { return }
        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
        NSColor(srgbRed: 0.16, green: 0.17, blue: 0.22, alpha: 1).setFill()
        NSRect(x: 0, y: 0, width: 300, height: 170).fill()
        let animal = Coyote(x: 150, y: 30)
        animal.grounded = true; animal.wizardFade = 1
        paintCoyote(animal, at: CGPoint(x: 150, y: 30))
        paintHealth(10, max: 10, at: CGPoint(x: 150, y: 120), width: 72)
        NSGraphicsContext.restoreGraphicsState()
        if let data = rep.representation(using: .png, properties: [:]) {
            try? data.write(to: URL(fileURLWithPath: path))
        }
    }
}
