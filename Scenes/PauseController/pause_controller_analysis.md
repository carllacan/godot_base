# Pause controller analysis (2026-07-13)

Analysis of `pause_controller.gd` (autoload `Pause`): what it implements, what each
feature is for, how the two finished projects (hexis, core_defender proto1) handled
pausing, and what to simplify or expand.

Note: this file sits in the GodotBase submodule, but the usage analysis below is
specific to **bingomental** (with core_defender as comparison, since the controller
originated there — "Initial commit, including lots of code used in Coreward").

## TL;DR

The accumulator design is sound and worth keeping — hexis shows what the hand-rolled
alternative looks like, and it's worse. But about half of the controller is dead or
unwired in bingomental: `can_pause` does literally nothing, and `paused_externally`
(the controller-disconnect feature this was built around) fires into the void because
nothing listens to it. The controller-disconnect scenario never needed the
accumulator; the accumulator solves a different problem (overlapping pause causes
fighting over a single boolean). Simplify the dead parts, wire or delete the
external-pause signal, and the ~60 lines that remain are justified.

## Features and their current status

1. **Pause-source accumulation** (`pause_sources`, `add/remove_pause_source`,
   `must_pause`) — the tree pauses while *any* source is registered and unpauses only
   when all are gone. **In actual use, but degenerately**: in bingomental only two
   sources ever exist — `WindowsLayer` (any open window pauses the game, see
   `GodotBase/Scenes/WindowsLayer/windows_layer.gd`) and the controller itself via
   the hotkey. Since windows close each other (`close_all_but`), in practice there is
   almost always exactly one source.

2. **`can_pause` flag** — **completely dead code**. The `# TODO: wtf is this for` is
   answered: nothing. The setter calls `update_pause_state()`, but
   `update_pause_state()` never reads `can_pause`, and nothing else does either — in
   bingomental *or* core_defender. WindowsLayer writes it; core_defender's `game.gd`
   writes it during state transitions (apparent intent: "can't pause during
   transitions") — but it was never hooked into any check.

3. **`paused_externally` signal** — a *request* signal (misleading name — it pauses
   nothing itself). Emitted on joypad disconnect
   (`GodotBase/Autoloads/input_manager.gd`) and Steam overlay open
   (`GodotBase/Integration/steam_integration_controller.gd`). **In bingomental
   nothing connects to it** — the controller-disconnect pause is currently not
   functional in this game. In core_defender it *is* wired: `Game/game.gd` connects
   it to `_on_pause_game_requested`, which opens the pause menu window only if
   `state == PLAYING`.

4. **`toggle_pause` hotkey** — bound to Ctrl+Shift+P, pauses the raw tree with itself
   as source, **without any UI appearing**. Reads as a debug feature; on a reachable
   key the player would see the game freeze with no indication why. (In
   core_defender this handler is commented out.)

5. **`force_unpaused()`** — clears all sources at once. Used by the pause menu's
   Reset/Quit (`Game/GUI/PauseMenu/pause_menu_window.gd`) and by core_defender's
   return-to-main-menu. Exists because sources are object references: when the scene
   holding a source is torn down, the source leaks and the tree stays paused forever
   — exactly the pause-source leak that blocked prestige testing until the
   `_exit_tree` cleanup was added to `windows_layer.gd` (July 2026).

6. **`await get_tree().physics_frame` before (un)pausing** — bingomental-only
   addition (commit "Add frame pause before pausing … to avoid errors";
   core_defender's copy doesn't have it). Introduces a small re-entrancy hazard: two
   state changes in quick succession both suspend at the await and can apply stale
   decisions.

7. **`paused`/`unpaused` signals** — emitted, **zero listeners in either project**.

## How the two finished projects did it

### Hexis (Godot 3) — no pause controller, no tree pause at all

A `paused` bool, `$MoveTimer.paused`, an animation mutex, and a state machine. This
is the instructive one, because it hand-rolls exactly what the accumulator abstracts:

- It needed an `externally_paused` bool so Steam-overlay-deactivate would only
  unpause **if the overlay was what paused it** — a manual two-source accumulator.
  That is the bug class `pause_sources` kills generically: *external cause ends, but
  the player had also paused manually, and the game wrongly resumes*.
- The Steam-overlay-activate handler is disabled (`return` as first line) — it
  apparently caused enough trouble to turn off, while the deactivate handler still
  carries a `print("WAS NOT PAUSED")` debug scar.
- Controller disconnect → `show_pausemenu()`, gated on the state machine (only if
  PLAYING). Same pattern as core_defender; no accumulator needed for it.
- Every pausable thing (timers, animation locks, tutorial yields) had to be paused
  individually — the cost of not using tree pause.

### Core_defender proto1 — same GodotBase controller, one revision older

Its actual working model: *windows pause the game* (WindowsLayer as the only real
pause source), and everything else — pause button, Escape key, Steam overlay,
controller disconnect — just **opens the pause menu window**, which pauses via
WindowsLayer. `force_unpaused()` on return to main menu. `can_pause` written but
dead there too.

## What each feature is realistically for

- **Accumulator**: overlapping pause causes — pause menu open *and* Steam overlay on
  top; tutorial pause plus a window; focus-loss pause while a menu is open. Whenever
  two causes overlap and one ends, a single boolean resumes the game wrongly (the
  hexis bug). If a second *independent* source never appears, it's overkill — but
  it's also small.
- **`paused_externally`**: "something outside the player's intent happened; the game
  should decide whether to bring up the pause menu." Controller disconnect and Steam
  overlay today; window focus loss or mobile backgrounding would be natural future
  emitters. The decision logic (only pause if actually mid-game) correctly lives in
  the game, not the controller.
- **`force_unpaused`**: scene teardown/reset — the escape hatch for the
  object-reference leak.
- **`can_pause`**: intended "pausing is temporarily forbidden" (transitions, game
  over animations). Never implemented.

## Plausible future needs

- **Wire `paused_externally`** — connect it to `show_pause_menu()` in
  `Game/GUI/gui.gd`, same as core_defender. But decide first whether it's wanted:
  for an idle/incremental game, pausing when the Steam overlay opens is arguably
  wrong — progression continuing is the genre's point. Controller disconnect →
  pause menu still makes sense for Steam Deck / controller play.
- **Auto-unregistering sources**: in `add_pause_source`, connect the source's
  `tree_exiting` to `remove_pause_source`. Eliminates the entire leak class (the
  WindowsLayer bug and every future one) and makes `force_unpaused` mostly
  unnecessary. Single highest-value change if the controller stays.
- **Pause vs. saving / idle accounting**: tree pause stops physics-driven nodes, and
  SaveManager is physics-driven — a long-open pause menu means no autosave flushes
  (this already bit once in the frozen-tree incident). Consider flushing a save on
  `paused.emit()` or making SaveManager `PROCESS_MODE_ALWAYS`. Also decide whether
  paused time counts for deadtime/idle accrual — any accrual using wall-clock
  timestamps rather than `_process` delta won't actually stop during tree pause.
- YAGNI: pause priorities/reasons, multi-controller support, resurrecting
  `can_pause`.

## Recommendation

Keep the accumulator core, prune the rest:

- **Delete `can_pause`** and its writes in WindowsLayer — pure noise.
- **Decide on `paused_externally`**: wire it to the pause menu (5 lines, restores
  the feature it was built for) or delete the emissions. The current state —
  half-implemented — is the worst option.
- **Rethink the Ctrl+Shift+P hotkey**: either make it open the pause menu like
  Escape does, or gate it behind `Flags.DEBUG` — a silent tree-freeze is a
  support-ticket generator.
- **Add the `tree_exiting` auto-unregister** — ~2 lines, retires the leak class
  permanently.
- Optionally drop `paused`/`unpaused` until something listens (harmless though, and
  the natural hook for save-on-pause).

That leaves a ~50-line controller where every line is load-bearing, and the
architecture still matches what core_defender shipped with.
