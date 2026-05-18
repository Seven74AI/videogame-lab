# PLAYTEST Checklist — Videogame Lab

> **Mandatory before marking any game-dev ticket as DONE.**
> Static code review is not enough. The game must launch and run.

## Pre-Playtest (before launching Godot)

- [ ] `scripts/ci-validate.sh` passes (headless Godot loads project without errors)
- [ ] `project.godot` has `run/main_scene` set
- [ ] All `.gd` scripts compile (no parse errors in Godot output)
- [ ] All `.tscn` scenes reference valid scripts and resources

## Launch Check

- [ ] Game window opens at target resolution (check `project.godot` display settings)
- [ ] No errors in Godot Output panel on first frame
- [ ] Main scene / menu appears correctly

## Core Loop (5-minute minimum)

- [ ] Player can perform primary action(s) without crash
- [ ] Game state updates correctly (score, HP, resources, etc.)
- [ ] No softlocks — every game state has a path forward
- [ ] Game can be reset / restarted without leaking state

## Edge Cases

- [ ] Rapid input spam does not crash or glitch
- [ ] Window resize / minimize / restore does not break rendering
- [ ] Pause (if implemented) freezes and resumes correctly
- [ ] Empty state / game-over state renders correctly

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
|            |            |           |                     |       |

---

**Rule:** If *any* item fails, the ticket is NOT done. Fix the issue and re-test.
