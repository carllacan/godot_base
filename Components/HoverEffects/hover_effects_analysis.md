# Hover effects analysis (2026-08-05)

Findings from reading `hover_effects.gd` while writing `Tests/test_hover_effects.gd`.
Four problems, in the order they are worth fixing. Behaviours marked *(pinned by a
test)* are demonstrated by the test suite as it stands, so fixing them means updating
that test too.

## 1. The remembered modulate goes stale and clobbers every other modulate writer

`original_modulate` is snapshotted once, in `_ready()` (line 17), and `update_effects()`
(lines 58-62) writes an **absolute** value derived from that snapshot on both the enter
and the exit transition:

```gdscript
func update_effects()-> void:
	if is_parent_hovered or is_parent_focused:
		get_parent().modulate = original_modulate*modulate_factor
	else:
		get_parent().modulate = original_modulate
```

Anything else that writes `modulate` on the same node loses the moment the mouse
touches it. In this same Components folder both `Fader/fader.gd` and
`Floater/floater.gd` animate `get_parent().modulate`; a tween, a disabled-state dim, or
plain code doing `card.modulate.a = 0.5` are all equally vulnerable. The node snaps back
to whatever it looked like when the scene loaded — mid-fade, mid-float, dim gone.

**Fix direction**: capture the modulate at the untinted → tinted transition instead of at
ready, i.e. collapse the two setters onto a single `set_tinted(bool)` that does
`original_modulate = get_parent().modulate` on the way in. That still loses changes made
*while* the node is tinted, but it stops the component from fighting everything else on
the node for the common case.

The alternative — applying the factor multiplicatively and dividing it back out on exit —
avoids the snapshot entirely but drifts with float error and divides by zero on any
factor channel set to 0, so it is not worth it.

## 2. The component is silently dead when added to a parent that is already ready

*(pinned by `test_effects_added_to_a_parent_that_is_already_ready_never_react`)*

`_ready()` (line 16) connects to `get_parent().ready` and does its real wiring from
there. That works when the component and its parent come out of the same packed scene —
children are ready before their parent, so the signal is still to come. It does **not**
work for a component instantiated and added to a parent that is already in the tree: the
`ready` signal has already fired and will never fire again, so the four connections are
never made. No error, no warning, just a component that does nothing.

**Fix direction**: the wait does not appear to buy anything — `mouse_entered`,
`focus_entered` and the rest exist on the Control from the moment it is constructed, so
the body of `_on_parent_ready()` can run directly from `_ready()`. If the deferred shape
is worth keeping for some reason, guard it:

```gdscript
if get_parent().is_node_ready(): _on_parent_ready()
else: get_parent().ready.connect(_on_parent_ready)
```

## 3. `on_hover` / `on_focus` gate the events rather than the effect

*(pinned by `test_turning_the_hover_effect_off_does_not_untint_a_hovered_parent`)*

The switches are checked in the signal handlers (lines 39 and 44), not in
`update_effects()`. Turn `on_hover` off while the parent is hovered and the matching
`mouse_exited` is dropped on the floor, leaving the parent tinted permanently. Same for
`on_focus`.

**Fix direction**: always track `is_parent_hovered` / `is_parent_focused`, and apply the
switches where the effect is decided:

```gdscript
var is_hovering:bool = is_parent_hovered and on_hover
var is_focusing:bool = is_parent_focused and on_focus
```

This makes the exports live — flipping one re-evaluates the tint instead of freezing it.
Only matters if they are ever toggled at runtime, which is why this is third.

## 4. A non-Control parent fails with an opaque error

`_on_parent_ready()` (lines 31-35) reaches for `mouse_entered` and `focus_entered`, which
only exist on Control. Hang the component off a Node2D and the failure is
`Invalid access to property or key 'mouse_entered'` from inside a callback, with nothing
identifying the scene that is misconfigured. Per the project directives this is an assert
case, in `_ready()`:

```gdscript
assert(get_parent() is Control, "HoverEffects must hang from a Control")
```

Smaller things in the same function: `var p = get_parent()` is untyped, and the `.bind(p)`
on all four connections feeds a `_control` argument that all four handlers ignore — both
the binds and the parameters can go.
