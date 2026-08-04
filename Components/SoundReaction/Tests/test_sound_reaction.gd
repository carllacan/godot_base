extends GutTest

## The component is watched through a real AudioStreamPlayer instead of a spy.
## A spy is not possible here: play() is a native method, so the engine calls it
## directly and a GDScript override is never reached. What the tests look at is
## is_playing(), which means every player needs something to play, hence the
## second of silence _silence builds.

## Names of the InputMap actions the action tests use. They are registered in
## before_all so the tests do not depend on the project's own actions, and they
## stay unbound because the tests feed the component InputEventActions rather
## than key presses.
const ACTION:String = "test_sound_reaction_action"
const OTHER_ACTION:String = "test_sound_reaction_other_action"


func before_all()-> void:
	for action in [ACTION, OTHER_ACTION]:
		if not InputMap.has_action(action):
			InputMap.add_action(action)


func after_all()-> void:
	for action in [ACTION, OTHER_ACTION]:
		if InputMap.has_action(action):
			InputMap.erase_action(action)


## A second of silence, so a player has a stream to report as playing
func _silence()-> AudioStreamWAV:
	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_8_BITS
	stream.mix_rate = 8000
	var data := PackedByteArray()
	data.resize(8000)
	stream.data = data
	return stream


## Builds the component under the button it reacts to, next to the player it
## drives, which is how it is used in the game's scenes. The exports are set
## before the button enters the tree, so the component is configured by the time
## the button emits "ready", like a scene loading its properties.
func _make_reaction(opts:Dictionary = {})-> SoundReaction:
	var button := Button.new()
	button.visible = opts.get("visible", true)

	var reaction := SoundReaction.new()
	reaction.target_signals = opts.get("target_signals", ["pressed"] as Array[String])
	reaction.target_actions = opts.get("target_actions", [] as Array[String])
	reaction.enabled = opts.get("enabled", true)

	if opts.get("with_sound", true):
		var sound := AudioStreamPlayer.new()
		sound.stream = _silence()
		button.add_child(sound)
		reaction.target_sound = sound

	button.add_child(reaction)
	add_child_autofree(button)
	return reaction


func _button(reaction:SoundReaction)-> Button:
	return reaction.get_parent() as Button


func _sound(reaction:SoundReaction)-> AudioStreamPlayer:
	return reaction.target_sound


## The event an action bound to anything at all would produce once pressed
func _action_event(action:String, pressed:bool = true)-> InputEventAction:
	var event := InputEventAction.new()
	event.action = action
	event.pressed = pressed
	return event


#region the assumptions the tests are built on

## The parent's visibility gates the action handling, so the tests would be
## meaningless if what they build were hidden to begin with.
func test_a_button_the_tests_build_is_visible_in_tree():
	var reaction := _make_reaction()

	assert_true(_button(reaction).is_visible_in_tree())


## is_playing is how every test below sees a sound happen, so it has to react to
## a play() on the kind of player the tests build.
func test_a_player_the_tests_build_reports_itself_as_playing():
	var reaction := _make_reaction()

	assert_false(_sound(reaction).is_playing(), "nothing has played yet")

	_sound(reaction).play()

	assert_true(_sound(reaction).is_playing())

#endregion


#region wiring

func test_the_component_listens_to_its_target_signal():
	var reaction := _make_reaction({"target_signals": ["pressed"] as Array[String]})

	assert_true(_button(reaction).pressed.is_connected(reaction.play_target_sound))


func test_all_the_target_signals_are_listened_to():
	var reaction := _make_reaction({
		"target_signals": ["pressed", "button_up", "button_down"] as Array[String],
	})
	var button := _button(reaction)

	assert_true(button.pressed.is_connected(reaction.play_target_sound), "pressed")
	assert_true(button.button_up.is_connected(reaction.play_target_sound), "button_up")
	assert_true(button.button_down.is_connected(reaction.play_target_sound), "button_down")


## A signal the parent does not have is a configuration mistake, and the
## component warns about it rather than erroring out, so the signals around it
## are still wired up.
func test_a_signal_the_parent_does_not_have_is_skipped():
	var reaction := _make_reaction({
		"target_signals": ["not_a_signal", "pressed"] as Array[String],
	})

	assert_false(_button(reaction).has_signal("not_a_signal"))
	assert_true(_button(reaction).pressed.is_connected(reaction.play_target_sound))


## The doc comment on the component promises "pressed" as the default, but the
## fallback in get_target_signals only fires when target_signals is null, which
## a typed Array export never is: unconfigured means an empty array, and an
## unconfigured component listens to nothing.
func test_a_component_with_no_target_signals_listens_to_nothing():
	var reaction := _make_reaction({"target_signals": [] as Array[String]})

	assert_eq(reaction.get_target_signals(), [] as Array[String])
	assert_false(_button(reaction).pressed.is_connected(reaction.play_target_sound))


## The component waits for its parent to be ready before listening, so a button
## that has not entered the tree yet is not hooked up.
func test_a_parent_that_is_not_ready_yet_is_not_listened_to():
	var button:Button = autofree(Button.new())
	var reaction := SoundReaction.new()
	reaction.target_signals = ["pressed"] as Array[String]
	button.add_child(reaction)

	assert_false(button.pressed.is_connected(reaction.play_target_sound))


## The parent emits "ready" once, so a component added to a button that is
## already in the tree never gets to listen to it. Components have to be part of
## the scene, or added before it, to do anything.
func test_a_component_added_to_a_ready_parent_never_listens():
	var button:Button = autofree(Button.new())
	add_child_autofree(button)

	var reaction := SoundReaction.new()
	reaction.target_signals = ["pressed"] as Array[String]
	button.add_child(reaction)

	assert_false(button.pressed.is_connected(reaction.play_target_sound))


## A missing sound is warned about but does not stop the wiring, so a player
## assigned later is heard from the next press on.
func test_a_component_without_a_sound_still_listens():
	var reaction := _make_reaction({"with_sound": false})

	assert_true(_button(reaction).pressed.is_connected(reaction.play_target_sound))

#endregion


#region playing on a signal

func test_the_target_signal_plays_the_sound():
	var reaction := _make_reaction({"target_signals": ["pressed"] as Array[String]})

	_button(reaction).pressed.emit()

	assert_true(_sound(reaction).is_playing())


## Nothing about the component is one-shot: it plays on every emission, even one
## that lands while the sound from the previous one is still going.
func test_the_sound_plays_again_on_a_second_emission():
	var reaction := _make_reaction({"target_signals": ["pressed"] as Array[String]})

	_button(reaction).pressed.emit()
	_sound(reaction).stop()
	_button(reaction).pressed.emit()

	assert_true(_sound(reaction).is_playing())


func test_any_of_the_target_signals_plays_the_sound():
	var reaction := _make_reaction({
		"target_signals": ["button_up", "button_down"] as Array[String],
	})

	_button(reaction).button_down.emit()
	assert_true(_sound(reaction).is_playing(), "button_down played")

	_sound(reaction).stop()

	_button(reaction).button_up.emit()
	assert_true(_sound(reaction).is_playing(), "button_up played")


func test_a_disabled_component_does_not_play():
	var reaction := _make_reaction({"enabled": false})

	_button(reaction).pressed.emit()

	assert_false(_sound(reaction).is_playing())


## Disabling is a mute, not an unhooking: the signals stay connected, so the
## component is heard again as soon as it is enabled.
func test_a_component_that_is_enabled_again_plays():
	var reaction := _make_reaction({"enabled": false})
	_button(reaction).pressed.emit()

	reaction.enabled = true
	_button(reaction).pressed.emit()

	assert_true(_sound(reaction).is_playing())


## A component whose sound was never assigned is a configuration mistake, and it
## warns about it, but a press must not bring the game down.
func test_a_component_without_a_sound_survives_a_press():
	var reaction := _make_reaction({"with_sound": false})

	_button(reaction).pressed.emit()

	pass_test("the missing sound did not stop the component")

#endregion


#region playing on an action

func test_a_target_action_plays_the_sound():
	var reaction := _make_reaction({"target_actions": [ACTION] as Array[String]})

	reaction._input(_action_event(ACTION))

	assert_true(_sound(reaction).is_playing())


func test_an_action_that_is_not_a_target_does_not_play():
	var reaction := _make_reaction({"target_actions": [ACTION] as Array[String]})

	reaction._input(_action_event(OTHER_ACTION))

	assert_false(_sound(reaction).is_playing())


func test_any_of_the_target_actions_plays_the_sound():
	var reaction := _make_reaction({
		"target_actions": [ACTION, OTHER_ACTION] as Array[String],
	})

	reaction._input(_action_event(ACTION))
	assert_true(_sound(reaction).is_playing(), "the first action played")

	_sound(reaction).stop()

	reaction._input(_action_event(OTHER_ACTION))
	assert_true(_sound(reaction).is_playing(), "the second action played")


## The sound belongs to the press, so letting the key go does not play it again.
func test_a_released_action_does_not_play():
	var reaction := _make_reaction({"target_actions": [ACTION] as Array[String]})

	reaction._input(_action_event(ACTION, false))

	assert_false(_sound(reaction).is_playing())


func test_a_component_with_no_target_actions_ignores_input():
	var reaction := _make_reaction({"target_actions": [] as Array[String]})

	reaction._input(_action_event(ACTION))

	assert_false(_sound(reaction).is_playing())


## Input is global, so a component in a screen that is not on show would answer
## for a button the player cannot see. The parent's visibility is what keeps
## hidden menus quiet.
func test_a_hidden_parent_silences_the_actions():
	var reaction := _make_reaction({
		"target_actions": [ACTION] as Array[String],
		"visible": false,
	})

	reaction._input(_action_event(ACTION))

	assert_false(_sound(reaction).is_playing())


func test_a_disabled_component_ignores_its_actions():
	var reaction := _make_reaction({
		"target_actions": [ACTION] as Array[String],
		"enabled": false,
	})

	reaction._input(_action_event(ACTION))

	assert_false(_sound(reaction).is_playing())


## The tests above call _input by hand; this one checks the engine really routes
## input to the component, which is what makes the actions work in the game.
func test_the_engine_routes_input_to_the_component():
	var reaction := _make_reaction({"target_actions": [ACTION] as Array[String]})

	get_tree().root.push_input(_action_event(ACTION))

	assert_true(_sound(reaction).is_playing())

#endregion
