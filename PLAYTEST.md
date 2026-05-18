# PLAYTEST Checklist — Videogame Lab

> **Mandatory before marking any game-dev ticket as DONE.**
> Static code review is not enough. The game must launch and run.

## Pre-Playtest (before launching Godot)

- [ ] `scripts/ci-validate.sh` passes (headless Godot loads project without errors)
- [ ] `GODOT_SILENCE_ROOT_WARNING=1 godot4 --headless --path deep-root-proto res://tests/test.tscn` — all 49 tests pass
- [ ] `project.godot` has `run/main_scene` set
- [ ] All `.gd` scripts compile (no parse errors in Godot output)
- [ ] All `.tscn` scenes reference valid scripts and resources

## Launch Check

- [ ] Game window opens at target resolution (check `project.godot` display settings)
- [ ] No errors in Godot Output panel on first frame
- [ ] Grid renders with TileMapLayer (60x40 grid visible)
- [ ] HUD renders with Control nodes (GP, resources, rivals, trees visible)

## Core Loop (5-minute minimum)

- [ ] Player can grow mycelium with arrow keys
- [ ] Player can trade minerals for sugars with keys 1/2/3
- [ ] Player can click empty cell to grow
- [ ] Player can click tree to select it
- [ ] 3 rival AIs expand with distinct personalities (Red aggressive, Orange defensive, Violet opportunistic)
- [ ] Resources (water, minerals, sugar) are absorbed on growth
- [ ] Trees have 6 trades each, cooldown between trades
- [ ] Game state updates correctly (GP, resources, territory %)
- [ ] R key resets the game cleanly

## Edge Cases

- [ ] Rapid input spam does not crash or glitch
- [ ] Window resize / minimize / restore does not break rendering
- [ ] Empty tree (0 trades left) rejects trades with message
- [ ] Insufficient minerals blocks trade with message
- [ ] Out-of-bounds click does not crash

## Performance

- [ ] Framerate stays stable at target (no sustained drops below 30 FPS)
- [ ] No visible stutter or hitching during normal gameplay
- [ ] Memory usage does not grow unbounded over 5+ minutes (no leak)

## Audio

- [ ] All sound effects play at correct timing and volume
- [ ] No audio clipping, distortion, or missing sounds
- [ ] Music loops cleanly (if implemented)

## Exit Check

- [ ] Game closes cleanly (no hanging process, no crash on exit)
- [ ] Godot Output panel has no ERROR lines during entire session

## Sign-off

| Date       | Tester     | Ticket ID | Result (PASS/FAIL) | Notes |
|------------|------------|-----------|---------------------|-------|
| 2026-05-18 | coder      | t_d7bc47e3 | CI PASS / 49 tests PASS | Proto v3 refactored: TileMap + Control UI + AStarGrid2D + auto-loads + shader + save system |

---

**Rule:** If *any* item fails, the ticket is NOT done. Fix the issue and re-test.
