extends GutTest

## Name of the InputMap action used by the shortcut tests. Registered in
## before_all so the tests do not depend on the project's own actions.
const ACTION:String = "test_navigation_shortcut"


var _screens:Node


func before_all()-> void:
	if not InputMap.has_action(ACTION):
		InputMap.add_action(ACTION)


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
	action_shortcut:String = "",
)-> NavigationComponent:
	var button := Button.new()
	var nav := NavigationComponent.new()
	nav.to_hide = to_hide
	nav.to_show = to_show
	nav.hide_on_ready = hide_on_ready
	nav.show_on_ready = show_on_ready
	nav.action_shortcut = action_shortcut
	button.add_child(nav)
	add_child_autofree(button)
	return nav


func _action_event()-> InputEventAction:
	var event := InputEventAction.new()
	event.action = ACTION
	event.pressed = true
	return event


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


#region can_perform

func test_can_perform_in_the_source_state():
	var nav := _make_nav([_make_screen("Source", true)], [_make_screen("Destination", false)])

	assert_true(nav.can_perform())


func test_cannot_perform_when_destination_is_already_visible():
	var nav := _make_nav([_make_screen("Source", true)], [_make_screen("Destination", true)])

	assert_false(nav.can_perform())


func test_cannot_perform_when_source_is_already_hidden():
	var nav := _make_nav([_make_screen("Source", false)], [_make_screen("Destination", false)])

	assert_false(nav.can_perform())


func test_cannot_perform_when_one_of_several_sources_is_hidden():
	var nav := _make_nav(
		[_make_screen("SourceA", true), _make_screen("SourceB", false)],
		[_make_screen("Destination", false)],
	)

	assert_false(nav.can_perform())


func test_cannot_perform_before_ready():
	var nav:NavigationComponent = autofree(NavigationComponent.new())
	nav.to_hide = [_make_screen("Source", true)]
	nav.to_show = [_make_screen("Destination", false)]

	assert_false(nav.can_perform())

#endregion


#region action shortcut

func test_shortcut_navigates_when_it_can_perform():
	var source := _make_screen("Source", true)
	var destination := _make_screen("Destination", false)
	var nav := _make_nav([source], [destination], false, false, ACTION)

	nav._input(_action_event())

	assert_false(source.visible)
	assert_true(destination.visible)


func test_shortcut_does_nothing_when_it_cannot_perform():
	# Already in the destination state, as the screen this navigation leads
	# away from is not the one currently open
	var source := _make_screen("Source", false)
	var destination := _make_screen("Destination", true)
	var nav := _make_nav([source], [destination], false, false, ACTION)
	watch_signals(nav)

	nav._input(_action_event())

	assert_signal_emit_count(nav, "performed", 0)


func test_shortcut_ignores_other_actions():
	var source := _make_screen("Source", true)
	var destination := _make_screen("Destination", false)
	var nav := _make_nav([source], [destination], false, false, ACTION)

	var event := InputEventAction.new()
	event.action = "ui_accept"
	event.pressed = true
	nav._input(event)

	assert_true(source.visible)
	assert_false(destination.visible)


func test_no_shortcut_means_events_are_ignored():
	var source := _make_screen("Source", true)
	var destination := _make_screen("Destination", false)
	var nav := _make_nav([source], [destination])

	nav._input(_action_event())

	assert_true(source.visible)
	assert_false(destination.visible)

#endregion
