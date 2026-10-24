import Cocoa
import Carbon.HIToolbox

// ───────────────────────────────── app ────────────────────────────────────

/// AppKit refuses to let an ordinary window's frame cross the top of the visible
/// screen. That pins the goose in mid-air whenever it is perched high on a tab bar
/// — it hops, but the window cannot follow it up, so it just tucks its legs and
/// stays put. These windows are decoration; they go exactly where they are told.
final class FreePanel: NSPanel {
    override func constrainFrameRect(_ frameRect: NSRect, to screen: NSScreen?) -> NSRect { frameRect }
}

/// Creates the consistently configured click-through panel used by every actor
/// and prop. Callers only supply stacking behavior that is inherited from the
/// main goose panel after it has been created.
func makeOverlayPanel(
    size: NSSize,
    level: NSWindow.Level,
    collectionBehavior: NSWindow.CollectionBehavior
) -> FreePanel {
    let panel = FreePanel(contentRect: NSRect(origin: .zero, size: size),
                          styleMask: [.borderless, .nonactivatingPanel],
                          backing: .buffered, defer: false)
    panel.isOpaque = false
    panel.backgroundColor = .clear
    panel.hasShadow = false
    panel.isFloatingPanel = true
    panel.becomesKeyOnlyIfNeeded = true
    panel.hidesOnDeactivate = false
    panel.ignoresMouseEvents = true
    panel.level = level
    panel.collectionBehavior = collectionBehavior
    return panel
}


var hotKeyRefs: [EventHotKeyRef?] = []
var hotKeyActions: [UInt32: () -> Void] = [:]
let hotKeyCallback: EventHandlerUPP = { _, event, _ in
    var hk = EventHotKeyID()
    GetEventParameter(event, EventParamName(kEventParamDirectObject), EventParamType(typeEventHotKeyID),
                      nil, MemoryLayout<EventHotKeyID>.size, nil, &hk)
    let id = hk.id
    DispatchQueue.main.async { hotKeyActions[id]?() }
    return noErr
}

/// ⌥⌘G (goose) and ⌥⌘F (fish), anywhere in the system.
func installHotKeys(_ keys: [(code: Int, id: UInt32, action: () -> Void)]) {
    var spec = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed))
    InstallEventHandler(GetApplicationEventTarget(), hotKeyCallback, 1, &spec, nil, nil)
    for k in keys {
        hotKeyActions[k.id] = k.action
        var ref: EventHotKeyRef?
        RegisterEventHotKey(UInt32(k.code), UInt32(optionKey | cmdKey),
                            EventHotKeyID(signature: OSType(0x474F4F53), id: k.id),
                            GetApplicationEventTarget(), 0, &ref)
        hotKeyRefs.append(ref)
    }
}

var DEBUG = false
func dlog(_ m: String) { if DEBUG { FileHandle.standardError.write(("[goose] " + m + "\n").data(using: .utf8)!) } }

final class AppDelegate: NSObject, NSApplicationDelegate {
    let goose = Goose()
    var panel: NSPanel!
    var view: GooseView!
    var statusItem: NSStatusItem!
    var last = CFAbsoluteTimeGetCurrent()

    // drag bookkeeping
    var dragging = false
    var dragOffset = CGSize.zero
    var dragVel = CGPoint.zero
    var dragLast = CGPoint.zero
    var dragLastT = CFAbsoluteTimeGetCurrent()
    var dragMoved: CGFloat = 0
    var clickable = false
    var wasClickable = false
    var awake = true

    // the fish
    var fish: Fish?
    var fishPanel: NSPanel!
    var fishView: FishView!
    var draggingFish = false
    var fishClickable = false
    var fishOffset = CGSize.zero
    var fishLastT = CFAbsoluteTimeGetCurrent()

    // eggs and goslings, each in its own little window
    var eggs: [(egg: Egg, panel: FreePanel, view: PropView)] = []
    var chicks: [(chick: Chick, panel: FreePanel, view: PropView,
                  spell: FreePanel, spellView: PropView)] = []
    var nextChickID = 1
    var hotEgg: PropView?
    var hotChick: PropView?
    var draggingChickID: Int?
    var chickOffset = CGSize.zero
    var chickLastT = CFAbsoluteTimeGetCurrent()

    // optional University of Toronto coyote and its far teleport circle
    var coyote: Coyote?
    var coyotePanel: FreePanel?
    var coyoteView: PropView?
    var coyoteSpell: FreePanel?
    var coyoteSpellView: PropView?
    var draggingCoyote = false, coyoteClickable = false
    var coyoteOffset = CGSize.zero, coyoteVel = CGPoint.zero
    var coyoteLast = CGPoint.zero, coyoteLastT = CFAbsoluteTimeGetCurrent()

    func applicationDidFinishLaunching(_ n: Notification) {
        // prefer an external display — that's "my monitor"
        let external = NSScreen.screens.first { !$0.localizedName.lowercased().contains("built-in") }
        goose.screen = external ?? NSScreen.screens[0]
        goose.move(to: goose.screen)

        let overlayLevel = NSWindow.Level(rawValue: NSWindow.Level.floating.rawValue + 1)
        let overlayBehavior: NSWindow.CollectionBehavior = [
            .canJoinAllSpaces, .stationary, .fullScreenAuxiliary, .ignoresCycle
        ]
        panel = makeOverlayPanel(size: NSSize(width: WIN_W, height: WIN_H),
                                 level: overlayLevel,
                                 collectionBehavior: overlayBehavior)

        view = GooseView(frame: NSRect(x: 0, y: 0, width: WIN_W, height: WIN_H))
        view.goose = goose
        view.onGrab = { [weak self] p in self?.beginDrag(at: p) }
        view.onDrag = { [weak self] p in self?.updateDrag(p) }
        view.onRelease = { [weak self] in self?.endDrag() }
        panel.contentView = view
        panel.orderFrontRegardless()

        fishPanel = makeOverlayPanel(size: NSSize(width: FISHWIN_W, height: FISHWIN_H),
                                     level: panel.level,
                                     collectionBehavior: panel.collectionBehavior)

        fishView = FishView(frame: NSRect(x: 0, y: 0, width: FISHWIN_W, height: FISHWIN_H))
        fishView.fish = { [weak self] in self?.fish }
        fishView.onGrab = { [weak self] in self?.beginFishDrag() }
        fishView.onDrag = { [weak self] p in self?.updateFishDrag(p) }
        fishView.onRelease = { [weak self] in self?.endFishDrag() }
        fishPanel.contentView = fishView

        goose.onAte = { [weak self] in self?.removeFish() }

        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        statusItem.button?.title = "🪿"
        statusItem.menu = buildMenu()
        view.menu = buildMenu()                   // right-click the goose
        fishView.menu = buildMenu()

        let t = Timer(timeInterval: 1.0 / 60.0, repeats: true) { [weak self] _ in self?.tick() }
        RunLoop.current.add(t, forMode: .common)

        installHotKeys([
            (code: kVK_ANSI_G, id: 1, action: { [weak self] in self?.toggleGoose() }),
            (code: kVK_ANSI_F, id: 2, action: { [weak self] in self?.dropFish() })
        ])
    }

    private func buildMenu() -> NSMenu {
        let m = NSMenu()
        let tg = m.addItem(withTitle: awake ? "Put goose away" : "Let the goose out",
                           action: #selector(toggleGoose), keyEquivalent: "g")
        tg.target = self
        tg.keyEquivalentModifierMask = [.command, .option]
        m.addItem(.separator())
        m.addItem(withTitle: "Honk", action: #selector(doHonk), keyEquivalent: "").target = self
        m.addItem(withTitle: "Hop", action: #selector(doJump), keyEquivalent: "").target = self
        m.addItem(withTitle: "Fly somewhere", action: #selector(doFly), keyEquivalent: "").target = self
        m.addItem(withTitle: "Come here", action: #selector(doCome), keyEquivalent: "").target = self
        m.addItem(.separator())

        let fi = m.addItem(withTitle: fish == nil ? "Drop a fish" : "Move the fish here",
                           action: #selector(dropFish), keyEquivalent: "f")
        fi.target = self
        fi.keyEquivalentModifierMask = [.command, .option]
        if fish != nil {
            m.addItem(withTitle: "Take the fish away", action: #selector(takeFish), keyEquivalent: "").target = self
        }
        m.addItem(withTitle: "Lay an egg", action: #selector(layEgg), keyEquivalent: "").target = self
        m.addItem(withTitle: coyote == nil ? "Spawn coyote" : "Despawn coyote",
                  action: #selector(toggleCoyote), keyEquivalent: "").target = self
        if goose.fed > 0 {
            let n = m.addItem(withTitle: goose.fed == 1 ? "1 fish eaten" : "\(goose.fed) fish eaten",
                              action: nil, keyEquivalent: "")
            n.isEnabled = false
        }
        m.addItem(.separator())

        let screens = NSMenuItem(title: "Screen", action: nil, keyEquivalent: "")
        let sub = NSMenu()
        for (i, s) in NSScreen.screens.enumerated() {
            let it = sub.addItem(withTitle: s.localizedName, action: #selector(pickScreen(_:)), keyEquivalent: "")
            it.target = self
            it.tag = i
            it.state = (s == goose.screen) ? .on : .off
        }
        screens.submenu = sub
        m.addItem(screens)

        let f = m.addItem(withTitle: "Follow my cursor", action: #selector(toggleFollow), keyEquivalent: "")
        f.target = self; f.state = goose.followCursor ? .on : .off
        let st = m.addItem(withTitle: "Stretchy mode", action: #selector(toggleStretchy), keyEquivalent: "")
        st.target = self; st.state = goose.stretchy ? .on : .off
        let s = m.addItem(withTitle: "Honk sounds", action: #selector(toggleSound), keyEquivalent: "")
        s.target = self; s.state = goose.soundOn ? .on : .off
        if !chicks.isEmpty {
            m.addItem(.separator())
            let hdr = m.addItem(withTitle: chicks.count == 1 ? "1 gosling" : "\(chicks.count) goslings",
                                action: nil, keyEquivalent: "")
            hdr.isEnabled = false
            for c in chicks {
                let it = m.addItem(withTitle: "\u{2715}   Gosling \(c.chick.id)",
                                   action: #selector(shooChick(_:)), keyEquivalent: "")
                it.target = self
                it.tag = c.chick.id
            }
            m.addItem(withTitle: "Shoo them all", action: #selector(shooAllChicks), keyEquivalent: "").target = self
        }
        m.addItem(.separator())
        m.addItem(withTitle: "Quit goose", action: #selector(quit), keyEquivalent: "q").target = self
        if !awake {
            for it in m.items where it.action != #selector(toggleGoose) && it.action != #selector(quit) {
                it.isEnabled = false
            }
            m.autoenablesItems = false
        }
        return m
    }

    private func refreshMenus() {
        statusItem.menu = buildMenu()
        view.menu = buildMenu()
        fishView?.menu = buildMenu()
        for e in eggs { e.view.menu = buildMenu() }
        for c in chicks { c.view.menu = buildMenu() }
        coyoteView?.menu = buildMenu()
    }

    /// ⌥⌘G, the Desktop shortcut, and the menu all land here.
    @objc func toggleGoose() {
        awake.toggle()
        if awake {
            last = CFAbsoluteTimeGetCurrent()
            goose.ledges = LedgeFinder.current(on: goose.screen)
            panel.orderFrontRegardless()
            if fish != nil { showFishPanel() }
            for e in eggs { e.panel.orderFrontRegardless() }
            for c in chicks { c.panel.orderFrontRegardless() }
            if coyote != nil { coyotePanel?.orderFrontRegardless() }
            panel.orderFrontRegardless()
            goose.honk()
        } else {
            if dragging { endDrag() }
            if draggingFish { endFishDrag() }
            if draggingChickID != nil { endChickDrag() }
            if draggingCoyote { endCoyoteDrag() }
            panel.orderOut(nil)
            fishPanel.orderOut(nil)
            for e in eggs { e.panel.orderOut(nil) }
            for c in chicks { c.panel.orderOut(nil); c.spell.orderOut(nil) }
            coyotePanel?.orderOut(nil); coyoteSpell?.orderOut(nil)
            hotEgg = nil
            hotChick = nil
            if clickable || fishClickable {
                clickable = false; fishClickable = false
                panel.ignoresMouseEvents = true
                fishPanel.ignoresMouseEvents = true
                NSCursor.arrow.set()
            }
        }
        statusItem.button?.appearsDisabled = !awake
        refreshMenus()
        dlog("awake=\(awake)")
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        toggleGoose()          // double-clicking the Desktop shortcut again toggles
        return true
    }

    @objc func doHonk() { goose.honk() }
    @objc func doJump() { if !goose.jumpSomewhere() { goose.vy = 620; goose.support = nil; goose.act = .air } }
    @objc func doFly()  { goose.flyOff(preferWindows: true) }
    @objc func doCome() { goose.goTo(NSEvent.mouseLocation.x) }
    @objc func pickScreen(_ item: NSMenuItem) {
        guard item.tag < NSScreen.screens.count else { return }
        goose.move(to: NSScreen.screens[item.tag])
        refreshMenus()
    }
    @objc func toggleFollow(_ item: NSMenuItem) {
        goose.followCursor.toggle()
        if goose.followCursor { goose.goTo(NSEvent.mouseLocation.x) } else { goose.targetX = nil }
        refreshMenus()
    }
    @objc func toggleStretchy(_ item: NSMenuItem) {
        goose.stretchy.toggle()
        if !goose.stretchy { goose.resetStretch() }
        refreshMenus()
    }
    @objc func toggleSound(_ item: NSMenuItem) { goose.soundOn.toggle(); refreshMenus() }
    @objc func quit() { NSApp.terminate(nil) }

    // MARK: the fish
    /// Puts a fish under the cursor — where you then drag it around from.
    @objc func dropFish() {
        if !awake { toggleGoose() }
        let m = NSEvent.mouseLocation

        // playing on another display? the goose comes to you
        if let s = NSScreen.screens.first(where: { $0.frame.contains(m) }), s != goose.screen {
            goose.move(to: s)
        }

        let f = fish ?? Fish(x: m.x, y: m.y)
        f.x = m.x; f.y = m.y + 12
        f.vx = 0; f.vy = 0
        f.held = false; f.gone = false; f.resting = false; f.support = nil
        fish = f
        goose.fish = f
        showFishPanel()
        goose.honk("HONK!")
        refreshMenus()
    }

    @objc func takeFish() { removeFish() }

    private func showFishPanel() {
        guard let f = fish else { return }
        fishPanel.setFrameOrigin(NSPoint(x: (f.x - FISH_ANCHOR.x).rounded(),
                                         y: (f.y - FISH_ANCHOR.y).rounded()))
        fishPanel.orderFrontRegardless()
        panel.order(.above, relativeTo: fishPanel.windowNumber)   // the bird stays in front
    }

    func removeFish() {
        draggingFish = false
        fish = nil
        goose.fish = nil
        fishPanel.orderOut(nil)
        if fishClickable { fishClickable = false; fishPanel.ignoresMouseEvents = true }
        refreshMenus()
    }

    private func beginFishDrag() {
        guard let f = fish else { return }
        dlog("fish grab")
        draggingFish = true
        let m = NSEvent.mouseLocation
        fishOffset = CGSize(width: f.x - m.x, height: f.y - m.y)
        fishLastT = CFAbsoluteTimeGetCurrent()
        f.held = true
        f.resting = false
        f.support = nil
        f.vx = 0; f.vy = 0
    }

    private func updateFishDrag(_ m: NSPoint) {
        guard draggingFish, let f = fish else { return }
        let now = CFAbsoluteTimeGetCurrent()
        let dt = max(1.0 / 240.0, now - fishLastT)
        let nx = m.x + fishOffset.width, ny = m.y + fishOffset.height
        f.vx = (nx - f.x) / CGFloat(dt) * 0.6 + f.vx * 0.4
        f.vy = (ny - f.y) / CGFloat(dt) * 0.6 + f.vy * 0.4
        if abs(f.vx) > 25 { f.dir = f.vx > 0 ? 1 : -1 }
        f.x = nx; f.y = ny
        fishLastT = now
    }

    private func endFishDrag() {
        guard draggingFish else { return }
        dlog("fish release")
        draggingFish = false
        guard let f = fish else { return }
        f.held = false
        f.vx = max(-1200, min(1200, f.vx))
        f.vy = max(-1200, min(1200, f.vy))
    }

    // MARK: eggs and goslings
    private func makePropPanel(_ size: NSSize) -> (FreePanel, PropView) {
        let p = makeOverlayPanel(size: size, level: panel.level,
                                 collectionBehavior: panel.collectionBehavior)
        let v = PropView(frame: NSRect(origin: .zero, size: size))
        p.contentView = v
        v.menu = buildMenu()
        return (p, v)
    }

    @objc func toggleCoyote() {
        if coyote == nil { spawnCoyote() } else { despawnCoyote() }
    }

    private func spawnCoyote() {
        if !awake { toggleGoose() }
        let ground = goose.ledges.first(where: { $0.ground })
            ?? Ledge(y: goose.screen.visibleFrame.minY, x0: goose.screen.frame.minX,
                     x1: goose.screen.frame.maxX, ground: true)
        let startX = goose.x < goose.screen.frame.midX
            ? goose.screen.frame.maxX - 120 : goose.screen.frame.minX + 120
        let animal = Coyote(x: startX, y: ground.y)
        animal.support = ground; animal.grounded = true
        coyote = animal
        goose.coyote = animal

        let (cp, cv) = makePropPanel(NSSize(width: COYOTE_WIN_W, height: COYOTE_WIN_H))
        cv.render = { [weak self] in
            paintCoyote(animal, at: COYOTE_ANCHOR)
            if self?.coyote != nil {
                paintHealth(animal.health, max: 10,
                            at: CGPoint(x: COYOTE_ANCHOR.x, y: COYOTE_ANCHOR.y + 82), width: 72)
            }
        }
        cv.hit = NSRect(x: COYOTE_ANCHOR.x - 66, y: 0, width: 132, height: 82)
        cv.onDown = { [weak self] in self?.beginCoyoteDrag() }
        cv.onDrag = { [weak self] point in self?.updateCoyoteDrag(point) }
        cv.onUp = { [weak self] in self?.endCoyoteDrag() }
        cp.setFrameOrigin(NSPoint(x: animal.x - COYOTE_ANCHOR.x, y: animal.y - COYOTE_ANCHOR.y))
        cp.orderFrontRegardless()
        coyotePanel = cp; coyoteView = cv

        let (sp, sv) = makePropPanel(NSSize(width: SPELLWIN, height: SPELLWIN))
        sv.render = {
            let circles = coyoteCircles(animal)
            paintMagic(at: SPELL_ANCHOR, grow: circles.far.0, alpha: circles.far.1)
        }
        coyoteSpell = sp; coyoteSpellView = sv
        goose.honk("HONK!!!")
        refreshMenus()
    }

    private func despawnCoyote() {
        draggingCoyote = false; coyoteClickable = false
        coyotePanel?.orderOut(nil); coyoteSpell?.orderOut(nil)
        coyote = nil; coyotePanel = nil; coyoteView = nil
        coyoteSpell = nil; coyoteSpellView = nil
        goose.coyote = nil
        refreshMenus()
    }

    private func beginCoyoteDrag() {
        guard let animal = coyote else { return }
        draggingCoyote = true
        let mouse = NSEvent.mouseLocation
        coyoteOffset = CGSize(width: animal.x - mouse.x, height: animal.y - mouse.y)
        coyoteLast = mouse; coyoteLastT = CFAbsoluteTimeGetCurrent(); coyoteVel = .zero
        animal.held = true; animal.grounded = false; animal.support = nil
        animal.cast = -1; animal.vx = 0; animal.vy = 0
        goose.honk("HEY!")
    }

    private func updateCoyoteDrag(_ mouse: NSPoint) {
        guard draggingCoyote, let animal = coyote else { return }
        let now = CFAbsoluteTimeGetCurrent(), dt = max(1.0 / 240.0, now - coyoteLastT)
        let nx = mouse.x + coyoteOffset.width, ny = mouse.y + coyoteOffset.height
        coyoteVel = CGPoint(x: (mouse.x - coyoteLast.x) / CGFloat(dt) * 0.6 + coyoteVel.x * 0.4,
                            y: (mouse.y - coyoteLast.y) / CGFloat(dt) * 0.6 + coyoteVel.y * 0.4)
        animal.x = nx; animal.y = ny
        if abs(coyoteVel.x) > 25 { animal.dir = coyoteVel.x > 0 ? 1 : -1 }
        coyoteLast = mouse; coyoteLastT = now
    }

    private func endCoyoteDrag() {
        guard draggingCoyote else { return }
        draggingCoyote = false
        guard let animal = coyote else { return }
        animal.held = false; animal.grounded = false; animal.support = nil
        animal.vx = max(-1200, min(1200, coyoteVel.x))
        animal.vy = max(-1200, min(1200, coyoteVel.y))
    }

    @objc func layEgg() {
        if !awake { toggleGoose() }
        guard eggs.count < 6 else { return }
        let e = Egg(x: goose.x - goose.dir * 18, y: goose.y + Egg.halfH + 26)
        let (p, v) = makePropPanel(NSSize(width: EGGWIN, height: EGGWIN))
        v.hit = NSRect(x: EGG_ANCHOR.x - 13, y: 0, width: 26, height: 22)
        v.render = { paintEgg(e, at: EGG_ANCHOR) }
        v.onDown = { [weak self] in
            guard !e.cracking else { return }
            e.cracking = true
            e.hatchLeft = HATCH_TIME
            if self?.goose.soundOn == true { NSSound(named: "Pop")?.play() }
        }
        p.setFrameOrigin(NSPoint(x: (e.x - EGG_ANCHOR.x).rounded(), y: (e.y - EGG_ANCHOR.y).rounded()))
        p.orderFrontRegardless()
        panel.order(.above, relativeTo: p.windowNumber)
        eggs.append((e, p, v))
        goose.act = .sit
        goose.actLeft = 1.4
        goose.honk("HONK!")
        refreshMenus()
    }

    private func spawnChick(at p: CGPoint) {
        guard chicks.count < 8 else { return }
        let ch = Chick(id: nextChickID, x: p.x, y: p.y)
        nextChickID += 1
        ch.vy = 200
        let (pn, v) = makePropPanel(NSSize(width: CHICKWIN_W, height: CHICKWIN_H))
        v.render = { [weak self] in
            let anchor = chickAnchor(ch)
            paintChick(ch, at: anchor)
            if self?.coyote != nil {
                paintHealth(ch.health, max: 3, at: CGPoint(x: anchor.x, y: anchor.y + 45), width: 30)
            }
        }
        let initialAnchor = chickAnchor(ch)
        v.hit = NSRect(x: initialAnchor.x - 16, y: max(0, initialAnchor.y - 3), width: 32, height: 32)
        v.onDown = { [weak self] in self?.beginChickDrag(ch) }
        v.onDrag = { [weak self] p in self?.updateChickDrag(p) }
        v.onUp = { [weak self] in self?.endChickDrag() }
        pn.setFrameOrigin(NSPoint(x: (ch.x - initialAnchor.x).rounded(),
                                  y: (ch.y - initialAnchor.y).rounded()))
        pn.orderFrontRegardless()
        panel.order(.above, relativeTo: pn.windowNumber)

        let (sp, sv) = makePropPanel(NSSize(width: SPELLWIN, height: SPELLWIN))
        sv.render = {
            let c = spellCircles(ch)
            paintMagic(at: SPELL_ANCHOR, grow: c.far.0, alpha: c.far.1)
        }
        chicks.append((ch, pn, v, sp, sv))
        goose.honk("\u{2665}")
        refreshMenus()
    }

    @objc func shooChick(_ item: NSMenuItem) {
        guard let i = chicks.firstIndex(where: { $0.chick.id == item.tag }) else { return }
        if draggingChickID == item.tag { draggingChickID = nil }
        if chicks[i].view === hotChick { hotChick = nil }
        chicks[i].spell.orderOut(nil)
        chicks[i].panel.orderOut(nil)
        chicks.remove(at: i)
        refreshMenus()
    }

    @objc func shooAllChicks() {
        draggingChickID = nil
        hotChick = nil
        for c in chicks { c.panel.orderOut(nil); c.spell.orderOut(nil) }
        chicks.removeAll()
        refreshMenus()
    }

    private func beginChickDrag(_ ch: Chick) {
        dlog("chick grab \(ch.id)")
        draggingChickID = ch.id
        let m = NSEvent.mouseLocation
        chickOffset = CGSize(width: ch.x - m.x, height: ch.y - m.y)
        chickLastT = CFAbsoluteTimeGetCurrent()
        ch.held = true
        ch.grounded = false
        ch.support = nil
        ch.vx = 0; ch.vy = 0
        if Double.random(in: 0...1) < 0.6 { goose.honk("HONK!") }   // mother objects
    }

    private func updateChickDrag(_ m: NSPoint) {
        guard let id = draggingChickID,
              let ch = chicks.first(where: { $0.chick.id == id })?.chick else { return }
        let now = CFAbsoluteTimeGetCurrent()
        let dt = max(1.0 / 240.0, now - chickLastT)
        let nx = m.x + chickOffset.width, ny = m.y + chickOffset.height
        ch.vx = (nx - ch.x) / CGFloat(dt) * 0.6 + ch.vx * 0.4
        ch.vy = (ny - ch.y) / CGFloat(dt) * 0.6 + ch.vy * 0.4
        if abs(ch.vx) > 30 { ch.dir = ch.vx > 0 ? 1 : -1 }
        ch.x = nx; ch.y = ny
        chickLastT = now
    }

    private func endChickDrag() {
        guard let id = draggingChickID else { return }
        dlog("chick release \(id)")
        draggingChickID = nil
        guard let ch = chicks.first(where: { $0.chick.id == id })?.chick else { return }
        ch.held = false
        ch.vx = max(-900, min(900, ch.vx))
        ch.vy = max(-900, min(900, ch.vy))
    }

    // MARK: dragging
    private func beginDrag(at local: NSPoint) {
        let part: GrabPart = local.y >= view.anchor.y + 48 ? .head : .body
        dlog("grab \(part)")
        dragging = true
        dragMoved = 0
        let m = NSEvent.mouseLocation
        dragOffset = CGSize(width: goose.x - m.x, height: goose.y - m.y)
        dragLast = m
        dragLastT = CFAbsoluteTimeGetCurrent()
        dragVel = .zero
        goose.grab(part: part)
    }

    private func updateDrag(_ m: NSPoint) {
        guard dragging else { return }
        dlog("drag \(Int(m.x)),\(Int(m.y))")
        let now = CFAbsoluteTimeGetCurrent()
        let dt = max(1.0 / 240.0, now - dragLastT)
        let nx = m.x + dragOffset.width, ny = m.y + dragOffset.height
        dragMoved += abs(nx - goose.x) + abs(ny - goose.y)
        let delta = CGPoint(x: m.x - dragLast.x, y: m.y - dragLast.y)
        dragVel = CGPoint(x: delta.x / CGFloat(dt) * 0.6 + dragVel.x * 0.4,
                          y: delta.y / CGFloat(dt) * 0.6 + dragVel.y * 0.4)
        goose.tugStretch(by: delta)
        goose.x = nx; goose.y = ny
        dragLast = m; dragLastT = now
        if abs(dragVel.x) > 900 && Double.random(in: 0...1) < 0.04 { goose.honk("HONK!!") }
    }

    func endDrag() {
        guard dragging else { return }
        dlog("release moved=\(Int(dragMoved))")
        dragging = false
        // barely moved? that was a pet, not a throw
        if dragMoved < 6 {
            goose.grabPart = .whole
            goose.pet()
            goose.act = .air; goose.vx = 0; goose.vy = 0
        } else {
            goose.release(vx: dragVel.x, vy: dragVel.y)
        }
        // whichever screen you dropped it on becomes home
        if let s = NSScreen.screens.first(where: { $0.frame.contains(NSPoint(x: goose.x, y: goose.y)) }),
           s != goose.screen {
            goose.screen = s
            goose.ledges = LedgeFinder.current(on: s)
            refreshMenus()
        }
    }

    private func tick() {
        guard awake else { return }
        let now = CFAbsoluteTimeGetCurrent()
        let dt = min(0.05, now - last)
        last = now
        goose.step(dt)

        // Stretching from the head can pull the body below its usual feet
        // anchor. Reserve temporary space beneath it while held so the body is
        // not clipped; normal floor-standing windows remain seam-safe at y=0.
        let bodyRoom = dragging && goose.stretchy ? min(32, max(0, -goose.bodyStretch.y + 2)) : 0
        view.anchor = CGPoint(x: ANCHOR.x, y: bodyRoom)
        let origin = NSPoint(x: (goose.x - view.anchor.x).rounded(), y: (goose.y - view.anchor.y).rounded())
        panel.setFrameOrigin(origin)
        view.needsDisplay = true

        let m = NSEvent.mouseLocation
        var fishLocal = NSPoint(x: -999, y: -999)
        if let f = fish, !f.gone {
            // the fish falls on the goose's ledges; on another display it just drops to the floor
            let fs = NSScreen.screens.first { $0.frame.contains(NSPoint(x: f.x, y: f.y)) } ?? goose.screen
            f.step(dt, ledges: fs == goose.screen ? goose.ledges : [], screen: fs)
            let fo = NSPoint(x: (f.x - FISH_ANCHOR.x).rounded(), y: (f.y - FISH_ANCHOR.y).rounded())
            fishPanel.setFrameOrigin(fo)
            fishView.needsDisplay = true
            fishLocal = NSPoint(x: m.x - fo.x, y: m.y - fo.y)
        }

        for e in eggs {
            let es = NSScreen.screens.first { $0.frame.contains(NSPoint(x: e.egg.x, y: e.egg.y)) } ?? goose.screen
            e.egg.step(dt, ledges: es == goose.screen ? goose.ledges : [], screen: es)
            e.panel.setFrameOrigin(NSPoint(x: (e.egg.x - EGG_ANCHOR.x).rounded(),
                                           y: (e.egg.y - EGG_ANCHOR.y).rounded()))
            e.view.needsDisplay = true
        }
        for hatched in eggs where hatched.egg.cracking && hatched.egg.hatchLeft <= 0 && !hatched.egg.gone {
            hatched.egg.gone = true
            spawnChick(at: CGPoint(x: hatched.egg.x, y: hatched.egg.y - Egg.halfH))
        }
        if eggs.contains(where: { $0.egg.gone }) {
            for e in eggs where e.egg.gone { e.panel.orderOut(nil); if e.view === hotEgg { hotEgg = nil } }
            eggs.removeAll { $0.egg.gone }
            refreshMenus()
        }

        // The coyote hunts goslings; mother already used its previous-frame
        // position above and actively drives toward it while it exists.
        if let animal = coyote {
            animal.step(dt, chicks: chicks.map(\.chick), goose: goose,
                        ledges: goose.ledges, screen: goose.screen)
            if animal.health <= 0 {
                despawnCoyote()
            } else {
                coyotePanel?.setFrameOrigin(NSPoint(x: (animal.x - COYOTE_ANCHOR.x).rounded(),
                                                     y: (animal.y - COYOTE_ANCHOR.y).rounded()))
                coyoteView?.needsDisplay = true
                if animal.casting {
                    coyoteSpell?.setFrameOrigin(NSPoint(x: (animal.destX - SPELL_ANCHOR.x).rounded(),
                                                        y: (animal.destY + 5 - SPELL_ANCHOR.y).rounded()))
                    if coyoteSpell?.isVisible != true { coyoteSpell?.orderFrontRegardless() }
                    coyoteSpellView?.needsDisplay = true
                } else { coyoteSpell?.orderOut(nil) }
            }
        }
        let deadChicks = chicks.filter { $0.chick.health <= 0 }
        if !deadChicks.isEmpty {
            for dead in deadChicks { dead.panel.orderOut(nil); dead.spell.orderOut(nil) }
            if let id = draggingChickID, deadChicks.contains(where: { $0.chick.id == id }) { draggingChickID = nil }
            chicks.removeAll { $0.chick.health <= 0 }
            hotChick = nil
            refreshMenus()
        }

        // goslings flee the coyote, then return to their line behind mother.
        for (i, c) in chicks.enumerated() {
            let behind = goose.x - goose.dir * CGFloat(36 + i * 26)
            let threat = coyote.map { CGPoint(x: $0.x, y: $0.y) }
            c.chick.step(dt, ledges: goose.ledges, screen: goose.screen,
                         follow: CGPoint(x: behind, y: goose.y), threat: threat)
            let ca = chickAnchor(c.chick)
            c.panel.setFrameOrigin(NSPoint(x: (c.chick.x - ca.x).rounded(),
                                           y: (c.chick.y - ca.y).rounded()))
            c.view.hit = NSRect(x: ca.x - 16, y: max(0, ca.y - 3), width: 32, height: 32)
            c.view.needsDisplay = true

            if c.chick.casting {
                c.spell.setFrameOrigin(NSPoint(x: (c.chick.destX - SPELL_ANCHOR.x).rounded(),
                                               y: (c.chick.destY + 5 - SPELL_ANCHOR.y).rounded()))
                if !c.spell.isVisible {
                    c.spell.orderFrontRegardless()
                    c.panel.order(.above, relativeTo: c.spell.windowNumber)
                    panel.order(.above, relativeTo: c.panel.windowNumber)
                }
                c.spellView.needsDisplay = true
            } else if c.spell.isVisible {
                c.spell.orderOut(nil)
            }
        }

        // Prop panels only catch clicks while the cursor is over their artwork.
        let local = NSPoint(x: m.x - origin.x, y: m.y - origin.y)
        if dragging && NSEvent.pressedMouseButtons & 1 == 0 { endDrag() }
        if draggingFish && NSEvent.pressedMouseButtons & 1 == 0 { endFishDrag() }
        if draggingChickID != nil && NSEvent.pressedMouseButtons & 1 == 0 { endChickDrag() }
        if draggingCoyote && NSEvent.pressedMouseButtons & 1 == 0 { endCoyoteDrag() }

        var wantFish = false, wantGoose = false, wantCoyote = false
        var wantEgg: PropView?
        var wantChick: PropView?
        if dragging { wantGoose = true }
        else if draggingFish { wantFish = true }
        else if draggingCoyote { wantCoyote = true }
        else if let id = draggingChickID {
            wantChick = chicks.first(where: { $0.chick.id == id })?.view
        } else {
            wantFish = fish != nil && fishView.hitRect.contains(fishLocal)
            if !wantFish, let cp = coyotePanel, let cv = coyoteView {
                wantCoyote = cv.hit.contains(NSPoint(x: m.x - cp.frame.origin.x, y: m.y - cp.frame.origin.y))
            }
            if !wantFish, !wantCoyote {
                for c in chicks {
                    let o = c.panel.frame.origin
                    if c.view.hit.contains(NSPoint(x: m.x - o.x, y: m.y - o.y)) { wantChick = c.view; break }
                }
            }
            if !wantFish, !wantCoyote, wantChick == nil {
                for e in eggs {
                    let o = e.panel.frame.origin
                    if e.view.hit.contains(NSPoint(x: m.x - o.x, y: m.y - o.y)) { wantEgg = e.view; break }
                }
            }
            wantGoose = !wantFish && !wantCoyote && wantChick == nil && wantEgg == nil && view.hitRect.contains(local)
        }
        if wantEgg !== hotEgg {
            hotEgg = wantEgg
            for e in eggs { e.panel.ignoresMouseEvents = (e.view !== wantEgg) }
        }
        if wantChick !== hotChick {
            hotChick = wantChick
            for c in chicks { c.panel.ignoresMouseEvents = (c.view !== wantChick) }
        }
        if wantCoyote != coyoteClickable {
            coyoteClickable = wantCoyote
            coyotePanel?.ignoresMouseEvents = !wantCoyote
        }
        if wantGoose != clickable {
            clickable = wantGoose
            panel.ignoresMouseEvents = !wantGoose
            dlog("clickable=\(wantGoose)")
        }
        if wantFish != fishClickable {
            fishClickable = wantFish
            fishPanel.ignoresMouseEvents = !wantFish
            dlog("fishClickable=\(wantFish)")
        }
        let onSomething = clickable || fishClickable || coyoteClickable || hotEgg != nil || hotChick != nil
        if hotEgg != nil { NSCursor.pointingHand.set() }
        else if onSomething {
            ((dragging || draggingFish || draggingCoyote || draggingChickID != nil) ? NSCursor.closedHand : NSCursor.openHand).set()
        }
        else if wasClickable { NSCursor.arrow.set() }
        wasClickable = onSomething
    }
}

@main
enum Main {
    static func main() {
        let app = NSApplication.shared
        if let i = CommandLine.arguments.firstIndex(of: "--sheet"), i + 1 < CommandLine.arguments.count {
            Sheet.render(to: CommandLine.arguments[i + 1])
            return
        }
        if let i = CommandLine.arguments.firstIndex(of: "--iconset"), i + 1 < CommandLine.arguments.count {
            Icon.writeIconset(CommandLine.arguments[i + 1])
            return
        }
        if let i = CommandLine.arguments.firstIndex(of: "--coyote-sheet"), i + 1 < CommandLine.arguments.count {
            CoyoteSheet.render(to: CommandLine.arguments[i + 1])
            return
        }
        DEBUG = ProcessInfo.processInfo.environment["GOOSE_DEBUG"] != nil
        app.setActivationPolicy(.accessory)      // no Dock icon, menu-bar only
        let d = AppDelegate()
        app.delegate = d
        withExtendedLifetime(d) { app.run() }
    }
}
