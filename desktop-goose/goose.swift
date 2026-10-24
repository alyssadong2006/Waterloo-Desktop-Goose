import Cocoa

// ───────────────────────────────── constants ──────────────────────────────

let WIN_W: CGFloat = 240, WIN_H: CGFloat = 250
// Keep the transparent panel entirely above the feet. A panel extending below
// the floor can straddle two vertically stacked monitors (often 1x and Retina),
// making AppKit repeatedly switch backing scales and flash the sprite.
let ANCHOR = CGPoint(x: 120, y: 0)       // where the goose's feet sit inside the window
let GRAV: CGFloat = 2200                 // px / s^2
let WALK_SPEED: CGFloat = 58
let RUN_SPEED: CGFloat = 175
let MAX_JUMP_VX: CGFloat = 620

let FISH_PIX: CGFloat = 1.5              // points per fish pixel
let FISHWIN_W: CGFloat = 96, FISHWIN_H: CGFloat = 80
let FISH_ANCHOR = CGPoint(x: 48, y: 13.5) // bottom of a resting fish sits at window y=0
let BITE_TIME: Double = 0.42             // how long the lunge at a fish takes

let EGG_PIX: CGFloat = 1.5
let EGGWIN: CGFloat = 52
let EGG_ANCHOR = CGPoint(x: 26, y: 9.75) // bottom of a resting egg sits at window y=0
let CHICK_PIX: CGFloat = 1.5
let CHICKWIN_W: CGFloat = 72, CHICKWIN_H: CGFloat = 72
let CHICK_ANCHOR = CGPoint(x: 36, y: 16) // normal ledge anchor; ground uses y=0 dynamically
let CHICK_SPEED: CGFloat = 56
let HATCH_TIME: Double = 0.9

// A gosling that cannot possibly reach its mother gives up and resorts to magic.
let CAST_CHARGE: Double = 0.8            // hat on, circle winds up under it
let CAST_JUMP: Double = 1.5              // by now the far circle is open; it steps through
let CAST_TOTAL: Double = 2.2             // circles fade out
let HAT_FADE: Double = 3.5               // and the hat slowly goes with them
let CAST_COOL: Double = 6.0
let SPELLWIN: CGFloat = 96
let SPELL_ANCHOR = CGPoint(x: 48, y: 48)
let ANGER_FUSE: Double = 11              // seconds of fruitless chasing to boil over
let ANGER_MISS: Double = 0.2             // ...plus this much every time it snaps at nothing
let ANGER_WHIFF: Double = 0.07           // ...and this much every time it lands empty-beaked

// ───────────────────────────────── ledges ─────────────────────────────────

struct Ledge {
    var y: CGFloat
    var x0: CGFloat
    var x1: CGFloat
    var ground: Bool
    func contains(_ x: CGFloat, pad: CGFloat = 0) -> Bool { x >= x0 - pad && x <= x1 + pad }
    var width: CGFloat { x1 - x0 }

    /// Returns the highest ledge crossed while an actor is moving downward.
    /// Actors pass either their feet or their sprite's bottom edge, depending on
    /// which point they use for collision detection.
    static func highestCrossed(
        in ledges: [Ledge],
        from previousY: CGFloat,
        to currentY: CGFloat,
        at x: CGFloat,
        padding: CGFloat
    ) -> Ledge? {
        var best: Ledge?
        for ledge in ledges
        where ledge.y <= previousY + 1
            && ledge.y >= currentY - 1
            && ledge.contains(x, pad: padding) {
            if best == nil || ledge.y > best!.y { best = ledge }
        }
        return best
    }

    /// Finds the current version of a support after the window list is refreshed.
    static func refreshedSupport(
        matching support: Ledge,
        at x: CGFloat,
        in ledges: [Ledge],
        padding: CGFloat = 2
    ) -> Ledge? {
        ledges.first { abs($0.y - support.y) < 2.5 && $0.contains(x, pad: padding) }
    }
}

/// The visible top edge of every on-screen window — the shelves the goose perches
/// on (title bars / tab strips) — plus the floor of the display it lives on.
enum LedgeFinder {
    static func flipBase() -> CGFloat { NSScreen.screens.first?.frame.maxY ?? 0 }

    static func current(on screen: NSScreen) -> [Ledge] {
        let sf = screen.frame
        var out: [Ledge] = [Ledge(y: screen.visibleFrame.minY, x0: sf.minX, x1: sf.maxX, ground: true)]

        let opts: CGWindowListOption = [.optionOnScreenOnly, .excludeDesktopElements]
        guard let infos = CGWindowListCopyWindowInfo(opts, kCGNullWindowID) as? [[String: Any]] else { return out }
        let me = ProcessInfo.processInfo.processIdentifier

        // Front-to-back, so we can subtract the parts of a lower window's top
        // edge that are hidden behind the windows in front of it.
        var occluders: [CGRect] = []
        let base = flipBase()

        for info in infos {
            guard let bd = info[kCGWindowBounds as String] as? [String: CGFloat],
                  let layer = info[kCGWindowLayer as String] as? Int else { continue }
            let r = CGRect(x: bd["X"] ?? 0, y: bd["Y"] ?? 0, width: bd["Width"] ?? 0, height: bd["Height"] ?? 0)
            let alpha = (info[kCGWindowAlpha as String] as? CGFloat) ?? 1
            let pid = (info[kCGWindowOwnerPID as String] as? Int32) ?? 0

            if pid == me || layer != 0 || alpha < 0.2 { continue }
            if r.width < 140 || r.height < 60 { continue }

            var spans: [(CGFloat, CGFloat)] = [(r.minX, r.maxX)]
            let topY = r.minY                                   // CG coords: top edge
            for o in occluders where o.minY <= topY + 2 && o.maxY >= topY - 2 {
                var next: [(CGFloat, CGFloat)] = []
                for (a, b) in spans {
                    if o.maxX <= a || o.minX >= b { next.append((a, b)); continue }
                    if o.minX > a { next.append((a, o.minX)) }
                    if o.maxX < b { next.append((o.maxX, b)) }
                }
                spans = next
            }
            occluders.append(r)

            let ay = base - topY                                // AppKit y of the top edge
            if ay < sf.minY + 6 || ay > sf.maxY - 4 { continue }   // other display
            for (a0, b0) in spans {
                let a = max(a0, sf.minX), b = min(b0, sf.maxX)
                if b - a >= 90 { out.append(Ledge(y: ay, x0: a, x1: b, ground: false)) }
            }
            if occluders.count > 40 { break }
        }
        return out
    }
}

// ───────────────────────────────── the bird ───────────────────────────────

enum Act { case idle, walk, run, peck, honk, air, fly, sit, held, eat }
enum GrabPart { case whole, head, body }

final class Goose {
    var x: CGFloat = 300, y: CGFloat = 400
    var vx: CGFloat = 0, vy: CGFloat = 0
    var dir: CGFloat = 1
    var act: Act = .air
    var actLeft: Double = 0
    var phase: Double = 0
    var clock: Double = 0
    var support: Ledge?
    var targetX: CGFloat?
    var headDip: CGFloat = 0
    var beakOpen: CGFloat = 0
    var flap: CGFloat = 0
    var blinkLeft: Double = 0
    var bubbleLeft: Double = 0
    var bubbleText = "HONK!"
    var ledges: [Ledge] = []
    var followCursor = false
    var soundOn = true
    var screen: NSScreen = NSScreen.screens.first!
    var groundedTime: Double = 0
    var hearts: [(x: CGFloat, y: CGFloat, life: Double)] = []

    // Optional rubber-neck physics. Coordinates are screen-point offsets from the
    // ordinary pose; the part under the cursor stays fixed while the other trails.
    var stretchy = false
    var grabPart: GrabPart = .whole
    var headStretch = CGPoint.zero, bodyStretch = CGPoint.zero
    private var headStretchV = CGPoint.zero, bodyStretchV = CGPoint.zero

    // the fish it is currently after
    var fish: Fish?
    var biteLeft: Double = 0            // > 0 while its head is coming down on the fish
    var lungeCool: Double = 0           // stops it jumping at the fish every single frame
    var anger: Double = 0               // 0...1, builds while a fish keeps getting away
    var angryHonkLeft: Double = 0
    var fed = 0
    var onAte: (() -> Void)?

    // Protects goslings whenever the optional coyote is present.
    var coyote: Coyote?
    var coyoteAttackCool: Double = 0

    // flight
    private var flyFrom = CGPoint.zero, flyTo = CGPoint.zero, flyCtrl = CGPoint.zero
    private var flyT: Double = 0, flyDur: Double = 1
    private var flyTarget: Ledge?

    private var ledgeAge: Double = 99

    var walking: Bool { act == .walk || act == .run }
    var bounds: CGRect { screen.frame }

    /// Past this it has had enough: brows down, vein popping, and it stops being polite.
    var isAngry: Bool { anger > 0.55 || coyote != nil }

    /// Roughly where the beak is on screen — what has to touch the fish.
    var mouth: CGPoint {
        CGPoint(x: x + dir * (21 + headDip * 9), y: y + 62 - headDip * 36)
    }

    // MARK: main tick
    func step(_ dt: Double) {
        clock += dt
        stepStretch(dt)
        ledgeAge += dt
        lungeCool = max(0, lungeCool - dt)
        coyoteAttackCool = max(0, coyoteAttackCool - dt)
        if fish == nil { anger = max(0, anger - dt * 0.28) }      // sulks it off
        if isAngry {
            angryHonkLeft -= dt
            if angryHonkLeft <= 0 {
                angryHonkLeft = Double.random(in: 0.9...1.8)
                honk(["HONK!!!", "HONK!!", "!!!", "GRR!"].randomElement()!,
                     silent: Double.random(in: 0...1) > 0.35)
            }
        }
        if ledgeAge > 0.9 { ledges = LedgeFinder.current(on: screen); ledgeAge = 0; revalidateSupport() }

        blinkLeft -= dt
        if blinkLeft < -2.5 && Double.random(in: 0...1) < 0.02 { blinkLeft = 0.13 }
        bubbleLeft -= dt
        for i in hearts.indices { hearts[i].y += CGFloat(dt) * 40; hearts[i].x += CGFloat(sin(clock * 6 + Double(i))) * 0.4; hearts[i].life -= dt }
        hearts.removeAll { $0.life <= 0 }
        if act != .fly && act != .held { flap = max(0, flap - CGFloat(dt) * 3) }

        switch act {
        case .held: return                       // the human is in charge
        case .air:  stepAir(dt)
        case .fly:  stepFly(dt)
        default:    stepGrounded(dt)
        }

        let b = bounds
        if x < b.minX + 12 { x = b.minX + 12; if act != .fly { dir = 1 } }
        if x > b.maxX - 12 { x = b.maxX - 12; if act != .fly { dir = -1 } }
        if y < b.minY - 240 { y = b.maxY - 120; act = .air; vy = 0; vx = 0 }   // safety net
    }

    /// Gives the loose end of the goose some inertia when its other end is moved.
    func tugStretch(by delta: CGPoint) {
        guard stretchy, act == .held else { return }
        // More than 1:1 counter-motion makes the loose end visibly sling in the
        // opposite screen direction instead of merely lagging behind the cursor.
        let tug = CGPoint(x: -delta.x * 1.35, y: -delta.y * 1.35)
        if grabPart == .head {
            bodyStretch = limited(CGPoint(x: bodyStretch.x + tug.x, y: bodyStretch.y + tug.y), to: 26)
        }
        if grabPart == .body {
            headStretch = limited(CGPoint(x: headStretch.x + tug.x, y: headStretch.y + tug.y), to: 26)
        }
    }

    func resetStretch() {
        headStretch = .zero; bodyStretch = .zero
        headStretchV = .zero; bodyStretchV = .zero
        grabPart = .whole
    }

    private func limited(_ p: CGPoint, to radius: CGFloat) -> CGPoint {
        let d = hypot(p.x, p.y)
        return d > radius ? CGPoint(x: p.x * radius / d, y: p.y * radius / d) : p
    }

    private func stepStretch(_ dt: Double) {
        guard stretchy else { resetStretch(); return }
        let t = CGFloat(min(dt, 0.04)), spring: CGFloat = 52, damping: CGFloat = 9.5
        func advance(_ p: inout CGPoint, _ v: inout CGPoint) {
            v.x += (-spring * p.x - damping * v.x) * t
            v.y += (-spring * p.y - damping * v.y) * t
            p.x += v.x * t; p.y += v.y * t
            if hypot(p.x, p.y) < 0.08 && hypot(v.x, v.y) < 0.3 { p = .zero; v = .zero }
        }
        if act == .held && grabPart == .head { headStretch = .zero; headStretchV = .zero }
        else { advance(&headStretch, &headStretchV) }
        if act == .held && grabPart == .body { bodyStretch = .zero; bodyStretchV = .zero }
        else { advance(&bodyStretch, &bodyStretchV) }
    }

    private func stepAir(_ dt: Double) {
        biteLeft = 0
        let prevY = y
        vy -= GRAV * CGFloat(dt)
        x += vx * CGFloat(dt)
        y += vy * CGFloat(dt)
        flap = min(1, flap + CGFloat(dt) * 6)

        // Bounce off the sides *before* looking for a landing. A hard throw can put x
        // outside every ledge on the very frame it crosses one, and then it is below
        // the floor forever — the crossing test only fires on the way down past a ledge.
        let b = bounds
        if x < b.minX + 12 { x = b.minX + 12; if vx < 0 { vx = -vx * 0.45 } }
        if x > b.maxX - 12 { x = b.maxX - 12; if vx > 0 { vx = -vx * 0.45 } }
        if abs(vx) > 5 { dir = vx > 0 ? 1 : -1 }
        snatchFish()

        guard vy < 0 else { return }
        var best = Ledge.highestCrossed(in: ledges, from: prevY, to: y, at: x, padding: 3)
        // hard floor: whatever else happens, it never goes below the bottom of its screen
        if best == nil, y <= screen.visibleFrame.minY {
            best = Ledge(y: screen.visibleFrame.minY, x0: b.minX, x1: b.maxX, ground: true)
        }
        if let l = best { land(on: l) }
    }

    private func stepFly(_ dt: Double) {
        biteLeft = 0
        let prev = CGPoint(x: x, y: y)
        flyT += dt / flyDur
        let t = CGFloat(min(1, flyT)), u = 1 - t
        x = u * u * flyFrom.x + 2 * u * t * flyCtrl.x + t * t * flyTo.x
        y = u * u * flyFrom.y + 2 * u * t * flyCtrl.y + t * t * flyTo.y
        vx = (x - prev.x) / CGFloat(max(dt, 0.001))
        vy = (y - prev.y) / CGFloat(max(dt, 0.001))
        if abs(vx) > 12 { dir = vx > 0 ? 1 : -1 }
        snatchFish()
        if flyT >= 1 {
            if let l = flyTarget { land(on: l) }
            else { act = .air; vy = min(vy, 0) }      // chased a fish into thin air; drop
        }
    }

    private func land(on l: Ledge) {
        y = l.y; vy = 0; vx = 0
        support = l
        act = .idle
        actLeft = Double.random(in: 0.25...0.8)
        flap = 1
        groundedTime = 0
        if let f = fish, !f.gone { anger = min(1, anger + ANGER_WHIFF) }   // empty-beaked again
    }

    private func stepGrounded(_ dt: Double) {
        groundedTime += dt
        phase += Double(abs(vx)) * dt * 0.09

        switch act {
        case .peck:
            let p = 1 - actLeft / 1.1
            headDip = CGFloat(max(0, sin(p * .pi * 3)))
        case .honk:
            beakOpen = CGFloat(max(0, sin((1 - actLeft / 0.7) * .pi)))
            headDip = -0.18
        default:
            headDip *= 0.85
            beakOpen *= 0.8
        }

        if coyoteDrive(dt) { return }
        if fishDrive(dt) { return }

        // notices the cursor when it comes close
        let m = NSEvent.mouseLocation
        if !walking && abs(m.x - x) < 170 && abs(m.y - y) < 150 && abs(m.x - x) > 12 {
            dir = m.x > x ? 1 : -1
        }

        if walking {
            if followCursor { targetX = NSEvent.mouseLocation.x }
            if let t = targetX {
                dir = t > x ? 1 : -1
                if abs(t - x) < 8 {
                    vx = 0; act = .idle; actLeft = Double.random(in: 0.4...1.2)
                    if !followCursor { targetX = nil }
                }
            }
            if walking {
                vx = dir * (act == .run ? RUN_SPEED : WALK_SPEED)
                x += vx * CGFloat(dt)
            }

            if let s = support, !s.contains(x) {
                // reached the edge: turn back, or step off and fall
                if Double.random(in: 0...1) < 0.45 {
                    support = nil; act = .air; vy = 40; vx = dir * 60; targetX = nil
                } else {
                    x = min(max(x, s.x0 + 4), s.x1 - 4)
                    dir *= -1; targetX = nil
                }
            }
        } else {
            vx = 0
        }

        actLeft -= dt
        if actLeft <= 0 { chooseAction() }
    }

    private func revalidateSupport() {
        guard act != .air, act != .fly, act != .held, let s = support else { return }
        if let m = Ledge.refreshedSupport(matching: s, at: x, in: ledges) {
            support = m; y = m.y
        } else {
            support = nil; act = .air; vy = 0; vx = 0
        }
    }

    // MARK: protecting goslings
    private func coyoteDrive(_ dt: Double) -> Bool {
        guard let c = coyote, c.health > 0 else { return false }
        if c.held { vx = 0; act = .idle; actLeft = 0.2; return true }
        let dx = c.x - x, dy = c.y - y
        if abs(dx) > 5 { dir = dx > 0 ? 1 : -1 }
        if !c.casting, abs(dx) < 58, abs(dy) < 65, coyoteAttackCool <= 0, c.hurtCool <= 0 {
            c.health -= 1
            c.hurtCool = 0.7
            coyoteAttackCool = 0.75
            c.vx = dir * 180; c.vy = 250; c.grounded = false; c.support = nil
            honk("HONK!!!")
            return true
        }
        if dy > 185, lungeCool <= 0,
           glide(to: CGPoint(x: c.x, y: c.y), landingOn: c.support) { return true }
        if dy > 35, abs(dx) < 330, lungeCool <= 0,
           lunge(at: CGPoint(x: c.x, y: c.y)) { return true }
        if dy < -35, !(support?.ground ?? true), lungeCool <= 0,
           glide(to: CGPoint(x: c.x, y: c.y), landingOn: c.support) { return true }
        act = .run
        vx = dir * RUN_SPEED * 1.15
        x += vx * CGFloat(dt)
        if let s = support, !s.contains(x) {
            support = nil; act = .air; vy = 40; vx = dir * 100
        }
        return true
    }

    // MARK: the fish
    /// Close enough to get its beak on it from where it stands.
    private func canReach(_ f: Fish) -> Bool {
        abs(f.x - x) < 34 && f.y - y > -26 && f.y - y < 78
    }

    /// Everything the goose does about a fish while it is on its feet.
    /// Returns true when the fish is what it is doing this frame.
    private func fishDrive(_ dt: Double) -> Bool {
        guard let f = fish, !f.gone else { biteLeft = 0; return false }

        // mid-lunge: head comes down, beak opens, then the fish is gone
        if biteLeft > 0 {
            biteLeft -= dt
            let p = 1 - biteLeft / BITE_TIME
            act = .eat
            vx = 0
            headDip = CGFloat(max(0, sin(p * .pi)))
            beakOpen = CGFloat(max(0, sin(p * .pi * 2)))
            if biteLeft <= 0 {
                if canReach(f) { eat(f) }
                else {                                         // you moved it — infuriating
                    act = .idle; actLeft = 0.35
                    anger = min(1, anger + ANGER_MISS)
                }
            }
            return true
        }

        let dx = f.x - x, dy = f.y - y
        // anything on its own screen is fair game, however far up you hold it
        if !screen.frame.insetBy(dx: -60, dy: -60).contains(CGPoint(x: f.x, y: f.y)) {
            anger = max(0, anger - dt * 0.28)
            return false
        }
        if abs(dx) > 6 { dir = dx > 0 ? 1 : -1 }

        // the longer this goes on, the less charming it finds it
        anger = min(1, anger + dt / ANGER_FUSE)

        if canReach(f) {
            if Double.random(in: 0...1) < 0.2 { honk("HONK!") }
            biteLeft = BITE_TIME
            act = .eat
            vx = 0
            targetX = nil
            return true
        }

        // dangled well overhead — take off after it
        if dy > 190, lungeCool <= 0, glide(to: CGPoint(x: f.x, y: f.y)) { return true }
        // just out of reach — hop for it
        if dy > 34, abs(dx) < 340, lungeCool <= 0, lunge(at: CGPoint(x: f.x, y: f.y)) { return true }

        // perched on a tab bar with the fish below: fly down to it rather than
        // stand on the ledge looking at it
        if dy < -26, !(support?.ground ?? true) {
            if lungeCool <= 0, glide(to: CGPoint(x: f.x, y: f.y), landingOn: f.support) { return true }
            if abs(dx) < 14 {                          // right overhead — just step off
                support = nil; act = .air; vy = 0; vx = dir * 40; targetX = nil
                return true
            }
        }

        if dy > 0, abs(dx) < 14 {
            act = .idle                // standing right under it, waiting for its moment
            actLeft = 0.2
            vx = 0
            return true
        }

        act = .run
        actLeft = 0.5
        targetX = nil
        vx = dir * RUN_SPEED * (1 + 0.5 * CGFloat(anger))
        x += vx * CGFloat(dt)
        if let s = support, !s.contains(x) {
            if dy < -20 {              // fish is below: walk right off the edge after it
                support = nil; act = .air; vy = 40; vx = dir * 90
            } else {
                x = min(max(x, s.x0 + 4), s.x1 - 4)
                vx = 0
            }
        }
        return true
    }

    /// Takes the fish out of the air mid-jump.
    private func snatchFish() {
        guard let f = fish, !f.gone else { return }
        if hypot(f.x - mouth.x, f.y - mouth.y) < 40 { eat(f) }
    }

    /// A hop aimed so the *beak*, not the feet, arrives at `p`.
    @discardableResult
    private func lunge(at p: CGPoint) -> Bool {
        guard support != nil else { return false }
        let dx = p.x - x
        let dy = p.y - y - 56
        let apex = max(dy, 0) + CGFloat.random(in: 45...80)
        let vy0 = (2 * GRAV * apex).squareRoot()
        let disc = vy0 * vy0 - 2 * GRAV * dy
        guard disc > 0 else { return false }
        let t = CGFloat(vy0 + disc.squareRoot()) / GRAV
        let need = dx / t
        guard abs(need) <= MAX_JUMP_VX else { return false }
        vx = need; vy = vy0
        if abs(dx) > 4 { dir = dx > 0 ? 1 : -1 }
        support = nil; act = .air; targetX = nil; flap = 1; biteLeft = 0
        lungeCool = 0.85 - 0.45 * anger
        return true
    }

    /// Flies at a fish it cannot walk or hop to — up at one held overhead, or down
    /// off a tab bar to one on the floor. With no ledge to land on it ends in the
    /// air and falls the rest of the way.
    @discardableResult
    private func glide(to p: CGPoint, landingOn ledge: Ledge? = nil) -> Bool {
        flyFrom = CGPoint(x: x, y: y)
        flyTo = CGPoint(x: p.x, y: max(p.y - 52, screen.visibleFrame.minY))
        var target: Ledge?
        if let l = ledge, l.x1 - l.x0 > 30 {
            flyTo = CGPoint(x: min(max(p.x, l.x0 + 14), l.x1 - 14), y: l.y)
            target = l
        }
        let d = hypot(flyTo.x - flyFrom.x, flyTo.y - flyFrom.y)
        guard d > 30 else { return false }
        flyCtrl = flyTo.y > flyFrom.y
            ? CGPoint(x: (flyFrom.x + flyTo.x) / 2,                      // climbing: arc over the top
                      y: max(flyFrom.y, flyTo.y) + min(200, d * 0.35) + 30)
            : CGPoint(x: flyFrom.x + (flyTo.x - flyFrom.x) * 0.62,       // dropping: swoop off the ledge
                      y: flyFrom.y + min(30, d * 0.06))
        flyDur = Double(min(2.0, max(0.55, d / 620)))
        flyT = 0
        flyTarget = target
        act = .fly
        targetX = nil
        support = nil
        biteLeft = 0
        flap = 1
        lungeCool = 1.2 - 0.5 * anger
        if soundOn && Double.random(in: 0...1) < 0.4 { NSSound(named: "Frog")?.play() }
        return true
    }

    private func eat(_ f: Fish) {
        f.gone = true
        fish = nil
        biteLeft = 0
        headDip = 0
        fed += 1
        anger = 0                                              // all is forgiven
        if act == .eat || act == .peck { act = .idle; actLeft = 0.8 }
        for i in 0..<4 {
            hearts.append((x: CGFloat.random(in: -20...20),
                           y: CGFloat.random(in: 56...76) + CGFloat(i) * 5,
                           life: Double.random(in: 0.9...1.5)))
        }
        honk(["YUM!", "MMM!", "HONK!"].randomElement()!)
        onAte?()
    }

    // MARK: brain
    private func chooseAction() {
        // stuck on the floor for a while? go find a window to sit on
        if groundedTime > 14, (support?.ground ?? true), flyOff(preferWindows: true) { return }

        switch Double.random(in: 0...1) {
        case ..<0.18:
            act = .idle; actLeft = Double.random(in: 0.6...2.2)
            if Double.random(in: 0...1) < 0.35 { dir *= -1 }
        case ..<0.27:
            act = .sit; actLeft = Double.random(in: 1.5...4.0)
        case ..<0.39:
            act = .peck; actLeft = 1.1
        case ..<0.46:
            honk()
        case ..<0.56:
            if jumpSomewhere() { return }
            wander(run: false)
        case ..<0.66:
            if flyOff(preferWindows: true) { return }
            wander(run: false)
        case ..<0.85:
            wander(run: false)
        default:
            wander(run: Double.random(in: 0...1) < 0.4)
        }
    }

    private func wander(run: Bool) {
        act = run ? .run : .walk
        actLeft = Double.random(in: 1.2...3.5)
        if let s = support, s.width > 60 {
            targetX = CGFloat.random(in: (s.x0 + 10)...(s.x1 - 10))
            dir = targetX! > x ? 1 : -1
        } else if Double.random(in: 0...1) < 0.3 {
            dir *= -1
        }
    }

    func honk(_ text: String? = nil, silent: Bool = false) {
        if act != .held && act != .fly && act != .air { act = .honk; actLeft = 0.7 }
        beakOpen = 1
        bubbleText = text ?? ["HONK!", "HONK", "HONK?", "HONK HONK!"].randomElement()!
        bubbleLeft = 1.2
        flap = 1
        if soundOn && !silent { NSSound(named: "Frog")?.play() }
    }

    /// Short ballistic hop to a nearby ledge.
    @discardableResult
    func jumpSomewhere() -> Bool {
        guard let s = support else { return false }
        var cands: [(Ledge, CGFloat)] = []
        for l in ledges {
            if l.y == s.y && l.x0 == s.x0 { continue }
            let dy = l.y - y
            if dy > 320 || dy < -420 { continue }
            let lo = l.x0 + 14, hi = l.x1 - 14
            if hi <= lo { continue }
            let lx = min(max(x, lo), hi)
            let dx = lx - x
            if abs(dx) > 300 { continue }
            if abs(dx) < 25 && abs(dy) < 25 { continue }
            cands.append((l, lx))
        }
        guard !cands.isEmpty else { return false }
        cands.shuffle()
        for (l, lx) in cands.prefix(6) {
            let dy = l.y - y, dx = lx - x
            let apex = max(dy, 0) + CGFloat.random(in: 60...110)
            let vy0 = (2 * GRAV * apex).squareRoot()
            let disc = vy0 * vy0 - 2 * GRAV * dy
            guard disc > 0 else { continue }
            let t = CGFloat(vy0 + disc.squareRoot()) / GRAV
            let need = dx / t
            if abs(need) > MAX_JUMP_VX { continue }
            vx = need; vy = vy0
            if dx != 0 { dir = dx > 0 ? 1 : -1 }
            support = nil; act = .air; targetX = nil; flap = 1
            return true
        }
        return false
    }

    /// Takes off and flies to a far ledge — this is how it gets up to tab bars.
    @discardableResult
    func flyOff(preferWindows: Bool) -> Bool {
        var pool = ledges.filter { l in
            l.width > 110 && !(l.y == support?.y && l.x0 == support?.x0) && abs(l.y - y) + abs(l.x0 - x) > 80
        }
        if preferWindows {
            let tabs = pool.filter { !$0.ground && $0.y > y + 40 }
            if !tabs.isEmpty && Double.random(in: 0...1) < 0.85 { pool = tabs }
        }
        guard let l = pool.randomElement() else { return false }
        let lo = l.x0 + 20, hi = l.x1 - 20
        guard hi > lo else { return false }
        flyTo = CGPoint(x: CGFloat.random(in: lo...hi), y: l.y)
        flyFrom = CGPoint(x: x, y: y)
        let d = hypot(flyTo.x - flyFrom.x, flyTo.y - flyFrom.y)
        flyCtrl = CGPoint(x: (flyFrom.x + flyTo.x) / 2,
                          y: max(flyFrom.y, flyTo.y) + min(260, d * 0.45) + 40)
        flyDur = Double(min(2.4, max(0.75, d / 520)))
        flyT = 0
        flyTarget = l
        act = .fly
        targetX = nil
        support = nil
        if soundOn && Double.random(in: 0...1) < 0.5 { NSSound(named: "Frog")?.play() }
        return true
    }

    func goTo(_ px: CGFloat) { targetX = px; act = .run; actLeft = 12; dir = px > x ? 1 : -1 }

    // MARK: being handled
    func grab(part: GrabPart = .whole) {
        grabPart = stretchy ? part : .whole
        act = .held
        support = nil
        targetX = nil
        biteLeft = 0
        flap = 1
        honk(["HONK!", "HEY!", "HONK?", "HONKK"].randomElement()!)
    }

    func release(vx: CGFloat, vy: CGFloat) {
        grabPart = .whole
        self.vx = max(-1400, min(1400, vx))
        self.vy = max(-1400, min(1400, vy))
        act = .air
    }

    func pet() {
        act = .idle
        actLeft = 1.0
        headDip = 0
        blinkLeft = 0.6
        for i in 0..<3 {
            hearts.append((x: CGFloat.random(in: -18...18),
                           y: CGFloat.random(in: 58...74) + CGFloat(i) * 6,
                           life: Double.random(in: 0.9...1.4)))
        }
        honk("♥")
    }

    func move(to screen: NSScreen) {
        self.screen = screen
        ledges = LedgeFinder.current(on: screen)
        x = screen.frame.midX
        y = screen.frame.maxY - 140
        vx = 0; vy = 0
        support = nil
        act = .air
    }
}

// ───────────────────────────────── the fish ───────────────────────────────

/// A snack you drag around with the mouse. Falls and settles on the same ledges
/// the goose perches on, so you can park it on a title bar and make it climb.
final class Fish {
    var x: CGFloat
    var y: CGFloat                       // centre of the sprite
    var vx: CGFloat = 0, vy: CGFloat = 0
    var dir: CGFloat = 1
    var held = false
    var gone = false
    var resting = false
    var support: Ledge?
    var clock: Double = 0

    static let halfW = CGFloat(28) * FISH_PIX / 2
    static let halfH = CGFloat(18) * FISH_PIX / 2

    init(x: CGFloat, y: CGFloat) { self.x = x; self.y = y }

    func step(_ dt: Double, ledges: [Ledge], screen: NSScreen) {
        clock += dt
        guard !held, !gone else { return }
        let sf = screen.frame
        let floor = screen.visibleFrame.minY

        if resting {
            vx *= CGFloat(pow(0.015, dt))                  // slides to a stop
            if abs(vx) < 4 { vx = 0 }
            x += vx * CGFloat(dt)
            if let s = support, s.contains(x, pad: 1),
               s.ground || ledges.contains(where: { abs($0.y - s.y) < 2.5 && $0.contains(x, pad: 1) }) {
                return
            }
            resting = false; support = nil; vy = 0         // the window under it went away
        }

        let prevBottom = y - Fish.halfH
        vy -= GRAV * CGFloat(dt) * 0.85                    // a touch floatier than the bird
        x += vx * CGFloat(dt)
        y += vy * CGFloat(dt)

        if x < sf.minX + Fish.halfW { x = sf.minX + Fish.halfW; vx = -vx * 0.4 }
        if x > sf.maxX - Fish.halfW { x = sf.maxX - Fish.halfW; vx = -vx * 0.4 }
        if y > sf.maxY - Fish.halfH { y = sf.maxY - Fish.halfH; vy = min(vy, 0) }
        if abs(vx) > 6 { dir = vx > 0 ? 1 : -1 }

        guard vy < 0 else { return }
        let bottom = y - Fish.halfH
        var best = Ledge.highestCrossed(in: ledges, from: prevBottom, to: bottom, at: x, padding: 2)
        if best == nil, bottom <= floor {
            best = Ledge(y: floor, x0: sf.minX, x1: sf.maxX, ground: true)
        }
        guard let l = best else { return }
        y = l.y + Fish.halfH
        if vy < -420 {                                     // one bounce, then it settles
            vy = -vy * 0.32
            vx *= 0.7
        } else {
            vy = 0
            vx *= 0.45
            support = l
            resting = true
        }
    }
}

// ───────────────────────────────── eggs and goslings ─────────────────────

/// An egg. Falls and settles like the fish; click it and it hatches.
final class Egg {
    var x: CGFloat
    var y: CGFloat                       // centre
    var vx: CGFloat = 0, vy: CGFloat = 0
    var resting = false
    var support: Ledge?
    var clock: Double = 0
    var cracking = false
    var hatchLeft: Double = 0
    var gone = false

    static let halfW = CGFloat(10) * EGG_PIX / 2
    static let halfH = CGFloat(13) * EGG_PIX / 2

    init(x: CGFloat, y: CGFloat) { self.x = x; self.y = y }

    func step(_ dt: Double, ledges: [Ledge], screen: NSScreen) {
        clock += dt
        if cracking { hatchLeft -= dt }
        guard !gone else { return }
        let sf = screen.frame
        let floor = screen.visibleFrame.minY

        if resting {
            vx *= CGFloat(pow(0.01, dt))
            if abs(vx) < 3 { vx = 0 }
            x += vx * CGFloat(dt)
            if let s = support, s.contains(x, pad: 1),
               s.ground || ledges.contains(where: { abs($0.y - s.y) < 2.5 && $0.contains(x, pad: 1) }) {
                return
            }
            resting = false; support = nil; vy = 0
        }

        let prevBottom = y - Egg.halfH
        vy -= GRAV * CGFloat(dt) * 0.9
        x += vx * CGFloat(dt)
        y += vy * CGFloat(dt)
        if x < sf.minX + Egg.halfW { x = sf.minX + Egg.halfW; vx = -vx * 0.3 }
        if x > sf.maxX - Egg.halfW { x = sf.maxX - Egg.halfW; vx = -vx * 0.3 }

        guard vy < 0 else { return }
        let bottom = y - Egg.halfH
        var best = Ledge.highestCrossed(in: ledges, from: prevBottom, to: bottom, at: x, padding: 2)
        if best == nil, bottom <= floor {
            best = Ledge(y: floor, x0: sf.minX, x1: sf.maxX, ground: true)
        }
        guard let l = best else { return }
        y = l.y + Egg.halfH
        vy = 0; vx *= 0.3
        support = l; resting = true
    }
}

/// A gosling. Trots after the goose, falls off ledges after it, and scrambles
/// upward when the goose is somewhere it cannot reach.
final class Chick {
    let id: Int
    var health = 3
    var x: CGFloat, y: CGFloat           // feet
    var vx: CGFloat = 0, vy: CGFloat = 0
    var dir: CGFloat = 1
    var phase: Double = 0
    var clock: Double = 0
    var grounded = false
    var support: Ledge?
    var hopCool: Double = 0
    var lostFor: Double = 0
    var held = false
    // wizardry
    var stuckFor: Double = 0
    var cast: Double = -1                // seconds into the spell, -1 when not casting
    var jumped = false
    var destX: CGFloat = 0, destY: CGFloat = 0
    var wizardFade: Double = 0           // 1 while casting, then fades the hat out
    var castCool: Double = 0
    var casting: Bool { cast >= 0 }

    init(id: Int, x: CGFloat, y: CGFloat) { self.id = id; self.x = x; self.y = y }

    func step(_ dt: Double, ledges: [Ledge], screen: NSScreen, follow: CGPoint, threat: CGPoint? = nil) {
        clock += dt
        hopCool = max(0, hopCool - dt)
        castCool = max(0, castCool - dt)

        // mid-spell: it hangs in place, steps through at CAST_JUMP, then resumes
        if cast >= 0 {
            cast += dt
            if !jumped && cast >= CAST_JUMP {
                jumped = true
                x = destX; y = destY
                vx = 0; vy = 0
                grounded = false
                support = nil
            }
            if cast >= CAST_TOTAL { cast = -1; jumped = false; castCool = CAST_COOL }
            return
        }
        if wizardFade > 0 { wizardFade = max(0, wizardFade - dt / HAT_FADE) }

        guard !held else { stuckFor = 0; return }    // the human has it
        let sf = screen.frame
        let floor = screen.visibleFrame.minY

        // A nearby coyote takes priority over following mother: run directly
        // away from it. Once clear, return to the normal follow-the-leader line.
        var goal = follow
        if let threat, hypot(threat.x - x, threat.y - y) < 330 {
            let away: CGFloat = x >= threat.x ? 1 : -1
            goal = CGPoint(x: min(max(x + away * 450, screen.frame.minX + 20), screen.frame.maxX - 20), y: y)
        }
        // a toddle close up, a scurry when it has fallen behind.
        let dx = goal.x - x, gap = abs(dx)
        let speed: CGFloat = gap > 240 ? CHICK_SPEED * 2.4 : (gap > 90 ? CHICK_SPEED * 1.6 : CHICK_SPEED)
        if gap > 18 {
            dir = dx > 0 ? 1 : -1
            vx = dir * speed
            phase += Double(speed) * dt * 0.08
        } else {
            vx = 0
            if gap > 5 { dir = dx > 0 ? 1 : -1 }
        }

        // Somewhere it cannot walk to. Three ways that happens:
        //  - mother is up a tab bar, higher than it can hop
        //  - mother is well below but still under the ledge it is standing on, so
        //    walking toward her never takes it off the edge and it waits forever
        //    (if she is past the end of the ledge it just toddles off and drops,
        //    which is nicer than a spell, so that case is deliberately excluded)
        //  - mother is most of a screen away
        // Give it a few seconds of trying, then it resorts to wizardry.
        let strandedOver = y - goal.y > 120 && grounded && (support?.contains(goal.x, pad: 6) ?? false)
        let unreachable = (goal.y - y > 70) || strandedOver || gap > 650
        stuckFor = unreachable ? stuckFor + dt : max(0, stuckFor - dt * 2)
        if stuckFor > 3.5, castCool <= 0 {
            stuckFor = 0
            cast = 0
            jumped = false
            wizardFade = 1
            destX = goal.x
            destY = goal.y
        }

        let prevY = y
        vy -= GRAV * CGFloat(dt) * 0.9
        x += vx * CGFloat(dt)
        y += vy * CGFloat(dt)
        if x < sf.minX + 12 { x = sf.minX + 12 }
        if x > sf.maxX - 12 { x = sf.maxX - 12 }

        grounded = false
        if vy <= 0 {
            var best = Ledge.highestCrossed(in: ledges, from: prevY, to: y, at: x, padding: 3)
            if best == nil, y <= floor {
                best = Ledge(y: floor, x0: sf.minX, x1: sf.maxX, ground: true)
            }
            if let l = best { y = l.y; vy = 0; support = l; grounded = true }
        }

        // the goose has gone up somewhere: scramble after it
        if grounded, goal.y - y > 40, abs(dx) < 110, hopCool <= 0 {
            vy = 580; grounded = false; support = nil; hopCool = 0.7
        }
        if y < sf.minY - 200 { x = follow.x; y = follow.y + 60; vy = 0 }     // safety net
    }
}
