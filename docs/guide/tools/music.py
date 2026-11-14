"""Small shared music helpers for the guide: note names, and the bar text format used by the drills.

Bar text: events separated by spaces. An event is `notes:beats` (beats default 1), where notes is `r` (rest) or
notes joined by `+` (a chord). Each note is `Name[/finger][!]`, e.g. `C4/1`, `F#4`, `G3/5!`.
`!` highlights the note (blue) in figures. Finger numbers are optional.
"""
from __future__ import annotations

from dataclasses import dataclass, field

STEP = {'C': 0, 'D': 2, 'E': 4, 'F': 5, 'G': 7, 'A': 9, 'B': 11}
LETTERS = 'CDEFGAB'


def midi(name: str) -> int:
    acc = name[1:-1]
    return 12 * (int(name[-1]) + 1) + STEP[name[0]] + (-1 if acc == 'b' else 1 if acc == '#' else 0)


def diatonic(name: str) -> int:
    """White-key number: C4 = 28, D4 = 29, ... (accidentals ignored)."""
    return int(name[-1]) * 7 + LETTERS.index(name[0])


def from_diatonic(d: int) -> str:
    return f'{LETTERS[d % 7]}{d // 7}'


@dataclass
class Note:
    name: str
    finger: int | None = None
    mark: bool = False


@dataclass
class Event:
    beat: float            # start, in beats from the start of the piece
    length: float
    notes: list = field(default_factory=list)   # empty = rest


def parse_event(token: str):
    spec, _, length = token.partition(':')
    length = float(length) if length else 1.0
    notes = []
    if spec != 'r':
        for tok in spec.split('+'):
            mark = tok.endswith('!')
            name, _, finger = tok.rstrip('!').partition('/')
            notes.append(Note(name, int(finger) if finger else None, mark))
    return notes, length


def parse_bars(bars: list[str], beats_per_bar: int) -> list[Event]:
    """All bars of one hand -> events with absolute beats. Checks each bar adds up."""
    events, beat = [], 0.0
    for i, bar in enumerate(bars):
        start = beat
        for token in bar.split():
            notes, length = parse_event(token)
            events.append(Event(beat, length, notes))
            beat += length
        assert abs(beat - start - beats_per_bar) < 1e-9, f'bar {i + 1} has {beat - start} beats: {bar!r}'
    return events
