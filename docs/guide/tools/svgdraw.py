"""Draws staves and piano keyboards as SVG strings (no dependencies; clefs and rests use the Apple Symbols font)."""
from music import diatonic, from_diatonic, parse_bars, parse_event, Event

S = 10                      # staff space (px)
HALF = S / 2
INK = '#222'
BLUE = '#2f6fdf'            # highlighted notes; also the right hand
ORANGE = '#d9661f'          # the left hand
GREEN = '#2e9e4f'
GREY = '#777'
RH, LH = BLUE, ORANGE
SYMBOLS = "'Apple Symbols'"
TEXT = "Georgia, serif"

# Staff geometry: top line y; bottom line note (pos 0); staves are 4 spaces apart in a grand staff.
BOTTOM = {'treble': 'E4', 'bass': 'G2'}


class Canvas:
    def __init__(self):
        self.parts = []
        self.x0, self.y0, self.x1, self.y1 = 1e9, 1e9, -1e9, -1e9

    def grow(self, x0, y0, x1, y1):
        self.x0, self.y0 = min(self.x0, x0), min(self.y0, y0)
        self.x1, self.y1 = max(self.x1, x1), max(self.y1, y1)

    def line(self, x0, y0, x1, y1, w=1.0, color=INK, cap='butt'):
        self.parts.append(f'<line x1="{x0:.1f}" y1="{y0:.1f}" x2="{x1:.1f}" y2="{y1:.1f}" '
                          f'stroke="{color}" stroke-width="{w}" stroke-linecap="{cap}"/>')
        self.grow(min(x0, x1), min(y0, y1), max(x0, x1), max(y0, y1))

    def rect(self, x, y, w, h, fill=INK, stroke='none', sw=1.0, r=0):
        self.parts.append(f'<rect x="{x:.1f}" y="{y:.1f}" width="{w:.1f}" height="{h:.1f}" rx="{r}" '
                          f'fill="{fill}" stroke="{stroke}" stroke-width="{sw}"/>')
        self.grow(x, y, x + w, y + h)

    def text(self, x, y, s, size=12, color=INK, anchor='middle', font=TEXT, weight='normal', style='normal'):
        s = s.replace('&', '&amp;').replace('<', '&lt;')
        self.parts.append(f'<text x="{x:.1f}" y="{y:.1f}" font-family="{font}" font-size="{size}" fill="{color}" '
                          f'text-anchor="{anchor}" font-weight="{weight}" font-style="{style}">{s}</text>')
        w = len(s) * size * 0.55
        left = x - (w / 2 if anchor == 'middle' else w if anchor == 'end' else 0)
        self.grow(left, y - size, left + w, y + size * 0.3)

    def raw(self, s, box):
        self.parts.append(s)
        self.grow(*box)

    def svg(self, pad=6, width=None):
        x0, y0 = self.x0 - pad, self.y0 - pad
        w, h = self.x1 - self.x0 + 2 * pad, self.y1 - self.y0 + 2 * pad
        return (f'<svg xmlns="http://www.w3.org/2000/svg" viewBox="{x0:.1f} {y0:.1f} {w:.1f} {h:.1f}" '
                f'width="{width or w:.0f}" height="{(width or w) * h / w:.0f}">'
                + ''.join(self.parts) + '</svg>')


# ---------------------------------------------------------------- staff

def head(c, x, y, length, color):
    hollow = length >= 2
    rx = 7.2 if length >= 4 else 6.0
    fill, stroke = ('white', color) if hollow else (color, color)
    sw = 1.8 if hollow else 0.8
    c.raw(f'<ellipse cx="{x:.1f}" cy="{y:.1f}" rx="{rx}" ry="4.3" transform="rotate(-20 {x:.1f} {y:.1f})" '
          f'fill="{fill}" stroke="{stroke}" stroke-width="{sw}"/>', (x - rx, y - 5, x + rx, y + 5))
    if length in (1.5, 3, 0.75):
        c.raw(f'<circle cx="{x + 11:.1f}" cy="{y - (2.5 if (y % S) < 1 else 0):.1f}" r="1.8" fill="{color}"/>',
              (x, y - 3, x + 14, y + 3))


def sharp(c, x, y, color=INK):
    for dx in (-2.2, 2.2):
        c.line(x + dx, y - 9, x + dx, y + 9, 1.1, color)
    for dy in (-3, 3):
        c.line(x - 5, y + dy + 1.6, x + 5, y + dy - 1.6, 2.6, color)


def flat(c, x, y, color=INK):
    c.line(x - 3, y - 13, x - 3, y + 4, 1.2, color)
    c.raw(f'<path d="M{x - 3:.1f},{y - 1:.1f} C{x + 3:.1f},{y - 6:.1f} {x + 7:.1f},{y:.1f} {x - 3:.1f},{y + 4:.1f}" '
          f'fill="none" stroke="{color}" stroke-width="1.6"/>', (x - 4, y - 13, x + 6, y + 5))


def clef(c, kind, x, top):
    if kind == 'treble':
        c.text(x, top + 48, '\U0001D11E', 100, font=SYMBOLS, anchor='start')
    else:
        c.text(x + 2, top + 31, '\U0001D122', 51, font=SYMBOLS, anchor='start')


def rest(c, x, top, length):
    if length >= 4:
        c.rect(x - 5, top + S, 10, 5)
    elif length >= 2:
        c.rect(x - 5, top + 2 * S - 5, 10, 5)
    else:
        y = top + 6
        c.raw(f'<path d="M{x - 3:.1f},{y:.1f} l6,8 l-5,6 l6,8 c-5,-3 -9,0 -4,7" fill="none" stroke="{INK}" '
              f'stroke-width="2.4" stroke-linejoin="round"/>', (x - 6, y, x + 6, y + 30))


def draw_staff_music(staves, hands, time=None, bars=True, names=False, fingers=True, beat_w=30, even=False,
                     colors=None, name_color=GREY, clefs=True, first_bar_number=None, captions=None, final=True,
                     stagger=False):
    """staves: ['treble'] / ['bass'] / ['treble', 'bass'].
    hands: {staff: list of bar strings}. With even=True the notes are spread evenly (one slot per event) and
    there are no bar lines: good for teaching rows of notes. colors: {staff: color} for non-highlighted notes.
    captions: {staff: list of texts, one per event} written under (or over) each note instead of the name."""
    c = Canvas()
    colors = colors or {}
    num = time[0] if time else 4
    tops = {'treble': 0, 'bass': 0} if len(staves) == 1 else {'treble': 0, 'bass': 8 * S}
    bottom_y = {s: tops[s] + 4 * S for s in staves}

    def y_of(staff, name):
        return bottom_y[staff] - (diatonic(name) - diatonic(BOTTOM[staff])) * HALF

    # parse
    parsed = {}
    for staff in staves:
        if even:
            evs, b = [], 0.0
            for token in ' '.join(hands[staff]).split():
                if token == 's':                 # invisible spacer: one empty slot
                    evs.append(Event(b, 1, None))
                else:
                    notes, length = parse_event(token)
                    evs.append(Event(b, length, notes))
                b += 1
            parsed[staff] = evs
        else:
            parsed[staff] = parse_bars(hands[staff], num)
    total = max((e.beat + (1 if even else e.length)) for evs in parsed.values() for e in evs)

    x = 4
    if clefs:
        for staff in staves:
            clef(c, staff, x, tops[staff])
        x += 48
    if time:
        for staff in staves:
            for i, d in enumerate(time):
                c.text(x + 9, tops[staff] + 17 + i * 20, str(d), 22, weight='bold')
        x += 26
    start = x
    pad_l, pad_r = 16, 8
    bar_w = num * beat_w + pad_l + pad_r

    def x_of(beat):
        if even:
            return start + pad_l + beat * beat_w
        bar, off = divmod(beat, num)
        return start + int(bar) * bar_w + pad_l + off * beat_w

    end = x_of(total - 1) + beat_w - 4 if even else start + (int(round(total / num))) * bar_w

    # annotation rows (finger numbers and names), kept clear of the notes
    rows = {}
    for staff in staves:
        ys = [y_of(staff, n.name) for e in parsed[staff] for n in e.notes or []]
        above = staff == 'treble'
        if above:
            rows[staff] = (min([tops[staff]] + ys) - 14, -1)
        else:
            rows[staff] = (max([bottom_y[staff]] + ys) + 22, 1)

    for staff in staves:
        top = tops[staff]
        for i in range(5):
            c.line(start - (52 if clefs else 0) - (26 if time else 0), top + i * S, end, top + i * S, 1.0)
        base_color = colors.get(staff, INK)
        row_y, direction = rows[staff]
        low = max([bottom_y[staff]] + [y_of(staff, n.name) for e in parsed[staff] for n in e.notes or []])
        name_side_y = (max(bottom_y[staff] + 26, low + 20) if len(staves) == 1 or staff == 'bass' else None)
        evs = parsed[staff]
        for idx, e in enumerate(evs):
            nx = x_of(e.beat)
            if e.notes is None:
                continue
            if not e.notes:
                rest(c, nx, top, e.length)
                continue
            ys = []
            for n in e.notes:
                y = y_of(staff, n.name)
                ys.append(y)
                col = BLUE if n.mark else base_color
                pos = (diatonic(n.name) - diatonic(BOTTOM[staff]))
                # ledger lines
                for p in list(range(-2, pos - 1, -2)) + list(range(10, pos + 1, 2)):
                    ly = bottom_y[staff] - p * HALF
                    c.line(nx - 10, ly, nx + 10, ly, 1.2)
                if '#' in n.name:
                    sharp(c, nx - 15, y, col)
                elif n.name[1:-1] == 'b':
                    flat(c, nx - 14, y, col)
                head(c, nx, y, e.length, col)
            stem_end = None
            # stem
            if e.length < 4:
                col = BLUE if any(n.mark for n in e.notes) else base_color
                mid = sum(ys) / len(ys)
                if mid > top + 2 * S:      # below the middle line: stem up
                    c.line(nx + 5.6, max(ys), nx + 5.6, min(ys) - 33, 1.3, col)
                    stem_end = min(ys) - 33
                    if e.length <= 0.5:
                        fy = min(ys) - 33
                        c.raw(f'<path d="M{nx + 5.6:.1f},{fy:.1f} c2,8 12,10 8,22" fill="none" stroke="{col}" '
                              f'stroke-width="2.2"/>', (nx, fy, nx + 16, fy + 24))
                else:
                    c.line(nx - 5.6, min(ys), nx - 5.6, max(ys) + 33, 1.3, col)
                    stem_end = max(ys) + 33
                    if e.length <= 0.5:
                        fy = max(ys) + 33
                        c.raw(f'<path d="M{nx - 5.6:.1f},{fy:.1f} c2,-8 12,-10 8,-22" fill="none" stroke="{col}" '
                              f'stroke-width="2.2"/>', (nx - 6, fy - 24, nx + 10, fy))
            # finger numbers, stacked for chords (lowest note nearest the staff for the left hand)
            if fingers:
                fs = [n for n in sorted(e.notes, key=lambda n: diatonic(n.name), reverse=(direction < 0)) if n.finger]
                for k, n in enumerate(fs):
                    col = BLUE if n.mark else base_color
                    if direction < 0:
                        fy = min([top, min(ys) - 4] + ([stem_end] if stem_end is not None and stem_end < min(ys) else [])) - 8
                    else:
                        fy = max([bottom_y[staff], max(ys) + 4] + ([stem_end] if stem_end is not None and stem_end > max(ys) else [])) + 18
                    c.text(nx, fy + direction * k * 14, str(n.finger), 13, col, weight='bold')
            if captions and staff in captions:
                text = captions[staff][idx]
                if text:
                    ty = (name_side_y if name_side_y else row_y - 4) + (16 if fingers and direction > 0 and
                                                                        any(n.finger for n in e.notes) else 0)
                    if stagger and idx % 2:          # alternate rows so long captions don't touch
                        ty += 15 if (name_side_y or direction > 0) else -15
                    c.text(nx, ty, text, 12, name_color, weight='bold')
            elif names:
                label = '+'.join(n.name for n in sorted(e.notes, key=lambda n: -diatonic(n.name)))
                col = BLUE if any(n.mark for n in e.notes) else name_color
                ty = name_side_y if name_side_y else row_y - (16 if fingers and any(n.finger for n in e.notes) else 0)
                if name_side_y and fingers and direction > 0 and any(n.finger for n in e.notes):
                    ty += 16 * len([n for n in e.notes if n.finger])
                c.text(nx, ty, label, 11, col, weight='bold')

    # bar lines
    sys_top = tops[staves[0]]
    sys_bot = bottom_y[staves[-1]]
    if bars and not even:
        nbars = int(round(total / num))
        for b in range(1, nbars + 1):
            bx = start + b * bar_w
            if b == nbars and final:
                c.line(bx - 4, sys_top, bx - 4, sys_bot, 1.0)
                c.line(bx - 0.5, sys_top, bx - 0.5, sys_bot, 3.0)
            else:
                for staff in staves:
                    c.line(bx, tops[staff], bx, bottom_y[staff], 1.0)
                if len(staves) == 2:
                    c.line(bx, sys_top, bx, sys_bot, 1.0)
            if first_bar_number is not None and b < nbars:
                c.text(bx - 2, sys_top - 6, str(first_bar_number + b), 9, GREY, anchor='end', style='italic')
        if first_bar_number not in (None, 1):
            c.text(start - 4, sys_top - 6, str(first_bar_number), 9, GREY, anchor='end', style='italic')
    if len(staves) == 2:
        c.line(start - (52 if clefs else 0) - (26 if time else 0), sys_top,
               start - (52 if clefs else 0) - (26 if time else 0), sys_bot, 1.5)
    return c


# ---------------------------------------------------------------- keyboard

WK_W, WK_H, BK_W, BK_H = 24, 118, 14, 74
HAS_SHARP = set('CDFGA')


def white_x(name, lo):
    return (diatonic(name) - diatonic(lo)) * WK_W


def key_center(name, lo):
    """x center and a y for labels on that key."""
    base = name[0] + name[-1]
    x = white_x(base, lo)
    if '#' in name:
        return x + WK_W, BK_H - 14
    if name[1:-1] == 'b':
        return x, BK_H - 14
    return x + WK_W / 2, WK_H - 30


def keyboard(lo, hi, labels='white', marks=None, fingers=None, octave=True, brackets=None, arrows=None,
             label_marks_only=False, big_c=False, key_w=None):
    """labels: 'white' (every white key), 'c' (only C keys), or 'none'.
    marks: {note: color} fills keys. fingers: {note: (digit, color)} draws numbered circles on keys.
    brackets: [(from_note, to_note, text, color, level)] drawn above the keys.
    arrows: [(from_note, to_note, text, color)] arcs above the keys."""
    c = Canvas()
    marks, fingers = marks or {}, fingers or {}
    d0, d1 = diatonic(lo), diatonic(hi)
    for d in range(d0, d1 + 1):
        n = from_diatonic(d)
        x = (d - d0) * WK_W
        fill = marks.get(n, 'white')
        c.rect(x, 0, WK_W, WK_H, fill=fill, stroke='#333', sw=1.0, r=2)
        show = labels == 'white' or (labels == 'c' and n[0] == 'C')
        if label_marks_only:
            show = n in marks or n in fingers
        if show:
            text = n if octave else n[0]
            col = 'white' if fill not in ('white',) and fill.lower() not in ('#fff', '#ffffff') and \
                fill.lower() not in LIGHT else INK
            size = 11 if not (big_c and n == 'C4') else 12
            c.text(x + WK_W / 2, WK_H - 8, text, size if octave else 13, col, weight='bold')
    for d in range(d0, d1):
        n = from_diatonic(d)
        if n[0] in HAS_SHARP:
            sn = n[0] + '#' + n[-1]
            x = (d - d0 + 1) * WK_W - BK_W / 2
            c.rect(x, 0, BK_W, BK_H, fill=marks.get(sn, '#1b1b1b'), stroke='#111', sw=1.0, r=2)
    for n, (digit, color) in fingers.items():
        cx, cy = key_center(n, lo)
        if '#' not in n:
            cy = WK_H - 34 if labels != 'none' else WK_H - 22
        c.raw(f'<circle cx="{cx:.1f}" cy="{cy:.1f}" r="8.5" fill="{color}" stroke="white" stroke-width="1.5"/>',
              (cx - 9, cy - 9, cx + 9, cy + 9))
        c.text(cx, cy + 4.5, str(digit), 12.5, 'white', weight='bold')
    for (a, b, text, color, level) in brackets or []:
        xa = key_center(a, lo)[0] - (WK_W / 2 - 3 if '#' not in a else BK_W / 2)
        xb = key_center(b, lo)[0] + (WK_W / 2 - 3 if '#' not in b else BK_W / 2)
        y = -10 - level * 26
        c.line(xa, y + 6, xa, y, 1.6, color)
        c.line(xa, y, xb, y, 1.6, color)
        c.line(xb, y, xb, y + 6, 1.6, color)
        c.text((xa + xb) / 2, y - 5, text, 12, color, weight='bold')
    for arrow in arrows or []:
        a, b, text, color = arrow[:4]
        xa, xb = key_center(a, lo)[0], key_center(b, lo)[0]
        h = 26 + abs(xb - xa) * 0.12 + (arrow[4] if len(arrow) > 4 else 0)
        y = -6
        mx = (xa + xb) / 2
        c.raw(f'<path d="M{xa:.1f},{y} Q{mx:.1f},{y - 2 * h:.1f} {xb:.1f},{y}" fill="none" stroke="{color}" '
              f'stroke-width="2"/>', (min(xa, xb), y - h - 4, max(xa, xb), y))
        # arrow head at b
        sign = 1 if xb > xa else -1
        c.raw(f'<path d="M{xb:.1f},{y} l{-sign * 9:.1f},-5 l{sign * 2:.1f},-6 z" fill="{color}"/>',
              (xb - 10, y - 12, xb + 10, y))
        c.text(mx, y - h - 6, text, 12, color, weight='bold')
    return c


LIGHT = {'#cfe0ff', '#ffe2cc', '#d6f2dd', '#fff2b3', '#e8e8e8', '#dfe9ff', '#ffe6d5'}


# ---------------------------------------------------------------- hands

def hands():
    """Two hands seen from above (palms down) with finger numbers: thumbs point to each other."""
    c = Canvas()

    def hand(ox, mirror, color, title):
        # finger lengths from thumb outwards; x offsets from palm left
        fingers = [(1, 30, 62), (2, 52, 92), (3, 78, 102), (4, 104, 94), (5, 128, 72)]
        palm_x, palm_w = 22, 128
        for num, fx, length in fingers:
            px = ox + (palm_x + palm_w - (fx - palm_x) - 18 if mirror else fx)
            if num == 1:
                tilt = 22 if mirror else -22
                cx, cy = px + 9, 120
                c.raw(f'<rect x="{px:.1f}" y="{cy - length:.1f}" width="20" height="{length + 14}" rx="10" '
                      f'fill="#f3d9c2" stroke="#b98a68" stroke-width="1.4" '
                      f'transform="rotate({tilt} {cx:.1f} {cy:.1f})"/>', (px - 30, 40, px + 50, 140))
                tx = px + 10 + (14 if mirror else -14)
                ty = 86
            else:
                c.raw(f'<rect x="{px:.1f}" y="{120 - length:.1f}" width="20" height="{length + 10}" rx="10" '
                      f'fill="#f3d9c2" stroke="#b98a68" stroke-width="1.4"/>', (px, 120 - length, px + 20, 130))
                tx, ty = px + 10, 120 - length + 24
            c.raw(f'<circle cx="{tx:.1f}" cy="{ty:.1f}" r="11" fill="{color}"/>', (tx - 11, ty - 11, tx + 11, ty + 11))
            c.text(tx, ty + 5, str(num), 15, 'white', weight='bold')
        c.rect(ox + palm_x, 112, palm_w, 92, fill='#f3d9c2', stroke='#b98a68', sw=1.4, r=26)
        c.text(ox + palm_x + palm_w / 2, 170, title, 16, color, weight='bold')

    hand(0, True, LH, 'Left hand')
    hand(200, False, RH, 'Right hand')
    return c
