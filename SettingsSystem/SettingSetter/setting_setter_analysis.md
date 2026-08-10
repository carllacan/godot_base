# Setting setter analysis (2026-08-05)

Findings from reading `setting_setter.gd` after the move to `BaseComponent`, while
writing `Tests/test_setting_setter.gd`. Behaviours marked *(pinned by a test)* are
demonstrated by the test suite as it stands, so changing them means updating that test
too.

The refactor already absorbed the parent-validation problems this review originally
raised: `_is_parent_valid` reports a bad parent both at runtime and in the editor,
and the target wiring moved to `_on_parent_ready`. What
follows is what is left, in the order it is worth fixing.

## 1. Two scenes still set a property that no longer exists

`Game/game_main.tscn` lines 1104 and 1125 — the HUD mute and music toggles — set:

```
override_text = false
```

The export was renamed to `override_button_text` in GodotBase commit `3ed214c`, and the
scenes were never updated. Godot silently drops the unknown property, so both components
fall back to the default `true` and `update_parent()` writes `"SOUND: ON"` /
`"MUSIC: ON"` into two icon-only 48x48 buttons.

**Fix direction**: rename the property in both nodes. Worth a look at the HUD first to
see what it is actually rendering — whatever it is, it has been that way since the
rename.

## 2. Overridden labels are never translated

`SettingInfo.get_value_representation` ends with `return tr(val_str)`
(`setting_info.gd:83`), but the override branch (lines 152-157) returns the authored
string untouched:

```gdscript
var val_str:String
if val in value_representation_overrides:
	val_str = value_representation_overrides[val]
else:
	val_str = target_setting.get_value_representation(val)
```

So the pause menu's "Low" / "Medium" / "High" stay English in every locale, while the
window mode button next to them translates. The component redraws on
`NOTIFICATION_TRANSLATION_CHANGED` (lines 42-44), so being localisable is clearly the
intent.

**Fix direction**: `val_str = tr(value_representation_overrides[val])`. One line, and it
makes the existing translation notification actually worth having.

## 3. Keyboard and gamepad cycling does not consume its own event

`increase_actions` defaults to `["ui_accept", "ui_right"]` and `decrease_actions` to
`["ui_left"]`, and the focus branch (lines 80-87) never calls `accept_event()`:

```gdscript
	var focused = get_target().get_viewport().gui_get_focus_owner()
	if get_target() == focused:
		for a in decrease_actions:
			if event.is_action_pressed(a):
				cycle_setting(-1)
```

`ui_left` and `ui_right` are also Godot's focus-navigation actions, so I would expect
pressing right on a focused setting button to both change the value and move focus to the
next control. Confirm on a gamepad in the settings menu before fixing — it is a ten
second check and it decides whether this is a bug or a non-issue.

**Fix direction**: `accept_event()` after a cycle, as `navigation_marker.gd` does with
`set_input_as_handled()`. Worth considering the same move that component made since:
`BaseButton.shortcut` handles the enabled/visible/focus rules for you, so
`increase_actions` could become a `Shortcut` and delete this whole branch.

## 4. The bool toggle state looks inverted, and fights the button for a frame

Line 169, in `update_parent()`:

```gdscript
	if target_setting.is_bool() and (parent as Button).toggle_mode:
		parent.set_pressed_no_signal(not val)
```

For the HUD toggles (`toggle_mode = true`, `sound_enabled = true`) the button renders
*un*-pressed while sound is on. If that is deliberate — "pressed means the action you
would take" — it needs a comment, because nothing else in the component reads that way.

There is a second-order problem regardless of which way it goes: clicking a toggle Button
makes the engine flip `button_pressed` immediately, and `update_parent()` overwrites it a
frame later (see 5), so the button briefly shows one state and then the other.

*Deliberately not pinned by a test* — the test suite covers `toggle_mode` being set, but
not the pressed state, because the intent is unclear.

## 5. The awaited frame in `_on_setting_changed` looks unnecessary

Line 132, carrying its own TODO:

```gdscript
func _on_setting_changed(setting_name:String, _new_value:Variant)-> void:
	if setting_name == target_setting.name:
		await get_tree().process_frame # TODO: do this some other way.
		update_parent()
```

`SettingsContainer.set_setting_by_name` stores the value *before* `SettingsManager` emits
`setting_changed` (`settings_manager.gd:59-62`), so `update_parent()` can read the new
value synchronously. The wait costs a frame of stale UI on every change and is what makes
the flicker in 4 visible.

**Fix direction**: drop the await. The tests only ever wait *extra* frames
(`wait_process_frames(2)`), so they stay green either way.

## 6. `enabled` does nothing

`BaseComponent.enabled` (`base_component.gd:39`) is now part of every component's
interface, and on its own it only drives the processing callbacks — which this component
does not use. So a setter with `enabled = false` still connects to `gui_input`, still
cycles the setting on click, and still rewrites the button's text and icon.

**Fix direction**: honour it where the component acts — an early `if not enabled: return`
in `cycle_setting()` at minimum, and decide whether a disabled setter should also stop
refreshing its target. Whatever the answer, it belongs in the class doc, since "enabled
means nothing here" is a legitimate choice but not a guessable one.

## 7. A missing `target_setting` still crashes, and the editor could say so

`_on_parent_ready` calls `target_setting.is_bool()` (line 57) and `update_parent()` reads
`target_setting.dname` and `.name` (lines 145-146), none of it guarded. The component is
`@tool` now, so this is cheap to catch where it belongs:

```gdscript
func _get_configuration_warnings()-> PackedStringArray:
	var warnings := super()
	if target_setting == null:
		warnings.append("No target setting set")
	if show_only_overridden_values and get_shown_values().is_empty():
		warnings.append("Only overridden values are shown, but no override is set")
	return warnings
```

That second case is currently a runtime `push_error` from `cycle_setting` (lines 105-107)
that the player triggers by clicking a dead button.

Smaller version of the same thing: line 52 connects `gui_input` before the `if t is Button`
check on line 54, so a non-Control target errors there rather than being reported by the
`_is_parent_valid` machinery.

## 8. A mouse event falls through into the action loops

`_on_parent_received_input` (lines 67-87) handles the click and then keeps going into the
focus/action block, re-testing the same event against `increase_actions` and
`decrease_actions`. Harmless with the default InputMap, since no mouse button is bound to
`ui_accept` / `ui_left` / `ui_right` — but binding one would silently double-cycle.

**Fix direction**: `return` after handling a click.

## 9. Every step writes the settings file

`cycle_setting` → `Settings.set_setting_value_by_name` → `save_settings()` →
`ResourceSaver.save` (`settings_manager.gd:59-62` and `:92`). Cycling a 0-10 int setting
end to end writes the file ten times, each one a full resource serialisation on the main
thread.

**Fix direction**: belongs in `SettingsManager`, not here — coalesce saves behind a short
timer, or save when the settings menu closes. Note that the test suite snapshots and
restores `user://settings.tres` precisely because this component writes it on every
change.

## Smaller things

- **The cycle order is implicit.** `get_shown_values()` (lines 91-96) concatenates
  `icon_overrides` keys then `value_representation_overrides` keys, so filling both
  dictionaries in different orders gives an order no one chose. *(pinned by
  `test_shown_values_merge_both_override_dictionaries`)* Either document that
  `icon_overrides` decides, sort numeric settings, or add an explicit `shown_values`
  export that the two dictionaries decorate.
- **`must_show_value()` only feeds a log line** now (lines 148-150). Its natural consumer
  is the snapping feature below.
- **`_on_parent_button_pressed()` is an empty stub** (lines 126-127) connected to
  `pressed`. `Button.pressed` already gets press-release and keyboard activation right;
  moving the increase there would delete most of `_on_parent_received_input`.
- `MouseButton.MOUSE_BUTTON_RIGHT` (line 71) → `MOUSE_BUTTON_RIGHT`; `n` (line 145) is
  computed even when `include_settings_name` is false.
- **Variant keys and numeric types**: for a `TYPE_FLOAT` setting, keys authored as `0` in
  the inspector versus a stored `0.0` may or may not match on lookup. I have not checked
  how Godot hashes int against float dictionary keys — worth doing before anyone points
  this at a float setting.
- **`target_override` and readiness**: `BaseComponent._base_ready` waits on the *parent's*
  `ready`, but this component reads and writes `get_target()`. With an override set, the
  target may not have run its own `_ready` when `_on_parent_ready` fires.

## Features worth having

1. **Snap on ready.** With `show_only_overridden_values`, a value that is not in the list
   (a settings file written before the overrides existed) displays as `"QUALITY: 7"` until
   the player clicks. An export like `snap_to_shown_value` that moves to the nearest shown
   value in `_on_parent_ready` closes that hole, and gives `must_show_value()` a real job.
2. **Clamp instead of wrap.** A `wrap_around` toggle: for volume, jumping from max to min
   on one extra click is rarely what a player wants.
3. **Other target types.** `HSlider` for volumes, `OptionButton` for language — cycling
   three languages by clicking is fine, twelve is not. `CheckBox` already works, being a
   `Button`.
4. **A `value_cycled` signal**, so a scene can hook a click sound or a shake without every
   setter needing a script.
5. **Tooltip from `SettingInfo.description`.** The field exists and is marked "just for
   reference, will not be shown"; piping it into `tooltip_text` is free and already
   translated through `get_description()`.
