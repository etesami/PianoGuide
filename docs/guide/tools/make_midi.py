"""Writes each drill in drills.py as a .mid (track 1 right hand, track 2 left hand; finger numbers as lyric events,
PianoCore's convention) plus its lesson note .md, into the given folder."""
from __future__ import annotations

import struct
import sys
from pathlib import Path

from drills import DRILLS
from music import midi, parse_bars


def vlq(v):
    out = [v & 0x7F]
    v >>= 7
    while v:
        out.insert(0, (v & 0x7F) | 0x80)
        v >>= 7
    return bytes(out)


def meta(kind, data):
    return bytes([0xFF, kind]) + vlq(len(data)) + data


def track(events):
    # same tick: meta first, then note-offs, then lyric + note-on pairs in insertion order (as MIDIFileWriter does)
    order = lambda e: 0 if e[1][0] == 0xFF and e[1][1] != 5 else 1 if e[1][0] == 0x80 else 2
    events = [e for _, e in sorted(enumerate(events), key=lambda x: (x[1][0], order(x[1]), x[0]))]
    body, last = b'', 0
    for tick, data in events:
        body += vlq(tick - last) + data
        last = tick
    body += b'\x00' + meta(0x2F, b'')
    return b'MTrk' + struct.pack('>I', len(body)) + body


def write(drill, path: Path):
    num, den = drill['time']
    tick = lambda beats: int(round(beats * 480))
    tracks = [track([(0, meta(3, drill['file'].encode())),
                     (0, meta(0x51, (60_000_000 // drill['tempo']).to_bytes(3, 'big'))),
                     (0, meta(0x58, bytes([num, den.bit_length() - 1, 24, 8])))])]
    bars = len(drill.get('right') or drill['left'])
    for hand, velocity in (('right', 85), ('left', 60)):
        events = []
        for e in parse_bars(drill.get(hand) or ['r:%d' % num] * bars, num):
            for n in e.notes:
                if n.finger:
                    events.append((tick(e.beat), meta(5, str(n.finger).encode())))
                events.append((tick(e.beat), bytes([0x90, midi(n.name), velocity])))
                events.append((tick(e.beat + e.length * 0.95), bytes([0x80, midi(n.name), 0])))
        tracks.append(track(events))
    path.write_bytes(b'MThd' + struct.pack('>IHHH', 6, 1, len(tracks), 480) + b''.join(tracks))


if __name__ == '__main__':
    out = Path(sys.argv[1])
    out.mkdir(parents=True, exist_ok=True)
    for d in DRILLS:
        write(d, out / f"{d['file']}.mid")
        (out / f"{d['file']}.md").write_text(d['note'], encoding='utf-8')
        print('wrote', out / f"{d['file']}.mid")
