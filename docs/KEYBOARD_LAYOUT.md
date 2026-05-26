# Eyelash Corne Layout Description

Split columnar-stagger keyboard. 3x6 grid + 3 thumb keys per side. Volume encoder (left, inner bottom), 4-way joystick + push button (right, inner bottom). Gallium alpha layout, not QWERTY.

## Physical Geometry

```
╭──────────────────────────────╮  ╭──────────────────────────────╮
│ pinky ring mid  idx  idx inner│  │inner idx  idx  mid  ring pinky│
│ LT5  LT4  LT3  LT2  LT1  LT0│  │RT0  RT1  RT2  RT3  RT4  RT5 │
│ LM5  LM4  LM3  LM2  LM1  LM0│  │RM0  RM1  RM2  RM3  RM4  RM5 │
│ LB5  LB4  LB3  LB2  LB1  LB0│  │RB0  RB1  RB2  RB3  RB4  RB5 │
╰────────────╮ LH2  LH1  LH0  │  │ RH0  RH1  RH2 ╭─────────────╯
             ╰─────[ENC]───────┘  └───[JOY]────────╯
```

Reachability (best to worst): thumb keys > home row index/middle > home row ring > top row index/middle > bottom row index/middle > inner column (stretch) > outer column (pinky).

## Layer 0: Base (Gallium)

```
  `/HYP  b  l  d  c  v          j  y  o  u  ,   \/HYP
 Esc/MEH n  r  t  s  g          p  h  a  e  i   //MEH
Cmp/SFT  x  q  m  w  z          k  f  '  ;  .  Ret/SFT
           Fn/Esc NUM/Spc Ctl/Tab    NAV/SK⇧ BS/⇧ &toDEF
```

Encoder: volume up/down (rotate). Joystick: arrow keys + Return (push).

### Home Row Mods (bilateral, balanced flavor, 190ms tapping-term)

Left home row: n=Ctrl, r=Alt, t=Meta, s=Shift.
Right home row: h=Shift, a=Meta, e=Alt, i=Ctrl.
Trigger only on opposite-hand keypress (hold-trigger-key-positions).

### Outer Column Hold-Taps

| Key | Tap | Hold |
|-----|-----|------|
| LT5 | ` | Hyper (Ctrl+Shift+Meta+Alt) |
| LM5 | Esc | Meh (Ctrl+Alt+Shift) |
| LB5 | Compose | Shift |
| RT5 | \ | Hyper |
| RM5 | / | Meh |
| RB5 | Return | Shift |

### Thumb Keys

| Key | Tap | Hold |
|-----|-----|------|
| LH2 | Esc | FN layer |
| LH1 | Space | NUM layer |
| LH0 | Tab | Ctrl |
| RH0 | Sticky Shift | NAV layer |
| RH1 | Backspace | Shift |
| RH2 | &to DEF (reset to base) | — |

RH0 detail: hold = NAV layer, tap = one-shot Shift (160ms tapping-term).
RH1 detail: hold = Shift, tap = Backspace (quick-tap 160ms for repeat).

## Layer 2: NUM (left thumb hold LH1)

```
  `  !  @  #  $  %          ^  &  *  _  +  |
 Esc 1  2  3  4  5          6  7  8  9  0  /
  CW ~  -  =  {  [          ]  }  "  :  .  Ret
          Tab Spc ___       ___ ___ .
```

CW = caps_word. Joystick becomes mouse movement; encoder = PgDn/PgUp.
Full symbols row 1, digits row 2, paired brackets row 3.

## Layer 3: NAV (right thumb hold RH0)

```
  `  -  -  -  -  -          -  Home PgDn PgUp End  →GAM
 Esc Ctl Alt Meta ⇧  -     -  ←    ↓    ↑    →    Del
  -  Undo Cut Copy Paste Redo  -  -    -    -    -  Ins
          &moFN Spc ___     -  BS  ___
```

Left hand: explicit mod keys on home row (for one-hand mod+arrow). Edit keys on bottom row.
Joystick: scroll wheel (up/down/left/right) + click.
Mouse speed: warp (3x normal). LH2 activates FN for precision (0.5x).

## Layer 4: FN (left thumb hold LH2)

```
 Menu PrtSc Pause Ins Del Cancel   -  -  -  F11 F12  -
  -   F1    F2    F3  F4  F5       F6 F7 F8 F9  F10  -
 Clr  Undo  Cut   Copy Paste Redo  -  -  -  -   -    -
            ___   ___  ___         &moNAV ___ ___
```

RH0 = &mo NAV → holding both FN + NAV activates SYS (conditional layer).
Encoder: RGB brightness.
Mouse speed: precision (0.5x normal).

## Layer 5: SYS (FN + NAV held simultaneously)

BT channel select (0–4), BT disconnect, BT/USB output toggle, RGB controls, power/sleep/reset/bootloader, ZMK studio unlock.

## Combos (horizontal adjacent pairs, 20ms term)

All combos on DEF (some also NUM). Fast idle requirement prevents misfires during typing.

### Left Hand

| Keys | Output | Row |
|------|--------|-----|
| LT4+LT3 | < | top |
| LT3+LT2 | ( | top |
| LT2+LT1 | ) | top |
| LT1+LT0 | > | top |
| LM4+LM3 | CapsWord | home |
| LM3+LM2 | - | home |
| LM2+LM1 | = | home |
| LM1+LM0 | _ | home |
| LB4+LB3 | { | bottom |
| LB3+LB2 | [ | bottom |
| LB2+LB1 | ] | bottom |
| LB1+LB0 | } | bottom |

Pattern: brackets/grouping symbols fan outward from center. Home row combos also produce mod chords when held (HRM-combo hack).

### Right Hand

| Keys | Output | Row |
|------|--------|-----|
| RM0+RM1 | Leader key | home |
| RM1+RM2 | Alt+Backspace (delete word) | home |
| RM2+RM3 | Ctrl+Backspace (delete word) | home |
| RM3+RM4 | Delete | home |
| RB2+RB3 | Enter | bottom |

### Media Combos (vertical adjacent pairs)

| Keys | Output |
|------|--------|
| RM1+RT2 | Vol Up |
| RM3+RT2 | Vol Down |
| RT0+RT1 | Play/Pause |
| RM0+RT1 | Prev Track |
| RM4+RT3 | Next Track |

## Leader Sequences (activated via RM0+RM1 combo)

| Sequence | Action |
|----------|--------|
| U S B | Switch to USB output |
| B L E | Switch to BLE output |
| R E S E T | System reset |
| B O O T | Enter bootloader |

## Layer 1: Gaming

QWERTY alpha, adjusted for columnar stagger (WASD at ESDF physical position). No home row mods. Left thumb: Alt (tap-dance to NUM), Space, Ctrl. Right side: normal. Encoder: volume.

## Timing Parameters

| Parameter | Value |
|-----------|-------|
| HRM tapping-term | 190ms |
| HRM quick-tap | 190ms |
| HRM require-prior-idle | 190ms |
| Thumb hold tapping-term | 160ms (short) |
| Thumb quick-tap | 160ms (short, 120 for NAV) |
| Sticky key release | 900ms |
| Combo term (fast) | 20ms |
| Combo idle (fast) | 20ms |
| lt/mt tapping-term | 190ms |
| lt/mt quick-tap | 160ms |
