#!/usr/bin/env python3
"""Can the caves actually be played through? Simulates the player's jumps with
the real constants from src/actors/player.gd over every room in
src/world/rooms.gd (stitched into one world grid) and reports what's
reachable from the cemetery with and without Bat Wings (the double jump).

  python3 tools/reach.py          # exits 1 if a check fails
"""
import re, sys
from collections import deque

T = 16; CW, CH = 20, 12
GRAV, MAXF, RUN, ACCEL, JUMP, FLAP = 900.0, 320.0, 100.0, 900.0, -320.0, -270.0
BW, BH = 8, 20
DT = 1 / 60
SOLID = set('#CRB'); HAZ = set('^~!')

src = open('src/world/rooms.gd').read()
world = {}; marks = {}; rooms = {}
for m in re.finditer(r'"(\w+)": \{\s*"name": "([^"]+)",\s*"cell": Vector2i\((-?\d+), (-?\d+)\).*?"map": \[(.*?)\],', src, re.S):
    rid, cx, cy = m.group(1), int(m.group(3)), int(m.group(4))
    rows = re.findall(r'"([^"]*)"', m.group(5))
    rooms[rid] = (cx, cy, rows)
    for y, row in enumerate(rows):
        for x, c in enumerate(row):
            g = (cx * CW + x, cy * CH + y)
            world[g] = c
            if c in 'FHWSJN':
                marks.setdefault(c + ':' + rid, []).append(g)

def tile(gx, gy):
    c = world.get((gx, gy))
    if c is None:
        return '.' if gy < 0 else '#'   # sky above the cemetery, rock elsewhere
    return c

def solid(c): return c in SOLID

def collide(x, y):  # box with feet at (x, y)
    x0, x1 = int((x - BW / 2) // T), int((x + BW / 2 - 0.01) // T)
    y0, y1 = int((y - BH) // T), int((y - 0.01) // T)
    return any(solid(tile(i, j)) for i in range(x0, x1 + 1) for j in range(y0, y1 + 1))

def hazard(x, y):
    x0, x1 = int((x - BW / 2 + 2) // T), int((x + BW / 2 - 2) // T)
    y0, y1 = int((y - BH + 2) // T), int((y - 2) // T)
    for i in range(x0, x1 + 1):
        for j in range(y0, y1 + 1):
            c = tile(i, j)
            if c == '!' or (c in '^~' and (y - 2) % T >= 7):
                return True
    return False

def sim(x, y, dirs, jump, flap_at, frames=150):
    """dirs: list of (until_frame, dir). Returns landing (x, y) or None."""
    vx, vy = 0.0, (JUMP if jump else 0.0)
    flapped = False
    for f in range(frames):
        d = next((dd for until, dd in dirs if f < until), 0)
        vx += max(-ACCEL * DT, min(ACCEL * DT, d * RUN - vx))
        vy = min(vy + GRAV * DT, MAXF)
        if flap_at is not None and not flapped and f >= flap_at:
            vy = FLAP; flapped = True
        nx = x + vx * DT
        if not collide(nx, y): x = nx
        else: vx = 0
        ny = y + vy * DT
        if vy > 0:
            # one-way ledges: land if feet cross a ledge top
            ft0, ft1 = int(y // T), int(ny // T)
            landed = None
            for j in range(ft0, ft1 + 1):
                top = j * T
                if y <= top + 0.01 and ny >= top:
                    xs = range(int((x - BW / 2) // T), int((x + BW / 2 - 0.01) // T) + 1)
                    if any(tile(i, j) == '=' or solid(tile(i, j)) for i in xs):
                        landed = top; break
            if landed is not None:
                if hazard(x, landed): return None
                return (x, landed)
            if collide(x, ny):
                return None
        else:
            if collide(x, ny): vy = 0; continue
        y = ny
        if hazard(x, y): return None
    return None

def standing(x, y):
    j = int(y // T)
    xs = range(int((x - BW / 2) // T), int((x + BW / 2 - 0.01) // T) + 1)
    return any(tile(i, j) == '=' or solid(tile(i, j)) for i in xs) and not collide(x, y)

def reach(start, wings):
    seen = {}; q = deque([start]); key = lambda p: (int(p[0] // T), int(p[1] // T))
    seen[key(start)] = start
    plans = []
    for d in (-1, 0, 1):
        plans.append(([(999, d)], True, None))
        plans.append(([(999, d)], False, None))
        for k in (4, 10, 20):
            plans.append(([(k, 0), (999, d)], True, None))
            plans.append(([(k, d), (999, 0)], True, None))
        if wings:
            for fl in (14, 20, 26):
                plans.append(([(999, d)], True, fl))
                plans.append(([(fl, 0), (999, d)], True, fl))
    while q:
        x, y = q.popleft()
        tx = int(x // T)
        starts = {x}
        for sx in (tx * T + 4, tx * T + 8, tx * T + 12):
            if standing(sx, y): starts.add(sx)
        for sx in starts:
            for dirs, jump, fl in plans:
                r = sim(sx, y, dirs, jump, fl)
                if r and key(r) not in seen:
                    seen[key(r)] = r; q.append(r)
            # walk along the floor
            for d in (-1, 1):
                nx = sx + d * T
                if standing(nx, y) and key((nx, y)) not in seen and not hazard(nx, y):
                    seen[key((nx, y))] = (nx, y); q.append((nx, y))
    return seen

def got(seen, mark):
    out = []
    for gx, gy in marks.get(mark, []):
        if any(abs(k[0] - gx) <= 1 and k[1] == gy + 1 for k in seen):
            out.append(True)
        else:
            out.append(False)
    return all(out) if out else None

start = (40.0, 9 * T * 1.0)
no = reach(start, False)
yes = reach(start, True)
checks = [
    ("walk into the lair without wings", got(no, 'W:lair'), True),
    ("reach Hollis's lantern without wings", got(no, 'S:shrine'), True),
    ("read the mire journal without wings", got(no, 'J:mire'), True),
    ("NOT reach the chapel without wings", got(no, 'J:gallery'), False),
    ("NOT reach the rim without wings", got(no, 'F:rim'), False),
    ("reach the chapel with wings", got(yes, 'J:gallery'), True),
    ("reach Rowan's flashlight with wings", got(yes, 'F:rim'), True),
    ("reach the fungus heart vessel with wings", got(yes, 'H:fungus'), True),
    ("get back to the lantern from the rim", None, None),
]
fail = 0
for name, val, want in checks:
    if want is None: continue
    ok = val == want
    fail += not ok
    print(("ok   " if ok else "FAIL ") + name + ("" if ok else f" (got {val})"))
# Return trip: from the flashlight back to the shrine lantern with wings.
f = marks['F:rim'][0]
back = reach((f[0] * T + 8.0, (f[1] + 1) * T * 1.0), True)
ok = got(back, 'S:shrine')
print(("ok   " if ok else "FAIL ") + "walk back from the rim to the lantern")
fail += not ok
sys.exit(1 if fail else 0)
