extends GutTest

## A FocusManager hangs from the Control whose focus it manages, so every test
## builds a screen Control with two focusable buttons and a manager under it.
## The manager is added before the screen enters the tree, because it hooks
## itself up to the parent and the viewport on the parent's "ready" signal.
##
## Focus is real viewport focus rather than a stand-in, and the focus sound is a
## real AudioStreamPlayer holding a moment of silence: this version of GUT
## cannot double AudioStreamPlayer, and a real player reports "playing"
## correctly under the dummy audio driver.


var _screen:Control
var _button_a:Button
var _button_b:Button
var _outsider:Button


func before_each()-> void:
	get_viewport().gui_release_focus()


## The controller type is global state shared with the rest of the suite
func after_each()-> void:
	InputManager.current_controller_type = InputManager.ControllerTypes.KBM


func _make_manager(opts:Dictionary = {})-> FocusManager:
	_screen = Control.new()
	_screen.visible = opts.get("visible", true)

	_button_a = Button.new()
	_button_b = Button.new()
	_screen.add_child(_button_a)
	_screen.add_child(_button_b)

	var manager := FocusManager.new()
	manager.first_focus = _button_a if opts.get("first_focus", true) else null
	manager.persist_focus = opts.get("persist_focus", true)
	manager.focus_on_joypad = opts.get("focus_on_joypad", false)
	manager.unfocus_on_kbm = opts.get("unfocus_on_kbm", false)
	if opts.get("sound", false):
		var player := _make_player()
		manager.sound_on_focus_change = player
		_screen.add_child(player)
	_screen.add_child(manager)

	add_child_autofree(_screen)

	# A control belonging to some other screen, to check that the manager only
	# reacts to what happens under its own parent
	_outsider = Button.new()
	add_child_autofree(_outsider)

	return manager


func _make_player()-> AudioStreamPlayer:
	var stream := AudioStreamWAV.new()
	stream.data = PackedByteArray([0, 0, 0, 0, 0, 0, 0, 0])
	var player := AudioStreamPlayer.new()
	player.stream = stream
	return player


func _focus_owner()-> Control:
	return get_viewport().gui_get_focus_owner()


#region focus

func test_focus_grabs_the_first_focus_control():
	var manager := _make_manager()

	manager.focus()

	assert_eq(_focus_owner(), _button_a)


func test_focus_grabs_the_remembered_control_instead():
	var manager := _make_manager({"persist_focus": true})
	manager.last_focused_control = _button_b

	manager.focus()

	assert_eq(_focus_owner(), _button_b)


func test_focus_ignores_the_remembered_control_when_focus_is_not_persisted():
	var manager := _make_manager({"persist_focus": false})
	manager.last_focused_control = _button_b

	manager.focus()

	assert_eq(_focus_owner(), _button_a)


func test_focus_does_nothing_without_a_first_focus_control():
	var manager := _make_manager({"first_focus": false})

	manager.focus()

	assert_null(_focus_owner())


# Having nothing to focus is not the same as asking for nothing to be focused,
# so a manager with no candidate leaves whatever had the focus holding it.
func test_focus_leaves_the_current_focus_alone_when_it_has_no_candidate():
	var manager := _make_manager({"first_focus": false})
	_outsider.grab_focus()

	manager.focus()

	assert_eq(_focus_owner(), _outsider)

#endregion


#region unfocus

func test_unfocus_releases_the_focus():
	var manager := _make_manager()
	_button_a.grab_focus()

	manager.unfocus()

	assert_null(_focus_owner())


func test_unfocus_remembers_the_focused_control():
	var manager := _make_manager({"persist_focus": true})
	_button_b.grab_focus()

	manager.unfocus()

	assert_eq(manager.last_focused_control, _button_b)


func test_unfocus_remembers_nothing_when_focus_is_not_persisted():
	var manager := _make_manager({"persist_focus": false})
	_button_b.grab_focus()

	manager.unfocus()

	assert_null(manager.last_focused_control)


# What is remembered is whatever holds the focus at that moment, so unfocusing
# while nothing is focused wipes the memory rather than keeping the old one.
func test_unfocus_forgets_the_old_control_when_nothing_is_focused():
	var manager := _make_manager({"persist_focus": true})
	manager.last_focused_control = _button_b

	manager.unfocus()

	assert_null(manager.last_focused_control)


func test_focus_returns_to_the_control_that_was_focused_before_unfocus():
	var manager := _make_manager({"persist_focus": true})
	_button_b.grab_focus()

	manager.unfocus()
	manager.focus()

	assert_eq(_focus_owner(), _button_b)

#endregion


#region parent visibility

func test_showing_the_parent_focuses_it():
	_make_manager({"visible": false})

	_screen.show()

	assert_eq(_focus_owner(), _button_a)


func test_hiding_the_parent_releases_the_focus():
	_make_manager()
	_button_a.grab_focus()

	_screen.hide()

	assert_null(_focus_owner())


func test_hiding_the_parent_remembers_the_focused_control():
	var manager := _make_manager({"persist_focus": true})
	_button_b.grab_focus()

	_screen.hide()

	assert_eq(manager.last_focused_control, _button_b)


func test_showing_the_parent_again_restores_the_focus_it_had():
	_make_manager({"persist_focus": true})
	_button_b.grab_focus()

	_screen.hide()
	_screen.show()

	assert_eq(_focus_owner(), _button_b)

#endregion


#region controller type

func test_switching_to_a_joypad_focuses_when_asked():
	_make_manager({"focus_on_joypad": true})

	InputManager.current_controller_type = InputManager.ControllerTypes.JOYPAD

	assert_eq(_focus_owner(), _button_a)


func test_switching_to_a_joypad_does_nothing_by_default():
	_make_manager({"focus_on_joypad": false})

	InputManager.current_controller_type = InputManager.ControllerTypes.JOYPAD

	assert_null(_focus_owner())


func test_switching_to_the_keyboard_unfocuses_when_asked():
	_make_manager({"unfocus_on_kbm": true})
	InputManager.current_controller_type = InputManager.ControllerTypes.JOYPAD
	_button_a.grab_focus()

	InputManager.current_controller_type = InputManager.ControllerTypes.KBM

	assert_null(_focus_owner())


func test_switching_to_the_keyboard_does_nothing_by_default():
	_make_manager({"unfocus_on_kbm": false})
	InputManager.current_controller_type = InputManager.ControllerTypes.JOYPAD
	_button_a.grab_focus()

	InputManager.current_controller_type = InputManager.ControllerTypes.KBM

	assert_eq(_focus_owner(), _button_a)


func test_a_hidden_parent_does_not_grab_the_focus_on_a_joypad():
	_make_manager({"visible": false, "focus_on_joypad": true})

	InputManager.current_controller_type = InputManager.ControllerTypes.JOYPAD

	assert_null(_focus_owner())


# Every closed screen still hears the controller type change, so a hidden one
# must not release the focus the open screen is holding.
func test_a_hidden_parent_does_not_release_the_focus_on_a_keyboard():
	_make_manager({"visible": false, "unfocus_on_kbm": true})
	InputManager.current_controller_type = InputManager.ControllerTypes.JOYPAD
	_outsider.grab_focus()

	InputManager.current_controller_type = InputManager.ControllerTypes.KBM

	assert_eq(_focus_owner(), _outsider)

#endregion


#region focus sound

func test_the_sound_plays_when_the_focus_moves_inside_the_parent():
	var manager := _make_manager({"sound": true})

	_button_a.grab_focus()

	assert_true(manager.sound_on_focus_change.playing)


func test_the_sound_does_not_play_for_controls_outside_the_parent():
	var manager := _make_manager({"sound": true})

	_outsider.grab_focus()

	assert_false(manager.sound_on_focus_change.playing)


func test_the_sound_does_not_play_while_the_parent_is_hidden():
	var manager := _make_manager({"sound": true, "visible": false})

	_button_a.grab_focus()

	assert_false(manager.sound_on_focus_change.playing)


# Moving through a menu can change the focus more than once in a frame, and the
# clicks would pile up on top of each other. The player is stopped by hand
# because a second play() is what the test is looking for, not a running sound.
func test_the_sound_plays_only_once_per_frame():
	var manager := _make_manager({"sound": true})
	var player:AudioStreamPlayer = manager.sound_on_focus_change

	_button_a.grab_focus()
	player.stop()
	_button_b.grab_focus()

	assert_false(player.playing)


func test_the_sound_plays_again_on_the_next_frame():
	var manager := _make_manager({"sound": true})
	var player:AudioStreamPlayer = manager.sound_on_focus_change

	_button_a.grab_focus()
	await wait_process_frames(2)
	_button_b.grab_focus()

	assert_true(player.playing)


func test_a_focus_change_is_harmless_without_a_sound():
	_make_manager({"sound": false})

	_button_a.grab_focus()

	assert_eq(_focus_owner(), _button_a)


# Showing a screen focuses it, and that focus change is audible: the flag that
# would have silenced it is only raised after focus() has already run.
func test_showing_the_parent_plays_the_focus_sound():
	var manager := _make_manager({"visible": false, "sound": true})

	_screen.show()

	assert_true(manager.sound_on_focus_change.playing)

#endregion
