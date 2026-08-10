# Windows system expansion — owned/modal windows (2026-08-10)

Plan for adding parent/child ("owned") windows to `BaseWindow` + `WindowsLayer`, so a
window can open a sub-window (e.g. the pause menu opening a reset confirmation)
without the two fighting over who is open, who is paused, and who gets input.

Note: this file sits in the GodotBase submodule, but the motivating case and the
line references outside `Scenes/WindowsLayer/` are **bingomental**-specific.

## TL;DR

Build it as an **open-window stack** in `WindowsLayer`, not as parent pointers on
`BaseWindow`. `close_all_but` already enforces one window at a time, so the "tree"
is only ever a single chain — a stack expresses that exactly and makes every derived
question ("who is modal?", "who does an outside click test against?", "who handles
Escape?") resolve to *top of stack*. Borrow Godot's `transient`/`exclusive` naming so
the concepts are recognizable. Do **not** make `close()` blockable by children;
cascade it downward instead.

## Decision record: keep the Control-based system, do not migrate to `Window`

Checked against the 4.7.1 class reference (generated locally with `--doctool`, since
there is no Godot source checkout on this machine — descriptions were unavailable, so
only member/method existence is confirmed):

- `Window` inherits `Viewport` inherits `Node`. **It is not a `CanvasItem`** — no
  `modulate`, no `scale`; its spatial API is `position`/`size` as integer pixels plus
  `content_scale_factor`. The fade and grow animations in `base_window.gd:268` and
  `:285` (driving `modulate.a`, `scale`, `pivot_offset`) are structurally impossible
  on a `Window`. This alone settles it for a stylized game.
- Migration would also cost the titlebar-free theming (`Window`'s theme surface is
  `title_font` / `title_color` / `title_height` / `close` / `embedded_border`;
  `AcceptDialog` adds only `panel`), and would force rewriting layout from
  anchors/containers to pixel `position`/`size`, plus reworking the outside-click hit
  test at `windows_layer.gd:100-101` — `gui_get_hovered_control` and `is_ancestor_of`
  do not compose the same way across a viewport boundary.

Accepted, known gaps versus `Window` (deliberate trade-offs, not oversights):

- No real focus management — focus never leaves the main viewport.
- No screen-reader semantics. `Window` carries `accessibility_name` /
  `accessibility_description` in 4.7; a `PanelContainer` pretending to be a dialog
  will not be announced as one.
- `ConfirmationDialog` (`dialog_text`, `ok_button_text`, `cancel_button_text`,
  `dialog_autowrap`, `confirmed`/`canceled`, `add_button`) is re-implemented by hand.
- `dialog_close_on_escape` / `close_requested` are hand-rolled in
  `base_window.gd:237-253`.

Unverified, worth measuring before assuming either way: each `Window` is a `Viewport`
by inheritance, but whether *embedded* subwindows allocate their own render target is
not something the docs settled. Relevant only if the decision is ever revisited —
given the fill-rate work in the drum viewport, don't assume dialog viewports are free.

---

## Phase 0 — fixes that the expansion depends on

- [x] **`PauseMenu` leaks a node per open** — fixed by setting `destroy_on_close = true`
      in `show_pause_menu()`. Previously `destroy_on_close` defaulted to `false` and
      `windows.erase` only ran on `destroyed` (`windows_layer.gd:34`), so every Escape
      press permanently added a hidden node under `%CurrentWindowContainer` and an
      entry to `windows` — which `close_all_but` and `get_open_window` then iterate.
      Note this makes Phase 1 more urgent, not less: the pause menu is now *destroyed*
      by `close_all_but` when a confirmation opens, so answering No has nothing to
      return to.
- [x] **Remove the `reset_requested` disconnect workaround** in `gui.gd` — gone with
      the leak that caused it.
- [x] **Delete the commented-out reset code** in `pause_menu_window.gd`.
- [ ] **Confirm the dead `await tree_entered` at `base_window.gd:74`.** `tree_entered`
      fires *before* `_ready` for a node added via `add_child`, so the following
      `set_anchors_preset(PRESET_CENTER)` should never run. Verify, then delete both
      lines or restructure — this is load-bearing-looking code that probably does
      nothing.
- [ ] **`close_all_but` can skip windows.** `windows_layer.gd:84-88` iterates `windows`
      while a `close()` may synchronously reach `CLOSED` (when `fading_time == 0`,
      `update_state(0)` completes the transition immediately) and erase from the same
      array via `destroyed`. Iterate over a `duplicate()`.

## Phase 1 — the open stack in `WindowsLayer`

- [ ] Add `var open_stack: Array[BaseWindow] = []` **alongside** the existing
      `windows` registry (`windows_layer.gd:11`) — the registry stays as-is (it is
      editor-populated); the stack only tracks what is currently open, innermost last.
- [ ] `_on_window_started_opening` (`:37-38`) becomes: unwind `open_stack` down to the
      new window's owner, then push. A window with no owner clears the stack — which
      preserves today's behaviour exactly for every existing call site.
- [ ] `get_open_window()` (`:68-72`) returns `open_stack.back()` instead of the first
      open entry in `windows`. **This is the change that matters most** — with a chain
      the current implementation returns the *parent*, so the outside-click handler at
      `:91-102` would read `close_on_outside_click` off the parent and run
      `is_ancestor_of(hov)` against the parent, making clicks on the child's own
      buttons register as "outside" and trigger `close_all()`.
- [ ] `any_window_open()` (`:61-66`) becomes `not open_stack.is_empty()`.
- [ ] Pop on close: connect each window's `closed` to a stack pop, and make sure a
      window closing mid-stack takes everything above it with it.
- [ ] Verify the pause-source logic at `:41-51` still holds — with parent *and* child
      open, `any_window_open()` stays true throughout, which is precisely what fixes
      the "answer No and land back in the running game" bug.

## Phase 2 — ownership and modality on `BaseWindow`

Two separate axes, as in every system that has this (Godot's own `Window` has
`transient` / `transient_to_focused` for ownership and `exclusive` +
`popup_exclusive*` for modality; Win32 splits `hwndOwner` from `DialogBox` disabling
the owner; Qt splits the parent pointer from a three-level `windowModality`, whose
`WindowModal` level — block only the parent chain — is exactly this case).

- [ ] Add `var owner_window: BaseWindow` (ownership) and `@export var exclusive: bool`
      (modality) to `BaseWindow`.
- [ ] Add `func open_child(w: BaseWindow) -> BaseWindow` that sets `owner_window` and
      opens — the API the call sites actually use.
- [ ] **Cascade `close()` downward**: closing or freeing a window closes and frees its
      children. Without this you get an orphaned confirm dialog over a dead pause menu,
      and a coroutine awaiting a signal on a freed node.
- [ ] **Do not make `close()` blockable by children.** A "parent waits for its child
      before finishing its close" state means `CLOSING` cannot complete, which needs a
      new state (or a re-entrant close) on a machine that already carries
      READY/CLOSED/OPENING/OPEN/CLOSING at `base_window.gd:18-26`. The motivating case
      — the pause menu closing *because* of the reset — is expressed better as the
      parent awaiting the child's result and *then* calling `close()`.
- [ ] **Block input to the owner while an exclusive child is open.** Clear
      `ui_actions_enabled` (`base_window.gd:40`) on everything below the top of the
      stack, and block mouse input on the owner. Note that modulating or scaling a
      Control does **not** stop it receiving mouse input — this needs `mouse_filter`
      or a blocker Control, not a visual change.
- [ ] **Make input routing deliberate.** Today both windows run `_input` and whichever
      runs first calls `set_input_as_handled()`; the child wins only because it was
      added later. With the stack, only `open_stack.back()` should process ui actions.
- [ ] **Per-level dimming.** There is one `%WindowsBackground` for the whole layer
      (`windows_layer.gd:13`), so with two stacked windows nothing signals that the
      parent is inactive. Needs either a scrim per stack level or the owner modulated
      down (plus the real input blocking above).
- [ ] **Encode the rule: no window writes global state directly.** Anything global —
      music ducking, the pause source, the scrim, input blocking — must be *derived by
      `WindowsLayer` from the aggregate* (`any_window_open()` today, the stack after
      Phase 1), never set by an individual window's `open()`/`close()`. Precedent: the
      pause menu used to duck music in its own `close()`, so opening a confirmation
      dialog un-ducked the music mid-dialog (the aggregate said a window was still
      open; the pause menu didn't ask). The scrim and pause source never had the bug
      because they were only ever derived. Owned windows multiply the number of
      handoffs where an individual window's idea of "I am closing" disagrees with
      "anything is still open", so this has to be a rule, not a habit.

## Phase 3 — factory methods on `BaseWindow`

`godot_base_settings.gd:16` already documents `base_window_scene` as *"Scene that will
be used to create windows in BaseWindow factory methods"* — those factory methods do
not exist, and `gui.gd:28-71` hand-rolls the same eight lines three times
(instantiate → set title/text → `destroy_on_close = true` → `open()` → `await closed`
→ compare against `Results.Yes`).

- [ ] `static func confirm(title: String, text: String = "") -> bool`. Verified on
      4.7.1 that static functions can be coroutines and return a value through
      `await`, so call sites read `if await BaseWindow.confirm("..."): ...` and never
      touch `Results` or `destroy_on_close`.
- [ ] `static func alert(title: String, text: String = "") -> void` for the
      no-choice case (`can_cancel = false`).
- [ ] **Owner-aware overloads**, once Phase 2 lands — a factory window opened from
      inside another window should be *owned* by it, not pushed at stack root.
      Probably an optional `owner: BaseWindow = null` parameter rather than a
      separate method.
- [ ] **Settle the translation policy in the factory.** `update_default_info` no
      longer calls `tr()`, so call sites translate instead — but that leaves
      editor-set `title`/`text` exports untranslated. Currently latent (no
      translations are configured in `project.godot`), and it should be decided in
      one place before any are added. The factory is that place.
- [ ] Migrate the three `gui.gd` call sites and delete the duplication.

## Phase 4 — migrate the reset confirmation

- [ ] Move the reset flow out of `gui.gd:26-39` and back into `PauseMenu`, where it
      belongs, deleting the `reset_requested` signal entirely:

      ```gdscript
      func _on_reset_pressed() -> void:
          var confirm = open_child(...)
          await confirm.closed
          if confirm.result == Results.Yes:
              Pause.force_unpaused()
              Events.new_game_requested.emit()
      ```

- [ ] Verify modality kills the double-click bug: during the pause menu's 0.08 s close
      fade its buttons are still visible and clickable, so today a second Reset press
      spawns a second confirm window that closes the first via `close_all_but`.
- [ ] Route the copy through the Phase 3 factory so the three dialogs stop setting
      `title`/`text`/`destroy_on_close` by hand.

## Testing

- [ ] GUT coverage for the stack itself (push/unwind/pop ordering, `get_open_window`
      returning the innermost) — this is pure logic and testable headless.
- [ ] Manual: the animation, dimming, and input-blocking work needs the real app;
      headless validates shaders but cannot measure rendering.

## YAGNI

Multiple independent chains open at once; per-window z-index overrides; modality
levels beyond "blocks its owner chain"; draggable/resizable windows; migrating any of
this to native `Window` nodes.
