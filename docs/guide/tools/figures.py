"""Writes every figure of the guide as SVG into the given folder. Each figure is a small function below;
the name of the function (without fig_) is the file name, so piano-fundamentals.md uses figures/<name>.svg."""
from __future__ import annotations

import sys
from pathlib import Path

from drills import DRILLS
from music import diatonic
from svgdraw import BLUE, GREEN, GREY, INK, LH, ORANGE, RH, draw_staff_music, hands, keyboard

LIGHT_BLUE, LIGHT_ORANGE, LIGHT_GREEN, YELLOW = '#cfe0ff', '#ffe2cc', '#d6f2dd', '#fff2b3'


def fingers_for(notes, digits, color):
    return {n: (d, color) for n, d in zip(notes, digits)}


# ---------------------------------------------------------------- keyboard basics

def fig_kb_groups():
    return keyboard('C3', 'E4', labels='white', octave=False,
                    marks={'C3': LIGHT_BLUE, 'C4': LIGHT_BLUE, 'F3': LIGHT_ORANGE},
                    brackets=[('C#3', 'D#3', 'two black', BLUE, 0),
                              ('F#3', 'A#3', 'three black', ORANGE, 1),
                              ('C#4', 'D#4', 'two black', BLUE, 0)])


def fig_kb_octaves():
    marks = {'C4': BLUE}
    for c in ('C2', 'C3', 'C5', 'C6'):
        marks[c] = LIGHT_BLUE
    return keyboard('C2', 'C6', labels='c', marks=marks,
                    brackets=[('C2', 'B2', 'octave 2', GREY, 0), ('C3', 'B3', 'octave 3', GREY, 0),
                              ('C4', 'B4', 'octave 4', BLUE, 0), ('C5', 'B5', 'octave 5', GREY, 0)])


def fig_hands():
    return hands()


# ---------------------------------------------------------------- staff basics

def fig_treble_ladder():
    return draw_staff_music(['treble'], {'treble': ['C4 D4 E4 F4 G4 A4 B4 C5 D5 E5 F5 G5 A5']},
                            even=True, names=True, fingers=False, beat_w=34)


def fig_bass_ladder():
    return draw_staff_music(['bass'], {'bass': ['E2 F2 G2 A2 B2 C3 D3 E3 F3 G3 A3 B3 C4']},
                            even=True, names=True, fingers=False, beat_w=34)


def fig_treble_lines_spaces():
    return draw_staff_music(['treble'], {'treble': ['E4!:4 G4!:4 B4!:4 D5!:4 F5!:4 F4:4 A4:4 C5:4 E5:4']},
                            even=True, names=True, fingers=False, beat_w=38)


def fig_bass_lines_spaces():
    return draw_staff_music(['bass'], {'bass': ['G2!:4 B2!:4 D3!:4 F3!:4 A3!:4 A2:4 C3:4 E3:4 G3:4']},
                            even=True, names=True, fingers=False, beat_w=38)


def fig_middle_c():
    return draw_staff_music(['treble', 'bass'], {'treble': ['A3:4 B3:4 C4!:4 D4:4 E4:4 s s s s s'],
                                                 'bass': ['s s s s s A3:4 B3:4 C4!:4 D4:4 E4:4']},
                            even=True, names=True, fingers=False, beat_w=40)


# ---------------------------------------------------------------- landmarks

LANDMARKS = [('C2', 'Low C'), ('G2', 'Bass G'), ('C3', 'Bass C'), ('F3', 'Bass F'),
             ('C4', 'Middle C'), ('G4', 'Treble G'), ('C5', 'Treble C'), ('C6', 'High C')]


def fig_landmarks_staff():
    t_tokens, b_tokens, t_caps, b_caps = [], [], [], []
    for n, label in LANDMARKS:
        on_treble = n[-1] >= '4'
        t_tokens.append(f'{n}!:4' if on_treble else 's')
        b_tokens.append('s' if on_treble else f'{n}!:4')
        t_caps.append(label if on_treble else '')
        b_caps.append('' if on_treble else label)
    c = draw_staff_music(['treble', 'bass'], {'treble': [' '.join(t_tokens)], 'bass': [' '.join(b_tokens)]},
                         even=True, fingers=False, beat_w=70, captions={'treble': t_caps, 'bass': b_caps}, stagger=True,
                         name_color=BLUE)
    return c


def fig_landmarks_keys():
    marks = {n: (BLUE if n == 'C4' else LIGHT_BLUE) for n, _ in LANDMARKS}
    return keyboard('C2', 'C6', labels='none', marks=marks,
                    brackets=[(n, n, label, BLUE if n == 'C4' else INK, i % 2) for i, (n, label) in enumerate(LANDMARKS)])


# ---------------------------------------------------------------- intervals

def fig_intervals_staff():
    return draw_staff_music(['treble'], {'treble': ['E4 F4 s E4 G4 s E4 A4 s E4 B4']}, even=True, fingers=False,
                            beat_w=30, captions={'treble': ['', 'step', '', '', 'skip', '', '', '4th', '', '', '5th']},
                            name_color=BLUE)


def fig_intervals_keys():
    return keyboard('C4', 'D5', labels='white', octave=False,
                    marks={'D4': LIGHT_BLUE, 'E4': BLUE, 'A4': LIGHT_GREEN, 'C5': GREEN},
                    arrows=[('D4', 'E4', 'step', BLUE), ('A4', 'C5', 'skip', GREEN)])


# ---------------------------------------------------------------- positions

def position(rh_notes, lh_notes, lo, hi, rh_name, lh_name):
    f = {}
    f.update(fingers_for(lh_notes, [5, 4, 3, 2, 1], LH))
    f.update(fingers_for(rh_notes, [1, 2, 3, 4, 5], RH))
    marks = {n: LIGHT_ORANGE for n in lh_notes}
    marks.update({n: LIGHT_BLUE for n in rh_notes})
    return keyboard(lo, hi, labels='white', fingers=f, marks=marks,
                    brackets=[(lh_notes[0], lh_notes[-1], lh_name, LH, 0), (rh_notes[0], rh_notes[-1], rh_name, RH, 0)])


def fig_pos_c():
    return position(['C4', 'D4', 'E4', 'F4', 'G4'], ['C3', 'D3', 'E3', 'F3', 'G3'], 'C3', 'C5',
                    'right hand: C position', 'left hand: C position')


def fig_pos_middle_c():
    # both thumbs share Middle C: the left hand's 1 sits low on the key, the right hand's 1 above it
    lh, rh = ['F3', 'G3', 'A3', 'B3', 'C4'], ['C4', 'D4', 'E4', 'F4', 'G4']
    f = fingers_for(lh, [5, 4, 3, 2, 1], LH)
    f.update(fingers_for(rh[1:], [2, 3, 4, 5], RH))
    marks = {n: LIGHT_ORANGE for n in lh}
    marks.update({n: LIGHT_BLUE for n in rh[1:]})
    marks['C4'] = '#e8e8e8'
    c = keyboard('C3', 'C5', labels='white', fingers=f, marks=marks,
                 brackets=[('F3', 'C4', 'left hand', LH, 0), ('C4', 'G4', 'right hand', RH, 1)])
    x = (diatonic('C4') - diatonic('C3')) * 24 + 12
    c.raw(f'<circle cx="{x}" cy="62" r="8.5" fill="{RH}" stroke="white" stroke-width="1.5"/>', (x - 9, 53, x + 9, 71))
    c.text(x, 66.5, '1', 12.5, 'white', weight='bold')
    return c


def fig_pos_g():
    return position(['G4', 'A4', 'B4', 'C5', 'D5'], ['G2', 'A2', 'B2', 'C3', 'D3'], 'G2', 'E5',
                    'right hand: G position', 'left hand: G position')


def fig_pos_f():
    return position(['F4', 'G4', 'A4', 'A#4', 'C5'], ['F2', 'G2', 'A2', 'A#2', 'C3'], 'F2', 'D5',
                    'right hand: F position', 'left hand: F position')


def fig_middle_c_staff():
    return draw_staff_music(['treble', 'bass'], {'treble': ['C4/1 D4/2 E4/3 F4/4 G4/5 s s s s s'],
                                                 'bass': ['s s s s s C4/1 B3/2 A3/3 G3/4 F3/5']},
                            even=True, names=True, beat_w=34, colors={'treble': RH, 'bass': LH})


# ---------------------------------------------------------------- finding a position

def fig_fit_phrase():
    return draw_staff_music(['treble'], {'treble': ['E4 D4 C4! D4 E4 G4! E4 D4']}, even=True, fingers=False,
                            beat_w=32, captions={'treble': ['first', '', 'lowest', '', '', 'highest', '', '']},
                            name_color=BLUE)


def fig_fit_keys():
    return keyboard('A3', 'B4', labels='white', marks={'C4': LIGHT_BLUE, 'G4': LIGHT_BLUE, 'E4': YELLOW},
                    fingers=fingers_for(['C4', 'D4', 'E4', 'F4', 'G4'], [1, 2, 3, 4, 5], RH),
                    brackets=[('C4', 'G4', 'lowest C to highest G = C position', BLUE, 0)])


def fig_fit_answer():
    return draw_staff_music(['treble'], {'treble': ['E4/3 D4/2 C4/1 D4/2 E4/3 G4/5 E4/3 D4/2']}, even=True,
                            beat_w=32, colors={'treble': INK})


# ---------------------------------------------------------------- moving

def fig_shift_staff():
    return draw_staff_music(['treble'], {'treble': ['E4 F4 G4:2', 'C4:4', 'G4/1! A4 B4 G4']}, time=(4, 4),
                            beat_w=28, first_bar_number=2)


def fig_shift_keys():
    f = fingers_for(['G4', 'A4', 'B4', 'C5', 'D5'], [1, 2, 3, 4, 5], RH)
    return keyboard('B3', 'E5', labels='white', marks={'C4': LIGHT_BLUE, 'G4': BLUE}, fingers=f,
                    arrows=[('C4', 'G4', 'lift and move the whole hand', GREEN)])


def fig_thumb_under():
    f = fingers_for(['C4', 'D4', 'E4', 'F4', 'G4', 'A4', 'B4', 'C5'], [1, 2, 3, 1, 2, 3, 4, 5], RH)
    return keyboard('B3', 'D5', labels='white', octave=False, fingers=f, marks={'F4': LIGHT_GREEN},
                    arrows=[('C4', 'F4', 'thumb passes under to F', GREEN)])


def fig_cross_over():
    f = fingers_for(['C5', 'B4', 'A4', 'G4', 'F4', 'E4', 'D4', 'C4'], [5, 4, 3, 2, 1, 3, 2, 1], RH)
    return keyboard('B3', 'D5', labels='white', octave=False, fingers=f, marks={'E4': LIGHT_GREEN},
                    arrows=[('A4', 'E4', '3 crosses over the thumb to E', GREEN)])


def fig_extension():
    f = fingers_for(['C4', 'D4', 'E4', 'F4', 'A4'], [1, 2, 3, 4, 5], RH)
    return keyboard('B3', 'C5', labels='white', octave=False, fingers=f, marks={'A4': LIGHT_GREEN},
                    arrows=[('G4', 'A4', 'finger 5 reaches one key further', GREEN)])


# ---------------------------------------------------------------- rhythm

def fig_rhythm():
    return draw_staff_music(['treble'], {'treble': ['B4:4', 'B4:2 B4:2', 'B4 B4 B4 B4', 'B4:.5 B4:.5 B4:.5 B4:.5 B4:2']},
                            time=(4, 4), beat_w=38, fingers=False, name_color=BLUE,
                            captions={'treble': ['4 beats', '2', '2', '1', '1', '1', '1', '½', '½', '½', '½', '2']})


def fig_rests():
    return draw_staff_music(['treble'], {'treble': ['r:4', 'r:2 r:2', 'r r r r']}, time=(4, 4), beat_w=34,
                            fingers=False)


# ---------------------------------------------------------------- the drills, as sheet music

def drill_lines(drill, bars_per_line=4):
    hands_ = {}
    if drill.get('right'):
        hands_['treble'] = drill['right']
    if drill.get('left'):
        hands_['bass'] = drill['left']
    staves = [s for s in ('treble', 'bass') if s in hands_]
    n = len(next(iter(hands_.values())))
    out = []
    for i in range(0, n, bars_per_line):
        part = {s: hands_[s][i:i + bars_per_line] for s in staves}
        out.append(draw_staff_music(staves, part, time=drill['time'] if i == 0 else None, beat_w=27,
                                    first_bar_number=i + 1, colors={'treble': INK, 'bass': INK},
                                    final=i + bars_per_line >= n))
    return out


def main(folder: Path):
    folder.mkdir(parents=True, exist_ok=True)
    count = 0
    for name, fn in list(globals().items()):
        if name.startswith('fig_'):
            (folder / f'{name[4:]}.svg').write_text(fn().svg(), encoding='utf-8')
            count += 1
    for k, d in enumerate(DRILLS, 1):
        for j, c in enumerate(drill_lines(d), 1):
            (folder / f'drill{k}-{j}.svg').write_text(c.svg(), encoding='utf-8')
            count += 1
    print(f'wrote {count} figures to {folder}')


if __name__ == '__main__':
    main(Path(sys.argv[1]))
