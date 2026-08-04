extends GutTest

## The effects react to the mouse and focus signals of the control they hang
## from, so the tests emit those signals on the parent by hand rather than
## moving a real pointer around. _make_effects builds the component under a
## parent that is not in the tree yet, which is how a scene does it, and is what
## lets the component catch the parent's ready signal.

const HALF_ALPHA:Color = Color(1.0, 1.0, 1.0, 0.5)
const HALF_RED:Color = Color(1.0, 0.5, 0.5, 1.0)


## Builds the effects hanging from the control they tint. The parent's modulate
## is set before it enters the tree because that is the modulate the effects
## take as the untinted one.
func _make_effects(opts:Dictionary = {})-> HoverEffects:
	var parent := Control.new()
	parent.modulate = opts.get("modulate", Color.WHITE)

	var effects := HoverEffects.new()
	effects.on_hover = opts.get("on_hover", true)
	effects.on_focus = opts.get("on_focus", false)
	effects.modulate_factor = opts.get("modulate_factor", HALF_ALPHA)

	parent.add_child(effects)
	add_child_autofree(parent)
	return effects


func _parent_of(effects:HoverEffects)-> Control:
	return effects.get_parent()


func _assert_modulate(effects:HoverEffects, expected:Color, text:String = "")-> void:
	var got:Color = _parent_of(effects).modulate
	assert_true(got.is_equal_approx(expected), "%s: modulate is %s, expected %s" % [text, got, expected])


#region what the parent starts out as

func test_the_parent_is_left_alone_until_something_happens():
	var effects := _make_effects({"modulate": HALF_RED})

	_assert_modulate(effects, HALF_RED, "an untouched parent")


func test_the_parents_modulate_is_remembered_as_the_untinted_one():
	var effects := _make_effects({"modulate": HALF_RED})

	assert_eq(effects.original_modulate, HALF_RED)


func test_the_parent_is_neither_hovered_nor_focused_to_begin_with():
	var effects := _make_effects()

	assert_false(effects.is_parent_hovered, "hovered")
	assert_false(effects.is_parent_focused, "focused")

#endregion


#region hovering

func test_the_mouse_entering_the_parent_tints_it():
	var effects := _make_effects()

	_parent_of(effects).mouse_entered.emit()

	assert_true(effects.is_parent_hovered)
	_assert_modulate(effects, HALF_ALPHA, "a hovered parent")


func test_the_mouse_leaving_the_parent_puts_it_back():
	var effects := _make_effects()

	_parent_of(effects).mouse_entered.emit()
	_parent_of(effects).mouse_exited.emit()

	assert_false(effects.is_parent_hovered)
	_assert_modulate(effects, Color.WHITE, "a parent the mouse has left")


func test_the_tint_is_the_factor_applied_to_the_parents_own_modulate():
	var effects := _make_effects({"modulate": HALF_RED, "modulate_factor": HALF_ALPHA})

	_parent_of(effects).mouse_entered.emit()

	_assert_modulate(effects, Color(1.0, 0.5, 0.5, 0.5), "a hovered half red parent")


func test_the_parent_goes_back_to_its_own_modulate_and_not_to_white():
	var effects := _make_effects({"modulate": HALF_RED})

	_parent_of(effects).mouse_entered.emit()
	_parent_of(effects).mouse_exited.emit()

	_assert_modulate(effects, HALF_RED, "a half red parent the mouse has left")


func test_the_factor_can_tint_the_colour_and_not_just_the_alpha():
	var effects := _make_effects({"modulate_factor": HALF_RED})

	_parent_of(effects).mouse_entered.emit()

	_assert_modulate(effects, HALF_RED, "a parent hovered with a colour factor")

#endregion


#region focusing

func test_focus_is_ignored_by_default():
	var effects := _make_effects()

	_parent_of(effects).focus_entered.emit()

	assert_false(effects.is_parent_focused)
	_assert_modulate(effects, Color.WHITE, "a focused parent that does not react to focus")


func test_the_parent_getting_the_focus_tints_it_when_the_effects_watch_the_focus():
	var effects := _make_effects({"on_focus": true})

	_parent_of(effects).focus_entered.emit()

	assert_true(effects.is_parent_focused)
	_assert_modulate(effects, HALF_ALPHA, "a focused parent")


func test_the_parent_losing_the_focus_puts_it_back():
	var effects := _make_effects({"on_focus": true})

	_parent_of(effects).focus_entered.emit()
	_parent_of(effects).focus_exited.emit()

	assert_false(effects.is_parent_focused)
	_assert_modulate(effects, Color.WHITE, "a parent that has lost the focus")


func test_the_effects_can_watch_the_focus_and_not_the_mouse():
	var effects := _make_effects({"on_hover": false, "on_focus": true})

	_parent_of(effects).mouse_entered.emit()
	_assert_modulate(effects, Color.WHITE, "a hovered parent that only watches the focus")

	_parent_of(effects).focus_entered.emit()
	_assert_modulate(effects, HALF_ALPHA, "the same parent once it is focused")

#endregion


#region turning the effects off

func test_the_mouse_is_ignored_when_the_hover_effect_is_off():
	var effects := _make_effects({"on_hover": false})

	_parent_of(effects).mouse_entered.emit()

	assert_false(effects.is_parent_hovered)
	_assert_modulate(effects, Color.WHITE, "a hovered parent that does not react to the mouse")


# Turning an effect off does not undo a tint that is already there: it only
# stops the component from hearing about that kind of event.
func test_turning_the_hover_effect_off_does_not_untint_a_hovered_parent():
	var effects := _make_effects()
	_parent_of(effects).mouse_entered.emit()

	effects.on_hover = false
	_parent_of(effects).mouse_exited.emit()

	_assert_modulate(effects, HALF_ALPHA, "a parent left tinted")

#endregion


#region hovering and focusing at once

func test_a_parent_that_is_both_hovered_and_focused_is_tinted_once():
	var effects := _make_effects({"on_focus": true})

	_parent_of(effects).mouse_entered.emit()
	_parent_of(effects).focus_entered.emit()

	_assert_modulate(effects, HALF_ALPHA, "a hovered and focused parent")


func test_the_tint_stays_while_either_the_mouse_or_the_focus_is_left():
	var effects := _make_effects({"on_focus": true})

	_parent_of(effects).mouse_entered.emit()
	_parent_of(effects).focus_entered.emit()
	_parent_of(effects).focus_exited.emit()

	_assert_modulate(effects, HALF_ALPHA, "a parent that is still hovered")


func test_the_tint_only_goes_away_once_both_are_over():
	var effects := _make_effects({"on_focus": true})

	_parent_of(effects).mouse_entered.emit()
	_parent_of(effects).focus_entered.emit()
	_parent_of(effects).focus_exited.emit()
	_parent_of(effects).mouse_exited.emit()

	_assert_modulate(effects, Color.WHITE, "a parent that is neither hovered nor focused")

#endregion


#region driving the effects by hand

func test_the_parent_can_be_tinted_by_setting_the_hovered_flag():
	var effects := _make_effects()

	effects.is_parent_hovered = true

	_assert_modulate(effects, HALF_ALPHA, "a parent marked as hovered")


func test_the_parent_can_be_tinted_by_setting_the_focused_flag():
	var effects := _make_effects()

	effects.is_parent_focused = true

	_assert_modulate(effects, HALF_ALPHA, "a parent marked as focused")


# The flags are set directly here, so the effects apply even though they are
# not watching the events that would normally set them.
func test_the_flags_do_not_go_through_the_on_hover_and_on_focus_switches():
	var effects := _make_effects({"on_hover": false, "on_focus": false})

	effects.is_parent_hovered = true

	_assert_modulate(effects, HALF_ALPHA, "a parent marked as hovered by hand")

#endregion


#region wiring

# The component listens for the parent's ready signal to connect to it, so it
# has to be hanging from the parent before the parent enters the tree. Added
# afterwards, it never hears about the mouse.
func test_effects_added_to_a_parent_that_is_already_ready_never_react():
	var parent:Control = add_child_autofree(Control.new())
	var effects := HoverEffects.new()

	parent.add_child(effects)
	parent.mouse_entered.emit()

	assert_false(effects.is_parent_hovered)
	assert_true(parent.modulate.is_equal_approx(Color.WHITE), "modulate is %s" % parent.modulate)

#endregion
