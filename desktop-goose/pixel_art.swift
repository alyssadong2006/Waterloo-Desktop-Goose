import Cocoa

// ───────────────────────────────── pixel art ──────────────────────────────

let PIX: CGFloat = 1.5                     // points per sprite pixel
let TEXT_PIX: CGFloat = 3                  // speech bubbles stay coarse, and readable

enum Pal {
    static let table: [Character: NSColor] = [
        "K": NSColor(srgbRed: 0.25, green: 0.23, blue: 0.33, alpha: 1),   // outline
        "W": NSColor(srgbRed: 1.00, green: 0.99, blue: 0.96, alpha: 1),   // chinstrap + eye
        "E": NSColor(srgbRed: 0.17, green: 0.15, blue: 0.23, alpha: 1),   // pupil
        "H": NSColor.white,                                               // eye glint
        "R": NSColor(srgbRed: 1.00, green: 0.36, blue: 0.48, alpha: 1),   // heart
        "B": NSColor(srgbRed: 1.00, green: 1.00, blue: 0.99, alpha: 1),   // bubble fill
        "F": NSColor(srgbRed: 0.98, green: 0.55, blue: 0.36, alpha: 1),   // fish
        "C": NSColor(srgbRed: 1.00, green: 0.83, blue: 0.64, alpha: 1),   // fish belly
        "A": NSColor(srgbRed: 0.90, green: 0.20, blue: 0.22, alpha: 1),   // anger
        "N": NSColor(srgbRed: 0.11, green: 0.11, blue: 0.14, alpha: 1),   // black head / neck / bill / legs
        "T": NSColor(srgbRed: 0.48, green: 0.39, blue: 0.29, alpha: 1),   // brown back
        "U": NSColor(srgbRed: 0.87, green: 0.82, blue: 0.72, alpha: 1),   // pale breast
        "V": NSColor(srgbRed: 0.35, green: 0.28, blue: 0.20, alpha: 1),   // wing barring
        "Y": NSColor(srgbRed: 1.00, green: 0.80, blue: 0.15, alpha: 1),   // Waterloo gold
        "M": NSColor(srgbRed: 0.78, green: 0.09, blue: 0.18, alpha: 1),   // crest lions
        "P": NSColor(srgbRed: 1.00, green: 0.55, blue: 0.62, alpha: 1),   // cheek blush
        "G": NSColor(srgbRed: 0.96, green: 0.88, blue: 0.50, alpha: 1),   // gosling down
        "L": NSColor(srgbRed: 0.73, green: 0.67, blue: 0.36, alpha: 1),   // gosling shade
        "Z": NSColor(srgbRed: 0.65, green: 0.45, blue: 0.98, alpha: 1),   // wizardry
        "I": NSColor(srgbRed: 0.92, green: 0.88, blue: 1.00, alpha: 1),   // rune glow
        "Q": NSColor(srgbRed: 0.55, green: 0.47, blue: 0.39, alpha: 1),   // warm coyote fur
        "X": NSColor(srgbRed: 0.38, green: 0.31, blue: 0.27, alpha: 1),   // coyote shade
        "J": NSColor(srgbRed: 0.04, green: 0.18, blue: 0.32, alpha: 1),   // Toronto navy
        // spare, from back when it was a white goose with an orange bill
        "S": NSColor(srgbRed: 0.85, green: 0.87, blue: 0.94, alpha: 1),   // shade
        "O": NSColor(srgbRed: 1.00, green: 0.74, blue: 0.26, alpha: 1),   // orange bill + feet
        "D": NSColor(srgbRed: 0.89, green: 0.52, blue: 0.14, alpha: 1),   // orange bill shade
    ]
}

struct Sprite {
    let rows: [String]
    var w: Int { rows.first?.count ?? 0 }
    var h: Int { rows.count }
}

enum Art {    // Canada goose: black head, white chinstrap up the cheek from the throat.
    static let head = Sprite(rows: [
        "......KKKKKKKK......",
        "....KKNNNNNNNNKK....",
        "...KNNNNNNNNNNNNK...",
        "..KNNNNNNNNNNNNNNK..",
        ".KNNNNNNNNNWWWNNNNK.",
        ".KNNNNNNNNWHEEWNNNK.",
        "KNNNNNNNNNWEEEWNNNNK",
        "KNNNNNNNNNWEEEWNNNNK",
        "KNNNNNNNNNNWWWNNNNNK",
        "KNNNNNNNNNNNNNNNNNNK",
        "KNNNNNPPNNNNNNNNNNNK",
        "KNNNNNPPNNNNWWWWWNNK",
        ".KNNNNNNNNWWWWWWNNK.",
        ".KNNNNNNWWWWWWWNNNK.",
        "..KNNNNWWWWWWWNNNK..",
        "...KNNNWWWWWWNNNK...",
        "....KKNNWWWWNNKK....",
        "......KKKKKKKK......"
    ])
    static let headBlink = Sprite(rows: [
        "......KKKKKKKK......",
        "....KKNNNNNNNNKK....",
        "...KNNNNNNNNNNNNK...",
        "..KNNNNNNNNNNNNNNK..",
        ".KNNNNNNNNNNNNNNNNK.",
        ".KNNNNNNNNNNNNNNNNK.",
        "KNNNNNNNNNWWWWWNNNNK",
        "KNNNNNNNNNNNNNNNNNNK",
        "KNNNNNNNNNNNNNNNNNNK",
        "KNNNNNNNNNNNNNNNNNNK",
        "KNNNNNPPNNNNNNNNNNNK",
        "KNNNNNPPNNNNWWWWWNNK",
        ".KNNNNNNNNWWWWWWNNK.",
        ".KNNNNNNWWWWWWWNNNK.",
        "..KNNNNWWWWWWWNNNK..",
        "...KNNNWWWWWWNNNK...",
        "....KKNNWWWWNNKK....",
        "......KKKKKKKK......"
    ])
    static let headAngry = Sprite(rows: [
        "......KKKKKKKK......",
        "....KKNNNNNNNNKK....",
        "...KNNNNNNNNNNNNK...",
        "..KNNNNNNNNNNNNNNK..",
        ".KNNNNNNNNNNNNNNNNK.",
        ".KNNNNNNNNNNNNNNNNK.",
        "KNNNNNNNNNWEENNNNNNK",
        "KNNNNNNNNNWEEEWNNNNK",
        "KNNNNNNNNNWWWWWNNNNK",
        "KNNNNNNNNNNNNNNNNNNK",
        "KNNNNNPPNNNNNNNNNNNK",
        "KNNNNNPPNNNNWWWWWNNK",
        ".KNNNNNNNNWWWWWWNNK.",
        ".KNNNNNNWWWWWWWNNNK.",
        "..KNNNNWWWWWWWNNNK..",
        "...KNNNWWWWWWNNNK...",
        "....KKNNWWWWNNKK....",
        "......KKKKKKKK......"
    ])
    static let anger = Sprite(rows: [
        "AA......AA",
        "AA......AA",
        "..AA..AA..",
        "..AA..AA..",
        "....AA....",
        "....AA....",
        "..AA..AA..",
        "..AA..AA..",
        "AA......AA",
        "AA......AA"
    ])
    static let beak = Sprite(rows: [
        "..KKKKKK..",
        "NNNNNNNKK.",
        "NNNNNNNNNK",
        "NNNNNNNNK.",
        "NNNNNNKK..",
        "..KKKKK..."
    ])
    static let beakUpper = Sprite(rows: [
        "..KKKKKK..",
        "NNNNNNNKK.",
        "NNNNNNNNNK"
    ])
    static let beakLower = Sprite(rows: [
        "NNNNNNNNK.",
        "NNNNNNKK..",
        "..KKKKK..."
    ])
    static let body = Sprite(rows: [
        "...........KKKKKKKKKKKKKK...........",
        ".......KKKKTTTTTTTTTTTTTTKKKK.......",
        ".....KKTTTTTTTTTTTTTTTTTTTTTTKK.....",
        "....KTTTTTTTTTTTTTTTTTTTTTTTTTTK....",
        "..KKTTTTTTTTTTTTTTTTTTTTTTTTTTTTKK..",
        "..KTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTK..",
        ".KTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTK.",
        ".KTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTK.",
        "KTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTK",
        "KTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTK",
        "KTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTK",
        "KTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTK",
        "KTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTK",
        "KTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTK",
        "KTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTK",
        "KWWWWWWWWUUUUUUUUUUUUUUUUUUUUUUUUUUK",
        ".KWWWWWWUUUUUUUUUUUUUUUUUUUUUUUUUUK.",
        ".KWWWWWUUUUUUUUUUUUUUUUUUUUUUUUUUUK.",
        "..KWWWUUUUUUUUUUUUUUUUUUUUUUUUUUUK..",
        "..KKWUUUUUUUUUUUUUUUUUUUUUUUUUUUKK..",
        "....KUUUUUUUUUUUUUUUUUUUUUUUUUUK....",
        ".....KKUUUUUUUUUUUUUUUUUUUUUUKK.....",
        ".......KKKKUUUUUUUUUUUUUUKKKK.......",
        "...........KKKKKKKKKKKKKK..........."
    ])
    static let tail = Sprite(rows: [
        "KKKK......",
        "KNNNKK....",
        "KNNNNNKK..",
        "KNNNNNNNKK",
        "KNNNNNNNNN",
        ".KNNNNNNNN",
        "..KKNNNNNN",
        "....KKKKKK"
    ])
    /// The University of Waterloo seal, worn as a cutie mark on the flank:
    /// black lettering ring, white field, gold shield with a white-edged black
    /// chevron and three crimson lions. Symmetric, so mirroring it is safe.
    static let tag = Sprite(rows: [
        "......KKKKK......",
        "....KKKKKKKKK....",
        "..KKKKWWWWWKKKK..",
        "..KKWWWWWWWWWKK..",
        ".KKWWMMYYYMMWWKK.",
        ".KKWWMMYYYMMWWKK.",
        "KKWWWYYYYYYYWWWKK",
        "KKWWWYYYYYYYWWWKK",
        "KKWWWYYYWYYYWWWKK",
        "KKWWWYYWKWYYWWWKK",
        "KKWWWYWKYKWYWWWKK",
        ".KKWWWYMMMYWWWKK.",
        ".KKWWWWYMYWWWWKK.",
        "..KKWWWWWWWWWKK..",
        "..KKKKWWWWWKKKK..",
        "....KKKKKKKKK....",
        "......KKKKK......"
    ])
    static let wingFold = Sprite(rows: [
        "..KKKKKKKKKK....",
        ".KVVVVVVVVVVKK..",
        "KVVVVVVVVVVVVVK.",
        "KVVTTTVVTTTVVVK.",
        "KVVVVVVVVVVVVVK.",
        "KVVTTTVVTTTVVVK.",
        "KVVVVVVVVVVVVVK.",
        ".KVVVVVVVVVVVK..",
        "..KKVVVVVVVKK...",
        "....KKKKKKK....."
    ])
    static let wingUp = Sprite(rows: [
        "......KKKKKK....",
        ".....KTTVVK.....",
        "....KTTVVVK.....",
        "...KTTVVVVK.....",
        "..KTTVVVVK......",
        "..KTVVVVK.......",
        ".KTVVVVK........",
        ".KTVVVK.........",
        "KTVVVK..........",
        "KTVVK...........",
        "KVVK............",
        ".KK............."
    ])
    static let wingDown = Sprite(rows: [
        "....KKKKKKKK....",
        "..KKTTVVVVTTKK..",
        ".KTTVVVVVVVVTTK.",
        "KTVVVVVVVVVVVVTK",
        ".KTVVVVVVVVVVTK.",
        "..KTVVVVVVVVTK..",
        "...KTVVVVVVTK...",
        "....KTVVVVTK....",
        ".....KTVVTK.....",
        "......KKKK......"
    ])
    static let legStand = Sprite(rows: [
        "....NNNN....NNNN....",
        "....NNNN....NNNN....",
        "....NNNN....NNNN....",
        "....NNNN....NNNN....",
        "..NNNNNNN..NNNNNNN..",
        ".NNNNNNNN..NNNNNNNN."
    ])
    static let legWalkA = Sprite(rows: [
        "....NNNN....NNNN....",
        "....NNNN....NNNN....",
        "..NNNN........NNNN..",
        "..NNNN........NNNN..",
        "NNNNNN........NNNNNN",
        "NNNNNN........NNNNNN"
    ])
    static let legWalkB = Sprite(rows: [
        "......NNNN..NNNN....",
        "......NNNN..NNNN....",
        "......NNNN..NNNN....",
        "......NNNN..NNNN....",
        "....NNNNNN..NNNNNN..",
        "....NNNNNN..NNNNNN.."
    ])
    static let legTuck = Sprite(rows: [
        "......NNNN..NNNN....",
        "......NNNN..NNNN....",
        "....KKKKK..KKKKK....",
        "....KKKKK..KKKKK...."
    ])
    static let legDangle = Sprite(rows: [
        "....NNNN....NNNN....",
        "....NNNN....NNNN....",
        "....NNNN....NNNN....",
        "....NNNN....NNNN....",
        "....NNNN....NNNN....",
        "....NNNN....NNNN....",
        "..NNNNNN....NNNNNN..",
        "..NNNNNN....NNNNNN.."
    ])
    static let heart = Sprite(rows: [
        "..RR..RR..",
        ".RRRRRRRR.",
        "RRRRRRRRRR",
        "RRRRRRRRRR",
        "RRRRRRRRRR",
        ".RRRRRRRR.",
        ".RRRRRRRR.",
        "..RRRRRR..",
        "...RRRR...",
        "....RR...."
    ])
    // two tail positions, so it flaps while you swing it around
    static let fishA = Sprite(rows: [
        "............................",
        "KK..........................",
        "KFK...........KKKKKKKKK.....",
        "KFFKK.......KKFFFFFFFFFKK...",
        "KFFFFK.....KFFFFFFFFFFFFFK..",
        ".KFFFFKK..KFFFFFFFFFFFFFFFK.",
        "..KFFFFFKKFFFFFFFFFFFFEHFFFK",
        "...KFFFFFFFFFFFFFFFFFFEEFFFK",
        "....KFFFFFFFFFFFFFFFFFFFFFFK",
        "....KFFFFFFFFFFFFFFFFFFFFFFK",
        "...KFFFFFFFFFFFFFFFFFFFFFFFK",
        "..KCCCCCKKCCCCCCCCCCCCCCCCCK",
        ".KCCCCKK..KCCCCCCCCCCCCCCCK.",
        "KCCCCK.....KCCCCCCCCCCCCCK..",
        "KCCKK.......KKCCCCCCCCCKK...",
        "KCK...........KKKKKKKKK.....",
        "KK..........................",
        "............................"
    ])
    static let fishB = Sprite(rows: [
        "............................",
        ".KK.........................",
        ".KFKK.........KKKKKKKKK.....",
        ".KFFFK......KKFFFFFFFFFKK...",
        ".KFFFFKK...KFFFFFFFFFFFFFK..",
        "..KFFFFFKKKFFFFFFFFFFFFFFFK.",
        "...KFFFFFFFFFFFFFFFFFFEHFFFK",
        "....KKFFFFFFFFFFFFFFFFEEFFFK",
        "......KFFFFFFFFFFFFFFFFFFFFK",
        "......KFFFFFFFFFFFFFFFFFFFFK",
        "....KKFFFFFFFFFFFFFFFFFFFFFK",
        "...KCCCCCCCCCCCCCCCCCCCCCCCK",
        "..KCCCCCKKKCCCCCCCCCCCCCCCK.",
        ".KCCCCKK...KCCCCCCCCCCCCCK..",
        ".KCCCK......KKCCCCCCCCCKK...",
        ".KCKK.........KKKKKKKKK.....",
        ".KK.........................",
        "............................"
    ])
    // an egg, and the same egg once you have clicked it
    static let egg = Sprite(rows: [
        "....KK....",
        "...KUUK...",
        "..KUUUUK..",
        "..KUUUUK..",
        ".KUUUUUUK.",
        ".KUUVUUUK.",
        "KUUUUUUUUK",
        "KUUUUUVUUK",
        "KUUUUUUUUK",
        "KUVUUUUUUK",
        ".KUUUUUUK.",
        "..KUUUUK..",
        "...KKKK..."
    ])
    static let eggCrack = Sprite(rows: [
        "....KK....",
        "...KUUK...",
        "..KUUUUK..",
        "..KUUUUK..",
        ".KUUUUUUK.",
        ".KUUKUUUK.",
        "KUKUKUKUUK",
        "KKUKUKVKKK",
        "KUUKUUKUUK",
        "KUVKUUKUUK",
        ".KUUUUUUK.",
        "..KUUUUK..",
        "...KKKK..."
    ])
    // a gosling, two walk frames
    static let chickA = Sprite(rows: [
        "..........KKKK....",
        "........KKGGGGKK..",
        "........KGGGGGGK..",
        ".......KGGGGEEGNK.",
        ".......KGGGGEHGNNK",
        "...KKKKGGGGGGGGNNK",
        "..KGGGGGGGGGGGGNKK",
        ".KGGGGGGGGGGGGGK..",
        ".KGGGGGGGGGGGGK...",
        "KGGGGGGGGGGGGK....",
        "KGGGGGGGGGGGGK....",
        ".KLLLLLLLLLLK.....",
        "..KLLLLLLLLK......",
        "...KKKKKKKK.......",
        ".....NN..NN.......",
        ".....NN..NN.......",
        "....NNNNNNNN......"
    ])
    static let chickB = Sprite(rows: [
        "..........KKKK....",
        "........KKGGGGKK..",
        "........KGGGGGGK..",
        ".......KGGGGEEGNK.",
        ".......KGGGGEHGNNK",
        "...KKKKGGGGGGGGNNK",
        "..KGGGGGGGGGGGGNKK",
        ".KGGGGGGGGGGGGGK..",
        ".KGGGGGGGGGGGGK...",
        "KGGGGGGGGGGGGK....",
        "KGGGGGGGGGGGGK....",
        ".KLLLLLLLLLLK.....",
        "..KLLLLLLLLK......",
        "...KKKKKKKK.......",
        ".....NN..NN.......",
        "....NN....NN......",
        "...NNN....NNN....."
    ])
    // worn by a gosling that has given up on walking
    static let wizardHat = Sprite(rows: [
        "....KK.....",
        "....KZK....",
        "...KZZK....",
        "...KZZK....",
        "..KZZZK....",
        "..KZYZZK...",
        ".KZZZZZK...",
        ".KZZZZZZK..",
        "KZZZZZZZK..",
        "KKKKKKKKKKK",
        ".KKKKKKKKK."
    ])
    static let magic = Sprite(rows: [
        ".........ZZZZZZ.........",
        ".......ZZZZZZZZZZ.......",
        ".....ZZZ........ZZZ.....",
        "....ZZ..I......I..ZZ....",
        "...ZZ...I......I...ZZ...",
        "..ZZ.....I....I.....ZZ..",
        "..Z.......ZZZZ.......Z..",
        ".ZZ.....ZZZ..ZZZ.....ZZ.",
        ".Z.II..ZZ......ZZ..II.Z.",
        "ZZ...I.Z........Z.I...ZZ",
        "ZZ....ZZ....I...ZZ....ZZ",
        "ZZ....Z....I.I...Z....ZZ",
        "ZZ....Z...I.I.I..Z....ZZ",
        "ZZ....ZZ...I.I..ZZ....ZZ",
        "ZZ...I.Z....I...Z.I...ZZ",
        ".Z.II..ZZ......ZZ..II.Z.",
        ".ZZ.....ZZZ..ZZZ.....ZZ.",
        "..Z.......ZZZZ.......Z..",
        "..ZZ.....I....I.....ZZ..",
        "...ZZ...I......I...ZZ...",
        "....ZZ..I......I..ZZ....",
        ".....ZZZ........ZZZ.....",
        ".......ZZZZZZZZZZ.......",
        ".........ZZZZZZ........."
    ])
}
/// Tiny pixel font — just the glyphs the goose ever says.
enum Font5 {
    static let glyphs: [Character: [String]] = [
        "H": ["X.X", "X.X", "XXX", "X.X", "X.X"],
        "O": ["XXX", "X.X", "X.X", "X.X", "XXX"],
        "N": ["X..X", "XX.X", "XXXX", "X.XX", "X..X"],
        "K": ["X.X", "XX.", "X..", "XX.", "X.X"],
        "E": ["XXX", "X..", "XXX", "X..", "XXX"],
        "Y": ["X.X", "X.X", ".X.", ".X.", ".X."],
        "G": ["XXX", "X..", "X.X", "X.X", "XXX"],
        "U": ["X.X", "X.X", "X.X", "X.X", "XXX"],
        "M": ["X...X", "XX.XX", "X.X.X", "X...X", "X...X"],
        "R": ["XX.", "X.X", "XX.", "X.X", "X.X"],
        "!": ["X", "X", "X", ".", "X"],
        "?": ["XXX", "..X", ".XX", "...", ".X."],
        "\u{2665}": [".X.X.", "XXXXX", "XXXXX", ".XXX.", "..X.."],
        " ": ["."]
    ]

    static func width(_ s: String) -> Int {
        var w = 0
        for ch in s.uppercased() {
            guard let g = glyphs[ch] else { continue }
            w += (g.first?.count ?? 0) + 1
        }
        return max(0, w - 1)
    }
}

struct Canvas {
    let w: Int, h: Int
    /// Blank rows kept above row 0, so a head that lifts or bobs up has somewhere
    /// to go instead of being sliced off by the top of the canvas.
    let oy: Int
    var cells: [Character]

    init(w: Int, h: Int, oy: Int = 0) {
        self.w = w; self.h = h; self.oy = oy
        cells = Array(repeating: ".", count: w * h)
    }

    mutating func set(_ x: Int, _ y: Int, _ c: Character) {
        let y = y + oy
        guard x >= 0, y >= 0, x < w, y < h else { return }
        cells[y * w + x] = c
    }

    mutating func stamp(_ s: Sprite, _ x: Int, _ y: Int) {
        for (ry, row) in s.rows.enumerated() {
            for (rx, ch) in row.enumerated() where ch != "." {
                set(x + rx, y + ry, ch)
            }
        }
    }

    mutating func text(_ str: String, _ x: Int, _ y: Int, _ c: Character) {
        var cx = x
        for ch in str.uppercased() {
            guard let g = Font5.glyphs[ch] else { continue }
            for (ry, row) in g.enumerated() {
                for (rx, p) in row.enumerated() where p == "X" { set(cx + rx, y + ry, c) }
            }
            cx += (g.first?.count ?? 0) + 1
        }
    }

    /// Bottom-left of the canvas lands on `origin`; row 0 is the top row.
    func render(at origin: CGPoint, scale: CGFloat, flip: Bool, alpha: CGFloat = 1) {
        guard let ctx = NSGraphicsContext.current?.cgContext else { return }
        var byColor: [Character: [CGRect]] = [:]
        for y in 0..<h {
            for x in 0..<w {
                let c = cells[y * w + x]
                if c == "." { continue }
                let dx = flip ? CGFloat(w - 1 - x) : CGFloat(x)
                byColor[c, default: []].append(
                    CGRect(x: origin.x + dx * scale,
                           y: origin.y + CGFloat(h - 1 - y) * scale,
                           width: scale, height: scale))
            }
        }
        ctx.setShouldAntialias(false)
        for (c, rects) in byColor {
            guard let col = Pal.table[c] else { continue }
            (alpha < 1 ? col.withAlphaComponent(col.alphaComponent * alpha) : col).setFill()
            ctx.fill(rects)
        }
        ctx.setShouldAntialias(true)
    }
}

// Extra horizontal room lets stretchy mode move either half without clipping.
// The ordinary 64-pixel sprite is centred by CANVAS_SIDE_PAD.
let CANVAS_W = 96, CANVAS_H = 58, CANVAS_PAD = 28, CANVAS_BOTTOM_PAD = 18, CANVAS_SIDE_PAD = 16

/// Assembles the frame for whatever the goose is doing right now.
func composeGoose(_ g: Goose) -> Canvas {
    var c = Canvas(w: CANVAS_W, h: CANVAS_H + CANVAS_PAD + CANVAS_BOTTOM_PAD, oy: CANVAS_PAD)

    let sitting = g.act == .sit
    let tucked = g.act == .air || g.act == .fly
    let dangling = g.act == .held
    let walkFrame = Int(g.phase / 0.5) % 4

    var bob = 0
    // Keep the torso planted during the walk cycle. Alternating it by two sprite
    // rows made the whole goose snap up/down at ~10 Hz on a flat floor; goslings
    // looked stable because only their legs change between walking frames.
    if sitting { bob = 4 }
    if g.act == .fly { bob = Int(round(sin(g.clock * 17) * 2.4)) }
    if dangling { bob = -2 }

    // X offsets are stored in screen coordinates. Account for the final sprite
    // mirror so left-facing geese still sling opposite the cursor movement.
    let bodyDX = Int(round(g.bodyStretch.x * g.dir / PIX))
    let bodyDY = -Int(round(g.bodyStretch.y / PIX))
    let headDX = Int(round(g.headStretch.x * g.dir / PIX))
    let headDY = -Int(round(g.headStretch.y / PIX))

    // legs first — the body overlaps their tops
    if !sitting {
        if tucked {
            c.stamp(Art.legTuck, CANVAS_SIDE_PAD + 20 + bodyDX, 50 + bob + bodyDY)
        } else if dangling {
            let s = Int(round(sin(g.clock * 11)))
            c.stamp(Art.legDangle, CANVAS_SIDE_PAD + 20 + s * 2 + bodyDX, 50 + bodyDY)
        } else if g.walking {
            c.stamp([Art.legStand, Art.legWalkA, Art.legStand, Art.legWalkB][walkFrame],
                    CANVAS_SIDE_PAD + 20 + bodyDX, 52 + bodyDY)
        } else {
            c.stamp(Art.legStand, CANVAS_SIDE_PAD + 20 + bodyDX, 52 + bodyDY)
        }
    }

    let bodyX = CANVAS_SIDE_PAD + 14 + bodyDX, bodyY = 30 + bob + bodyDY

    // head placement
    var hx = CANVAS_SIDE_PAD + 30 + headDX, hy = 0 + bob + headDY
    if sitting { hx -= 2 }
    if g.act == .fly { hx += 4 }
    if g.act == .honk { hy -= 2 }
    hx += Int(round(g.headDip * 6))
    hy += Int(round(g.headDip * 24))

    // neck: a thick line from the shoulder to the head — the body is drawn over its base
    let ax = CGFloat(bodyX + 18), ay = CGFloat(bodyY + 8)
    let nbx = CGFloat(hx + 8), nby = CGFloat(hy + 12)
    let steps = Int(max(abs(nbx - ax), abs(nby - ay)))
    if steps > 0 {
        for i in 0...steps {
            let t = CGFloat(i) / CGFloat(steps)
            let px = Int(round(ax + (nbx - ax) * t)), py = Int(round(ay + (nby - ay) * t))
            c.set(px - 5, py, "K"); c.set(px + 5, py, "K")
            for i in -4...4 { c.set(px + i, py, "N") }
        }
    }

    c.stamp(Art.body, bodyX, bodyY)
    c.stamp(Art.tail, bodyX - 6, bodyY + 6)
    c.stamp(Art.tag, bodyX + 2, bodyY + 3)      // on the flank, *under* the wing

    var wing = Art.wingFold
    if g.act == .fly || dangling {
        wing = sin(g.clock * (dangling ? 14 : 17)) > 0 ? Art.wingUp : Art.wingDown
    } else if g.flap > 0.45 {
        wing = Art.wingUp
    }
    if g.act == .fly || dangling {
        let up = wing.h == Art.wingUp.h
        c.stamp(wing, bodyX + 8, bodyY - (up ? 8 : 0))
    } else {
        c.stamp(wing, bodyX + 13, bodyY + 9)
    }

    c.stamp(g.blinkLeft > 0 ? Art.headBlink : (g.isAngry ? Art.headAngry : Art.head), hx, hy)

    let bx = hx + 17, by = hy + 8
    if g.beakOpen > 0.25 {
        let gap = Int(round(g.beakOpen * 4))
        c.stamp(Art.beakUpper, bx, by - gap)
        c.stamp(Art.beakLower, bx, by + 3 + gap)
    } else {
        c.stamp(Art.beak, bx, by)
    }

    return c
}

/// Paints the goose (plus bubble and hearts) with `base` at its feet.
func paintGoose(_ g: Goose, at base: CGPoint) {
    let canvas = composeGoose(g)
    let origin = CGPoint(x: (base.x - CGFloat(CANVAS_W) / 2 * PIX).rounded(),
                         y: (base.y - CGFloat(CANVAS_BOTTOM_PAD) * PIX).rounded())

    if g.act != .air && g.act != .fly && g.act != .held {
        var sh = Canvas(w: 32, h: 2)
        for x in 2..<30 { sh.set(x, 0, "K"); sh.set(x, 1, "K") }
        sh.render(at: CGPoint(x: origin.x + 32 * PIX, y: base.y - 2 * PIX), scale: PIX, flip: false, alpha: 0.20)
    }

    // Keep the feet visually planted. The old angry animation shifted the entire
    // sprite left/right at high frequency, which looked like broken floor physics.
    // Anger is still communicated by the brows, vein, honks, and faster movement.
    let shake: CGFloat = 0
    canvas.render(at: CGPoint(x: origin.x, y: origin.y), scale: PIX, flip: g.dir < 0)

    // the vein, off the back of its head — hidden while it is mid-honk so the two never collide
    if g.isAngry && g.bubbleLeft <= 0 {
        var am = Canvas(w: 10, h: 10)
        am.stamp(Art.anger, 0, 0)
        am.render(at: CGPoint(x: (base.x - g.dir * 26 + shake + g.headStretch.x).rounded(),
                              y: (base.y + 84 + g.headStretch.y).rounded()),
                  scale: PIX, flip: false, alpha: CGFloat(0.65 + 0.35 * sin(g.clock * 9)))
    }

    for h in g.hearts {
        var hc = Canvas(w: 10, h: 10)
        hc.stamp(Art.heart, 0, 0)
        hc.render(at: CGPoint(x: (base.x + h.x).rounded(), y: (base.y + h.y).rounded()),
                  scale: PIX, flip: false, alpha: CGFloat(min(1, h.life / 0.45)))
    }

    if g.bubbleLeft > 0 {
        let alpha = CGFloat(min(1, g.bubbleLeft / 0.3))
        let bw = Font5.width(g.bubbleText) + 6, bh = 11
        var b = Canvas(w: bw, h: bh + 2)
        for y in 0..<bh {
            for x in 0..<bw {
                if (x == 0 || x == bw - 1) && (y == 0 || y == bh - 1) { continue }   // clipped corners
                b.set(x, y, (x == 0 || x == bw - 1 || y == 0 || y == bh - 1) ? "K" : "B")
            }
        }
        let cx = bw / 2
        b.set(cx - 1, bh, "K"); b.set(cx, bh, "B"); b.set(cx + 1, bh, "K")
        b.set(cx, bh + 1, "K")
        b.text(g.bubbleText, 3, 3, "K")
        b.render(at: CGPoint(x: (base.x + g.dir * 14 + g.headStretch.x - CGFloat(bw) / 2 * TEXT_PIX).rounded(),
                             y: (base.y + 90 + g.headStretch.y).rounded()),
                 scale: TEXT_PIX, flip: false, alpha: alpha)
    }
}

/// Paints the fish centred on `c`.
func paintFish(_ f: Fish, at c: CGPoint) {
    let rate = f.held ? 15.0 : (abs(f.vx) > 40 ? 11.0 : 5.0)
    let frame = sin(f.clock * rate) > 0 ? Art.fishA : Art.fishB
    var canvas = Canvas(w: 28, h: 18)
    canvas.stamp(frame, 0, 0)

    let bob = f.held ? CGFloat(round(sin(f.clock * 9) * 2.8)) * FISH_PIX : 0
    let origin = CGPoint(x: (c.x - Fish.halfW).rounded(), y: (c.y - Fish.halfH + bob).rounded())

    if f.resting {
        var sh = Canvas(w: 24, h: 2)
        for x in 0..<24 { sh.set(x, 0, "K"); sh.set(x, 1, "K") }
        sh.render(at: CGPoint(x: origin.x + 2 * FISH_PIX, y: origin.y - 2 * FISH_PIX),
                  scale: FISH_PIX, flip: false, alpha: 0.18)
    }
    canvas.render(at: origin, scale: FISH_PIX, flip: f.dir < 0)
}

/// Paints the egg centred on `c`.
func paintEgg(_ e: Egg, at c: CGPoint) {
    var canvas = Canvas(w: 10, h: 13)
    canvas.stamp(e.cracking ? Art.eggCrack : Art.egg, 0, 0)
    // a resting egg rocks gently; a hatching one shakes
    let rock = e.cracking ? sin(e.clock * 30) * 1.4 : (e.resting ? sin(e.clock * 2.2) * 0.6 : 0)
    let wob = CGFloat(Int(round(rock))) * EGG_PIX
    let origin = CGPoint(x: (c.x - Egg.halfW + wob).rounded(), y: (c.y - Egg.halfH).rounded())
    if e.resting {
        var sh = Canvas(w: 10, h: 2)
        for x in 1..<9 { sh.set(x, 0, "K"); sh.set(x, 1, "K") }
        sh.render(at: CGPoint(x: origin.x, y: origin.y - 2 * EGG_PIX),
                  scale: EGG_PIX, flip: false, alpha: 0.18)
    }
    canvas.render(at: origin, scale: EGG_PIX, flip: false)
}

/// A rune circle, centred on `c`, winding up from nothing as `grow` goes 0 -> 1.
func paintMagic(at c: CGPoint, grow: CGFloat, alpha: CGFloat) {
    guard alpha > 0.01 else { return }
    var mc = Canvas(w: 24, h: 24)
    mc.stamp(Art.magic, 0, 0)
    let sc = CHICK_PIX * (0.3 + 0.7 * max(0, min(1, grow)))
    mc.render(at: CGPoint(x: (c.x - 12 * sc).rounded(), y: (c.y - 12 * sc).rounded()),
              scale: sc, flip: false, alpha: alpha)
}

/// How far open each of the two circles is, and how bright, at this instant.
func spellCircles(_ ch: Chick) -> (near: (CGFloat, CGFloat), far: (CGFloat, CGFloat)) {
    guard ch.cast >= 0 else { return ((0, 0), (0, 0)) }
    let t = ch.cast
    // the one under its feet winds up first, then fades once it has gone
    let nearGrow = min(1, t / CAST_CHARGE)
    let nearAlpha = t < CAST_JUMP ? min(1, t / 0.25)
                                  : max(0, 1 - (t - CAST_JUMP) / (CAST_TOTAL - CAST_JUMP))
    // the far one opens before it arrives, and lingers a moment after
    let fo = (t - CAST_CHARGE) / (CAST_JUMP - CAST_CHARGE)
    let farGrow = max(0, min(1, fo))
    let farAlpha = t < CAST_CHARGE ? 0
                 : (t < CAST_JUMP ? min(1, fo * 1.6)
                                  : max(0, 1 - (t - CAST_JUMP) / (CAST_TOTAL - CAST_JUMP)))
    return ((nearGrow, CGFloat(nearAlpha)), (farGrow, CGFloat(farAlpha)))
}

/// Keep the gosling panel above a physical display seam while it is on the
/// monitor floor. On ordinary ledges it retains room below its feet.
func chickAnchor(_ ch: Chick) -> CGPoint {
    CGPoint(x: CHICK_ANCHOR.x, y: ch.support?.ground == true ? 0 : CHICK_ANCHOR.y)
}

/// Paints a gosling with `base` at its feet.
func paintChick(_ ch: Chick, at base: CGPoint) {
    // held: legs kicking. walking: the ordinary two-frame waddle.
    let frame = ch.held ? (sin(ch.clock * 17) > 0 ? Art.chickA : Art.chickB)
                        : ((Int(ch.phase / 0.5) % 2 == 0) ? Art.chickA : Art.chickB)
    var canvas = Canvas(w: 18, h: 17)
    canvas.stamp(frame, 0, 0)
    let wriggle = ch.held ? CGFloat(Int(round(sin(ch.clock * 12)))) * CHICK_PIX : 0
    let origin = CGPoint(x: (base.x - 9 * CHICK_PIX + wriggle).rounded(), y: base.y.rounded())

    // The monitor has no drawable area below its bottom edge. Lift the circle
    // just enough to keep it complete there; on window ledges it stays underfoot.
    let circles = spellCircles(ch)
    let circleY = base.y + (ch.support?.ground == true ? 18 : 5)
    paintMagic(at: CGPoint(x: base.x, y: circleY), grow: circles.near.0, alpha: circles.near.1)

    if ch.grounded && !ch.casting {
        var sh = Canvas(w: 12, h: 2)
        for x in 0..<12 { sh.set(x, 0, "K"); sh.set(x, 1, "K") }
        sh.render(at: CGPoint(x: origin.x + 3 * CHICK_PIX, y: origin.y - 2 * CHICK_PIX),
                  scale: CHICK_PIX, flip: false, alpha: 0.18)
    }
    // it thins out as it steps into the circle, and back in on the far side
    var solid: CGFloat = 1
    if ch.casting {
        solid = ch.cast < CAST_JUMP
            ? 1 - 0.8 * CGFloat(max(0, (ch.cast - (CAST_JUMP - 0.3)) / 0.3))
            : min(1, 0.2 + CGFloat((ch.cast - CAST_JUMP) / 0.3) * 0.8)
    }
    canvas.render(at: origin, scale: CHICK_PIX, flip: ch.dir < 0, alpha: solid)

    if ch.wizardFade > 0 {
        var hat = Canvas(w: 11, h: 11)
        hat.stamp(Art.wizardHat, 0, 0)
        let headCol: CGFloat = ch.dir < 0 ? 5 : 12          // the head, after any mirroring
        let hx = origin.x + headCol * CHICK_PIX + CHICK_PIX / 2 - 5.5 * CHICK_PIX
        // sat down over the head rather than balanced on top of it, but not so low
        // that the brim covers the eye
        hat.render(at: CGPoint(x: hx.rounded(), y: (origin.y + 13 * CHICK_PIX).rounded()),
                   scale: CHICK_PIX, flip: ch.dir < 0, alpha: CGFloat(ch.wizardFade))
    }
}
