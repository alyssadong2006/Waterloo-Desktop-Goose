#!/usr/bin/env python3
"""Generate the symmetric-outline pixel coyote frames used by both builds."""
from pathlib import Path
W, H = 72, 42

def frame(step):
    grid = [['.' for _ in range(W)] for _ in range(H)]
    mask = set()
    def ellipse(cx, cy, rx, ry):
        for y in range(H):
            for x in range(W):
                if ((x-cx)/rx)**2 + ((y-cy)/ry)**2 <= 1: mask.add((x,y))
    def polygon(points):
        for y in range(H):
            for x in range(W):
                inside, j = False, len(points)-1
                for i, (xi, yi) in enumerate(points):
                    xj, yj = points[j]
                    if (yi>y) != (yj>y) and x < (xj-xi)*(y-yi)/(yj-yi)+xi: inside = not inside
                    j = i
                if inside: mask.add((x,y))
    # Chibi proportions: plump body, oversized round head, short muzzle and one
    # clearly connected, upward-curving fluffy tail.
    ellipse(39,21,19,14); ellipse(56,15,13,12); ellipse(67,18,6,5)
    polygon([(48,10),(51,2),(57,10)]); polygon([(58,8),(64,2),(65,12)])
    ellipse(18,20,10,7); ellipse(11,15,8,6)
    polygon([(13,19),(6,15),(2,7),(5,4),(12,12)])
    offsets = ([0,2,-1,1] if step == 0 else [2,-1,2,-2])
    for i, x in enumerate([25,34,45,51]):
        x += offsets[i]
        for y in range(27,39):
            for xx in range(x-2,x+3): mask.add((xx,y))
        for xx in range(x-3,x+5): mask.add((xx,39))
    for x,y in mask:
        grid[y][x] = 'K' if any((x+dx,y+dy) not in mask for dx,dy in ((1,0),(-1,0),(0,1),(0,-1))) else 'Q'
    for x,y in mask:
        if grid[y][x] != 'K' and ((y>=25 and 16<x<55) or (x<17 and y>19)): grid[y][x] = 'X'
        if grid[y][x] != 'K' and ((61<=x<=71 and 17<=y<=22) or x<=5): grid[y][x] = 'U'
    for x,y in ((52,6),(53,5),(61,7),(62,6)):
        if (x,y) in mask: grid[y][x] = 'P'
    # Large white eye with a two-pixel pupil and glint; readable at 1x displays.
    for x,y in [(x,y) for y in range(11,16) for x in range(57,65)] + [(x,y) for y in (10,16) for x in range(59,63)]:
        if (x,y) in mask: grid[y][x] = 'W'
    for x,y in [(x,y) for y in range(12,16) for x in range(61,64)]:
        grid[y][x] = 'E'
    grid[12][61] = 'H'; grid[18][71] = 'E'
    for x,y in ((57,17),(58,17),(57,18),(58,18)):
        if (x,y) in mask: grid[y][x] = 'P'
    for x in range(64,71):
        if (x,22) in mask: grid[22][x] = 'E'
    return [''.join(row) for row in grid]

def swift_sprite(name, rows):
    body = '\n'.join(f'        "{row}",' for row in rows)
    return f'    static let {name} = Sprite(rows: [\n{body}\n    ])'

# A 17x17 miniature of the supplied U of T seal: double circular navy ring,
# branching tree, crowned shield, paired open books, wolf/leaf point and banner.
tag_grid = [['.' for _ in range(17)] for _ in range(17)]
for y in range(17):
    for x in range(17):
        distance = ((x-8)**2 + (y-8)**2) ** .5
        if distance <= 8.1:
            # Fixed double navy ring. Keeping both outlines in the sprite avoids
            # the rune glow making a thin mark appear to change weight.
            tag_grid[y][x] = 'K' if distance >= 6.35 or 5.25 <= distance <= 5.75 else 'W'
# tree canopy and trunk
for x,y in [(8,2),(6,3),(8,3),(10,3),(5,4),(7,4),(8,4),(9,4),(11,4),
            (6,5),(7,5),(8,5),(9,5),(10,5),(8,6),(8,7)]: tag_grid[y][x] = 'E'
# little crown above the shield
for x,y in [(6,7),(10,7),(7,8),(8,7),(9,8)]: tag_grid[y][x] = 'E'
# shield outline, narrowing to a point
for x in range(4,13): tag_grid[8][x] = 'E'
for y,left,right in [(9,4,12),(10,4,12),(11,5,11),(12,6,10),(13,8,8)]:
    tag_grid[y][left] = tag_grid[y][right] = 'E'
# two open books and the dark lower field/white wolf-leaf mark
for x,y in [(5,10),(6,9),(7,10),(9,10),(10,9),(11,10),(6,11),(7,11),(8,11),(9,11),(10,11)]: tag_grid[y][x] = 'E'
for x in range(6,11): tag_grid[12][x] = 'E'
tag_grid[12][8] = 'W'
# banner beneath the shield
for x in range(4,13):
    if tag_grid[14][x] != '.': tag_grid[14][x] = 'E'
tag = [''.join(row).replace('K', 'J').replace('E', 'J') for row in tag_grid]
out = 'import Cocoa\n\nextension Art {\n' + swift_sprite('coyoteA', frame(0)) + '\n' + swift_sprite('coyoteB', frame(1)) + '\n' + swift_sprite('torontoTag', tag) + '\n}\n'
root = Path(__file__).resolve().parents[1]
(root/'coyote_art.swift').write_text(out)
print('Generated coyote_art.swift')
