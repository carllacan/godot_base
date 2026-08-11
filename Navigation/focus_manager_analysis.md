# FocusManager analysis (2026-08-11)

Review of `focus_manager.gd`, written while giving it its class docstring. The
component has no instances anywhere in bingomental yet — nothing references its
UID in a `.tscn` — so none of this is a live regression, and the fixes are free
to make now, before the first screen depends on the current behaviour.

`Tests/test_focus_manager.gd` already covers it, 27 tests, all passing. Where a
fix would change what a test asserts it is named in the item; where the existing
tests would keep passing that is said too, so the ones that need a new test are
easy to pick out.

Three engine behaviours matter throughout and were measured on 4.7.1 headless
rather than assumed:

- `Viewport.gui_focus_changed` is emitted only when a control *gains* focus.
  Releasing focus emits nothing, so `_on_focus_changed`'s parameter is never
  `null`.
- Hiding a `Control` emits `visibility_changed` **before** the engine releases
  the focus of anything inside it, and the engine only releases focus that is
  actually inside the hidden subtree.
- `Control.grab_focus()` on a **hidden** control succeeds. It becomes the
  viewport's focus owner with nothing visible on screen.

(One candidate bug died on contact: a freed `last_focused_control` is harmless,
because in 4.7 `freed_node != null` evaluates to `false`, so the existing null
guard already covers it. A *hidden* one is not covered — see item 2.)

## TL;DR

The visibility-driven design is right, and the once-per-frame focus sound is
carefully done. The problems are all about scope: the component reaches for
*the viewport's* focus where it means *its own screen's* focus. That is one bug
when releasing (item 1) and a worse one when remembering (item 2). Beyond that,
a screen that is visible from the start is never focused at all (item 4).

## Bugs

### 1. `unfocus()` releases the focus even when it belongs to another screen

`focus_manager.gd:132`. `get_viewport().gui_release_focus()` is called
unconditionally, with no check that the focus owner is anything to do with this
screen.

The engine is more careful than this: hiding a Control releases only the focus
held inside it. So hiding screen A while screen B holds the focus leaves B alone
if the engine does it and kills B's focus if this component does. The plain
`NavigationComponent` hide-then-show order never triggers it — the outgoing
screen still owns the focus at the moment it hides, which is exactly what that
ordering is for — but closing a modal after the screen underneath has grabbed
focus does, and so does any HUD panel that hides on its own.

Fix: release only when `get_target().is_ancestor_of(focus_owner)`.

Tests: every existing unfocus test focuses a control inside the screen, so they
all keep passing. The foreign-focus case is untested and would want a new one.

### 2. `last_focused_control` can point at a foreign or hidden control

`focus_manager.gd:130` stores whatever `gui_get_focus_owner()` returns with no
check that it is under the target, and `focus_manager.gd:124` grabs focus on it
later with no check that it is still usable.

Because a hidden control *can* hold focus (measured, above), the visible symptom
is not an error but silence: nothing highlighted anywhere on screen, while d-pad
input goes to a control on a closed screen. Two ways in:

- Via item 1 — hiding A while B is focused makes A remember B's button, and
  reopening A focuses it, by which time it is usually hidden.
- On its own — any screen that rebuilds or conditionally hides its controls at
  runtime leaves `last_focused_control` pointing into a subtree that is no
  longer shown.

Fix: store only when the owner is inside the target, and in `focus()` require
`is_inside_tree()` and `is_visible_in_tree()` before grabbing.

Tests: `test_unfocus_forgets_the_old_control_when_nothing_is_focused` pins that
unfocusing with nothing focused wipes the memory rather than keeping the old
value; the fix above preserves that. The rest keep passing.

### 3. `focus()` never falls back to `first_focus`

`focus_manager.gd:116-121`. The `else` is an alternative, not a fallback: once
`persist_focus` is on and `last_focused_control` has been set, `first_focus` is
unreachable forever, however unusable the remembered control has become.

This is the other half of item 2 — validating the remembered control is only
useful if there is something to fall back to.

Tests: `test_focus_grabs_the_remembered_control_instead` and
`test_focus_ignores_the_remembered_control_when_focus_is_not_persisted` both use
a valid, visible remembered control, so both keep passing.

### 4. A screen that is visible at load never receives focus

All three triggers are edge-triggered. A start-visible main menu gets no
`visibility_changed`, and `InputManager.type_changed` only fires on a *change*,
so a player who boots the game with a gamepad already in hand opens on a screen
with nothing focused. `first_focus` reads like it should apply at startup and
does not.

The engine's own fallback softens this without fixing it. Measured on 4.7.1:
pressing a direction with no focus owner focuses the first control in tree order
— but only for `ui_down`/`ui_right`, only when the screens sit under a single
root Control, and never for `ui_up`. So the player's first stick press is eaten
and lands wherever tree order says, rather than on `first_focus`.

Fix: a `focus_on_ready` export, or `focus()` from `_on_parent_ready` when the
target is visible and `InputManager.is_joypad()`.

### 5. `target_override` into another viewport half-works

`focus_manager.gd:96` correctly listens on `get_target().get_viewport()`, but
`focus_manager.gd:130-132` uses the component's own `get_viewport()`. Those
differ exactly when `target_override` points into a `SubViewport` — the case the
override exists for — and the manager then queries and releases focus on the
wrong viewport while listening to the right one.

Fix: `get_target().get_viewport()` in both `focus()` and `unfocus()`.

## Improvements

### The frame guard in `_on_parent_visibility_changed` is redundant

`focus_manager.gd:151-153`. `focus()` on the line above emits
`gui_focus_changed` synchronously, so `_on_focus_changed` has already played the
sound and raised the same flag with the same one-frame coroutine before line 151
runs. Setting it again only adds a second coroutine racing the first to clear one
bool. Its one live effect is the case where `focus()` finds no candidate, where
it silences the rest of the frame for no reason.

`test_showing_the_parent_plays_the_focus_sound` is the decision point, and its
comment says the current audible behaviour is deliberate. Deleting the three
lines keeps that test passing. Moving the flag to *before* the `focus()` call —
if silencing the open-the-screen click was ever the intent — inverts it.

### `_on_input_type_changed` ignores its own argument

`focus_manager.gd:136-137`. The untyped `_new_type` is discarded and
`InputManager.current_controller_type` re-read to get the same value.
`func _on_input_type_changed(new_type:InputManager.ControllerTypes)` matched
directly says the same thing with one less indirection.

### `@tool` is declared but no configuration warnings are added

The edit-time cost of `@tool` is already being paid and only
`_is_parent_valid` uses it. Cheap additions, all catching things that are
currently silent or only warn at runtime:

- `first_focus` set but not a descendant of the target.
- `first_focus.focus_mode == FOCUS_NONE`, which `grab_focus()` only complains
  about at runtime, once, in the output log.
- `focus_on_joypad` on with no `first_focus`, which cannot do anything on a
  screen that has not been opened before.

### Nested managers double up the focus sound

`focus_change_played_this_frame` is per-instance and the ancestor test is
subtree-based, so a manager on a sub-panel inside a managed screen plays its
click alongside the outer one whenever both have a player assigned. Not
reachable today — nothing instantiates the component yet — but it is the kind of
thing that surfaces the day two screens are nested, long after the sound was
set up.

Run the tests with:

```
godot --headless -s addons/gut/gut_cmdln.gd -gdir=res://GodotBase/Navigation -ginclude_subdirs -gexit
```

from the `bingomental/` directory.
