# Layout Description

The layout below is defined once, in `config/keymap.dtsi`, and shared by every
board. See [Boards](#boards) for how each board maps it onto its own physical
key positions. The reference geometry is the eyelash corne.

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

## Boards

`config/keymap.dtsi` holds all six layers as chunks of bindings. Each board
keymap defines a `KEYMAP_LAYER` macro that arranges those chunks into its own
physical key order, then includes `base.keymap`:

| Argument | Size | Contents |
|----------|------|----------|
| `name` | — | layer name, also the display name |
| `TOP_L` `TOP_R` | 6 + 6 | top row |
| `MID_L` `MID_R` | 6 + 6 | home row |
| `BOT_L` `BOT_R` | 6 + 6 | bottom row |
| `THU_L` `THU_R` | 3 + 3 | thumbs |
| `JS_U` `JS_L` `JS_B` `JS_R` `JS_D` | 5 | 5-way joystick |
| `ENC_B` | 1 | encoder push button |
| `SENSORS` | — | `sensor-bindings` for encoder rotation |

Position labels (`LT0`..`RB5`, `LH0`..`LH2`, `RH0`..`RH2`) come from a
`zmk-helpers/key-labels/` header, so combos and home row mods are written once
against symbolic positions. `config/key_positions.h` derives `KEYS_L`,
`KEYS_R` and `THUMBS` from those labels; the outer pinky column is excluded
because those keys are mod-taps, not home row mods.

Hardware differences are declared by the board keymap as `CONFIG_WIRELESS`,
`CONFIG_RGB` and `CONFIG_EXT_POWER`. `&bt`, `&rgb_ug` and `&ext_power` only
link when the matching Kconfig symbol is set, so `defines.h` degrades their
aliases to `&none` on boards that lack the hardware — that is what makes the
one SYS layer safe to share between a wireless corne and a wired planck.

Board keymaps must **not** include `zmk-helpers/helper.h` themselves: its
`#pragma once` would make `base.keymap`'s later include a no-op, leaving ZMK's
native (unwrapped) `ZMK_MACRO` in force and breaking the devicetree parse.

### eyelash_corne — reference

`zmk-helpers/key-labels/eyelash42.h`. 42 keys plus encoder button (`LEC`) and
joystick (`JS0`..`JS4`), which take the `ENC_B` / `JS_*` arguments directly.

### planck_rev6 — 4x12 ortho

`zmk-helpers/key-labels/4x12.h`, all-1u physical layout, USB only, no RGB, no
switched power rail, no encoder populated (so `SENSORS` is dropped).

```
  0   1   2   3   4   5 │  6   7   8   9  10  11     LT5 .. LT0 │ RT0 .. RT5
 12  13  14  15  16  17 │ 18  19  20  21  22  23     LM5 .. LM0 │ RM0 .. RM5
 24  25  26  27  28  29 │ 30  31  32  33  34  35     LB5 .. LB0 │ RB0 .. RB5
 36  37  38  39  40  41 │ 42  43  44  45  46  47     LH5 LH4 LH3 LH2 LH1 LH0 │ RH0 RH1 RH2 RH3 RH4 RH5
```

Rows 1–3 are key-for-key identical to the corne. The corne's thumbs land on
`LH2 LH1 LH0` / `RH0 RH1 RH2`, i.e. the six inner keys of the bottom row, which
keeps every thumb reach the same.

That leaves six outer bottom-row keys with no corne counterpart. They stand in
for the hardware the planck does not have, so they follow the joystick and
encoder button per layer:

| Position | Argument | DEF | NUM | NAV |
|----------|----------|-----|-----|-----|
| 36 (`LH5`) | `ENC_B` | Play/Pause | — | — |
| 37 (`LH4`) | `JS_U` | ↑ | mouse up | scroll up |
| 38 (`LH3`) | `JS_B` | Return | click | click |
| 45 (`RH3`) | `JS_L` | ← | mouse left | scroll left |
| 46 (`RH4`) | `JS_D` | ↓ | mouse down | scroll down |
| 47 (`RH5`) | `JS_R` | → | mouse right | scroll right |

Provisional: functionally faithful, but the arrow cluster ends up split across
both hands. Reshuffle in `planck_rev6.keymap` — it is one macro line.

To use the planck's optional encoder, set `CONFIG_EC11=y` plus
`CONFIG_EC11_TRIGGER_GLOBAL_THREAD=y` in `planck_rev6.conf`, add an overlay
enabling the `encoder` node, and pass `SENSORS` through in `KEYMAP_LAYER`.

### glove80 — 80 keys

`zmk-helpers/key-labels/glove80.h`, split (`glove80_lh` central, `glove80_rh`
peripheral), wireless, RGB underglow and a switched power rail, no encoder or
joystick (so the last seven `KEYMAP_LAYER` arguments are dropped).

Key positions run 0..79 in this order — note the bottom row is split by the
thumb cluster:

```
  0 ..  9   ceiling row      (5 + 5)
 10 .. 21   number row       (6 + 6)
 22 .. 33   top row          → TOP_L TOP_R
 34 .. 45   home row         → MID_L MID_R
 46 .. 51   left bottom      → BOT_L
 52 .. 57   upper thumbs     (3 + 3)
 58 .. 63   right bottom     → BOT_R
 64 .. 68   left floor row   (5)
 69 .. 74   lower thumbs     → THU_L THU_R
 75 .. 79   right floor row  (5)
```

The corne's 42 keys map straight onto the three alpha rows and the lower thumb
row; the generated devicetree is identical to the corne's on all 42 positions,
on every layer, for both halves. The remaining 38 keys — ceiling row, number
row, upper thumbs, both floor rows — are `&none` on every layer.

Dropping the joystick arguments also drops the arrow cluster (DEF), mouse
cursor (NUM) and scrolling (NAV) that lived on it. There is plenty of dead
real estate to move them to; the floor rows are the obvious candidates.
