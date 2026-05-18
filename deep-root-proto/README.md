# DEEP ROOT — Proto v2

Mycelium network game — expand, absorb resources, trade with trees, compete against rival fungi.

**Proto v2 changes:** 60×40 grid (2400 cells), 3 rival AIs (Red/Orange/Violet), 3 symbiotic trees, 1280×720 window with canvas_items scaling.

## Quick Start

1. Open `deep-root-proto/` in Godot 4.2+
2. Launch `main.tscn` (F5)
3. Play 5–10 minutes
4. Fill in `RAPPORT.md`

## Controls

| Key | Action |
|-----|--------|
| Arrow keys | Grow mycelium in direction |
| Click empty cell | Grow toward clicked cell |
| `1` `2` `3` | Trade minerals → sugars (rates: 2→1, 5→3, 10→7) |
| Tab | Cycle through trees |
| Click tree | Select tree for trading |
| R | Reset with new random seed |

## Game Rules

- **Grid:** 60×40 cells, 24px each (1440×960 design, scaled to window)
- **Growth:** Costs 5 GP per cell. GP accumulates at 0.3/s base, boosted by +0.07/s per sugar held (cap +0.90/s)
- **Resources:** Water (common, +2GP), Minerals (medium, +3GP), Sugars (rare, +1GP +boost rate)
- **Trees:** 3 trees, each offers 6 trades (minerals → sugars). Trades have 4s cooldown. Must be adjacent to tree to trade.
- **Rivals:** 3 AI competitors with distinct personalities:
  - **Red** (aggressive) — targets player and trees
  - **Orange** (defensive) — maximizes territory
  - **Violet** (opportunistic) — prioritizes sugars

## UI

- Top-left: resource counters, GP, growth rate, rival stats, tree status
- Bottom: controls reminder
- Hover tooltip: cell type
- Green highlight: available growth cells
- Animations: growth pulse (green), rival growth (red/orange/violet), absorption (yellow), trade (gold)

## Files

| File | Lines | Role |
|------|-------|------|
| `main.gd` | ~660 | All game logic, rendering, input, AI |
| `project.godot` | ~95 | Godot 4.2+ config, InputMap bindings, viewport |
| `main.tscn` | 6 | Root scene |
| `README.md` | — | This file |
| `RAPPORT.md` | — | Playtest report template |

## Design Philosophy

- **Minimal:** _draw() rendering, no individual nodes per cell, zero visual polish
- **Proto-only:** No saves, no audio, no procgen, no multiplayer
- **One question:** Is the core loop satisfying? That's all we're testing.
