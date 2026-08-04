extends GutTest

## Name of the InputMap action used by the shortcut tests. Registered in
## before_all so the tests do not depend on the project's own actions.
const ACTION:String = "test_navigation_shortcut"


var _screens:Node


func before_all()-> void:
	# The action is bound to a real key because Viewport only dispatches
	# InputEventKey/Shortcut/JoypadButton to shortcut_input — an InputEventAction
	# is never routed there, so the tests have to push an actual key press.
	if not InputMap.has_action(ACTION):
		InputMap.add_action(ACTION)
		InputMap.action_add_event(ACTION, _key_event())


func after_all()-> void:
	if InputMap.has_action(ACTION):
		InputMap.erase_action(ACTION)


func before_each()-> void:
	_screens = add_child_autofree(Node.new())


## A node standing in for a menu screen, in the tree and with a known visibility
func _make_screen(screen_name:String, visible:bool)-> Control:
	var screen := Control.new()
	screen.name = screen_name
	screen.visible = visible
	_screens.add_child(screen)
	return screen


## Builds a Button with a NavigationComponent under it and puts it in the tree,
## which is what makes the parent emit "ready" and the on-ready behaviour run.
func _make_nav(
	to_hide:Array[Node],
	to_show:Array[Node],
	hide_on_ready:bool = false,
	show_on_ready:bool = false,
)-> NavigationComponent:
	var button := Button.new()
	var nav := NavigationComponent.new()
	nav.to_hide = to_hide
	nav.to_show = to_show
	nav.hide_on_ready = hide_on_ready
	nav.show_on_ready = show_on_ready
	button.add_child(nav)
	add_child_autofree(button)
	return nav


## The key press a player would actually make, bound to ACTION in before_all
func _key_event()-> InputEventKey:
	var event := InputEventKey.new()
	event.keycode = KEY_F13
	event.pressed = true
	return event


## The Shortcut resource a back button would carry. It holds an InputEventAction
## rather than a key, so the binding lives in the InputMap and is remappable.
func _make_shortcut()-> Shortcut:
	var action := InputEventAction.new()
	action.action = ACTION
	action.pressed = true
	var shortcut := Shortcut.new()
	shortcut.events = [action]
	return shortcut


#region on ready

func test_hides_to_hide_on_ready():
	var source := _make_screen("Source", true)

	_make_nav([source], [], true)

	assert_false(source.visible)


func test_does_not_hide_when_hide_on_ready_is_false():
	var source := _make_screen("Source", true)

	_make_nav([source], [], false)

	assert_true(source.visible)


func test_shows_to_show_on_ready_when_asked():
	var destination := _make_screen("Destination", false)

	_make_nav([], [destination], false, true)

	assert_true(destination.visible)


func test_does_not_show_to_show_on_ready_by_default():
	var destination := _make_screen("Destination", false)

	_make_nav([], [destination], true)

	assert_false(destination.visible)

#endregion


#region perform_navigation

func test_navigation_hides_source_and_shows_destination():
	var source := _make_screen("Source", true)
	var destination := _make_screen("Destination", false)
	var nav := _make_nav([source], [destination])

	nav.perform_navigation()

	assert_false(source.visible, "source screen should be hidden")
	assert_true(destination.visible, "destination screen should be shown")


func test_navigation_handles_several_nodes_on_each_side():
	var source_a := _make_screen("SourceA", true)
	var source_b := _make_screen("SourceB", true)
	var destination_a := _make_screen("DestinationA", false)
	var destination_b := _make_screen("DestinationB", false)
	var nav := _make_nav([source_a, source_b], [destination_a, destination_b])

	nav.perform_navigation()

	assert_false(source_a.visible)
	assert_false(source_b.visible)
	assert_true(destination_a.visible)
	assert_true(destination_b.visible)


func test_navigation_emits_performed():
	var nav := _make_nav([_make_screen("Source", true)], [_make_screen("Destination", false)])
	watch_signals(nav)

	nav.perform_navigation()

	assert_signal_emit_count(nav, "performed", 1)


# The outgoing screen must release focus before the incoming one grabs it, so
# every node is hidden before any node is shown.
func test_navigation_hides_everything_before_showing_anything():
	var source := _make_screen("Source", true)
	var destination := _make_screen("Destination", false)
	var nav := _make_nav([source], [destination])

	var order:Array[String] = []
	source.visibility_changed.connect(func(): order.append(source.name))
	destination.visibility_changed.connect(func(): order.append(destination.name))

	nav.perform_navigation()

	assert_eq(order, ["Source", "Destination"] as Array[String])


func test_pressing_the_parent_button_navigates():
	var source := _make_screen("Source", true)
	var destination := _make_screen("Destination", false)
	var nav := _make_nav([source], [destination])

	(nav.get_parent() as Button).pressed.emit()

	assert_false(source.visible)
	assert_true(destination.visible)

#endregion


#region parent button shortcut

# Keyboard/gamepad navigation is delegated to BaseButton.shortcut rather than
# handled here. These tests pin the engine behaviour this component relies on:
# a shortcut only fires for a button that is visible in tree and enabled, which
# is what lets every back button in a menu share one "ui_cancel" resource and
# still have only the open screen react.

func test_parent_button_shortcut_navigates():
	var source := _make_screen("Source", true)
	var destination := _make_screen("Destination", false)
	var nav := _make_nav([source], [destination])
	(nav.get_parent() as Button).shortcut = _make_shortcut()

	get_tree().root.push_input(_key_event())

	assert_false(source.visible, "source screen should be hidden")
	assert_true(destination.visible, "destination screen should be shown")


func test_shortcut_ignores_other_keys():
	var source := _make_screen("Source", true)
	var destination := _make_screen("Destination", false)
	var nav := _make_nav([source], [destination])
	(nav.get_parent() as Button).shortcut = _make_shortcut()

	# A real key press, but not the one bound to ACTION
	var event := InputEventKey.new()
	event.keycode = KEY_F14
	event.pressed = true
	get_tree().root.push_input(event)

	assert_true(source.visible)
	assert_false(destination.visible)


func test_shortcut_does_nothing_when_the_button_is_hidden():
	var source := _make_screen("Source", true)
	var destination := _make_screen("Destination", false)
	var nav := _make_nav([source], [destination])
	var button := nav.get_parent() as Button
	button.shortcut = _make_shortcut()
	button.hide()
	watch_signals(nav)

	get_tree().root.push_input(_key_event())

	assert_signal_emit_count(nav, "performed", 0)


func test_shortcut_does_nothing_when_the_button_is_disabled():
	var source := _make_screen("Source", true)
	var destination := _make_screen("Destination", false)
	var nav := _make_nav([source], [destination])
	var button := nav.get_parent() as Button
	button.shortcut = _make_shortcut()
	button.disabled = true
	watch_signals(nav)

	get_tree().root.push_input(_key_event())

	assert_signal_emit_count(nav, "performed", 0)


func test_no_shortcut_means_events_are_ignored():
	var source := _make_screen("Source", true)
	var destination := _make_screen("Destination", false)
	_make_nav([source], [destination])

	get_tree().root.push_input(_key_event())

	assert_true(source.visible)
	assert_false(destination.visible)

#endregion
