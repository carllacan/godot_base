extends GutTest

## The typewriter reveals its parent label one character at a time, waiting on a
## real timer in between, so these tests let the engine run. play() runs up to
## its first await synchronously, right after the first character is shown, so
## the tests that only care about how the effect starts call it and read the
## label back without waiting for anything. The ones that care about how long the
## whole effect takes await play() and time it, over texts short enough for the
## wait to be short too.

const SCENE:PackedScene = preload("res://GodotBase/Components/TypewriterEffect/typewriter_effect.tscn")
## Short, and a number of characters a total time divides into cleanly
const TEXT:String = "abcd"
const NUM_CHARS:int = 4
## What visible_characters is on a label nobody has touched
const ALL_SHOWN:int = -1
## Long enough for an effect built with the defaults below to be over
const WAIT_TIME:float = 0.2


## An audio player that counts instead of making noise, which is all these tests
## want to know about the writing sound. It is also set as the script of the
## component's own player, to catch the sound it falls back to.
class SpyPlayer extends AudioStreamPlayer:
	var play_count:int = 0

	# Shadowing play() is the point: the component calls it by name, and the
	# call goes to the script before it goes to the engine.
	@warning_ignore("native_method_override")
	func play(_from_position:float = 0.0)-> void:
		play_count += 1


## Builds a typewriter hanging from the label it writes out, which is how it is
## used in the game's scenes. It comes from the scene rather than from new() so
## that it has its default sound player, and everything is set before the label
## enters the tree, because entering the tree is when the triggers are wired up.
## The effect is instant unless a test asks for a slower one.
func _make_typewriter(opts:Dictionary = {})-> TypewriterEffect:
	var label := RichTextLabel.new()
	label.text = opts.get("text", TEXT)
	label.visible = opts.get("visible", true)

	var typewriter:TypewriterEffect = SCENE.instantiate()
	typewriter.total_time = opts.get("total_time", 0.0)
	typewriter.min_character_time = opts.get("min_character_time", 0.0)
	typewriter.write_sound = opts.get("write_sound", null)
	typewriter.trigger_on_ready = opts.get("trigger_on_ready", false)
	typewriter.trigger_on_shown = opts.get("trigger_on_shown", false)
	typewriter.reset_on_ready = opts.get("reset_on_ready", false)
	typewriter.reset_on_shown = opts.get("reset_on_shown", false)

	label.add_child(typewriter)
	if opts.get("in_tree", true):
		add_child_autofree(label)
	else:
		autofree(label)
	return typewriter


func _label_of(typewriter:TypewriterEffect)-> RichTextLabel:
	return typewriter.get_parent() as RichTextLabel


func _shown(typewriter:TypewriterEffect)-> int:
	return _label_of(typewriter).visible_characters


## Runs a whole effect and reports how long it took, in milliseconds
func _time_play(typewriter:TypewriterEffect, time_s:float = NAN)-> int:
	var start := Time.get_ticks_msec()
	await typewriter.play(time_s)
	return Time.get_ticks_msec() - start


#region what the typewriter is attached to

func test_a_typewriter_under_a_rich_text_label_has_nothing_to_complain_about():
	var typewriter := _make_typewriter()

	assert_true(typewriter._get_configuration_warnings().is_empty())


## The wording comes from BaseComponent now, built out of _is_parent_valid and
## _get_parent_requirement, so it names both what was expected and what it got.
func test_a_typewriter_under_anything_else_complains():
	var parent := Node.new()
	var typewriter:TypewriterEffect = SCENE.instantiate()
	parent.add_child(typewriter)
	add_child_autofree(parent)

	var warnings := typewriter._get_configuration_warnings()
	assert_eq(warnings.size(), 1)
	assert_string_contains(warnings[0], "a RichTextLabel", "names the requirement")
	assert_string_contains(warnings[0], "Node", "names what it actually got")
	assert_push_error("cannot be attached to a Node")

#endregion


#region resetting

func test_resetting_hides_every_character():
	var typewriter := _make_typewriter()

	typewriter.reset()

	assert_eq(_shown(typewriter), 0)


func test_resetting_does_nothing_before_the_typewriter_is_in_the_tree():
	var typewriter := _make_typewriter({"in_tree": false})
	_label_of(typewriter).visible_characters = 2

	typewriter.reset()

	assert_eq(_shown(typewriter), 2)

#endregion


#region writing the text out

func test_playing_shows_every_character():
	var typewriter := _make_typewriter()

	await typewriter.play()

	assert_eq(_shown(typewriter), NUM_CHARS)


func test_playing_starts_over_from_a_blank_label():
	var typewriter := _make_typewriter()
	_label_of(typewriter).visible_characters = 3

	typewriter.play()
	var shown_at_the_start := _shown(typewriter)
	await wait_seconds(WAIT_TIME)

	assert_eq(shown_at_the_start, 1, "the label should have been blanked before the first character")


func test_playing_does_nothing_before_the_typewriter_is_in_the_tree():
	var typewriter := _make_typewriter({"in_tree": false})
	_label_of(typewriter).visible_characters = 2

	await typewriter.play()

	assert_eq(_shown(typewriter), 2)


func test_a_label_with_no_text_is_left_blank():
	var typewriter := _make_typewriter({"text": ""})

	await typewriter.play()

	assert_eq(_shown(typewriter), 0)

#endregion


#region how long the effect takes

func test_the_total_time_paces_the_whole_effect():
	var typewriter := _make_typewriter({"total_time": 0.4})

	var elapsed:int = await _time_play(typewriter)

	assert_between(elapsed, 350, 900)


func test_the_minimum_character_time_holds_a_fast_effect_back():
	var typewriter := _make_typewriter({"total_time": 0.0, "min_character_time": 0.1})

	var elapsed:int = await _time_play(typewriter)

	assert_between(elapsed, 350, 900)


func test_a_zero_total_time_with_no_minimum_is_as_fast_as_the_frames_allow():
	var typewriter := _make_typewriter({"total_time": 0.0, "min_character_time": 0.0})

	var elapsed:int = await _time_play(typewriter)

	assert_lt(elapsed, 300)


# play() takes the time to spend on the effect as an argument, but paces itself
# with total_time whatever it is given: the argument is worked out and then never
# used. This pins down what play() does today, not what its argument promises.
func test_the_time_given_to_play_is_ignored():
	var typewriter := _make_typewriter({"total_time": 0.4})

	var elapsed:int = await _time_play(typewriter, 0.0)

	assert_between(elapsed, 350, 900, "should take the total time, not the time it was given")

#endregion


#region the writing sound

func test_every_character_makes_a_sound():
	var spy:SpyPlayer = autofree(SpyPlayer.new())
	var typewriter := _make_typewriter({"write_sound": spy})

	await typewriter.play()

	assert_eq(spy.play_count, NUM_CHARS)


func test_a_typewriter_without_a_sound_of_its_own_falls_back_to_the_default_one():
	var typewriter := _make_typewriter()
	var default_player := typewriter.get_node("DefaultClickPlayer")
	default_player.set_script(SpyPlayer)

	await typewriter.play()

	assert_eq(default_player.play_count, NUM_CHARS)

#endregion


#region what starts the effect

func test_a_typewriter_with_no_triggers_leaves_the_label_alone():
	var typewriter := _make_typewriter()

	await wait_seconds(WAIT_TIME)

	assert_eq(_shown(typewriter), ALL_SHOWN)


func test_a_typewriter_that_triggers_on_ready_writes_the_text_out():
	var typewriter := _make_typewriter({"trigger_on_ready": true})

	await wait_seconds(WAIT_TIME)

	assert_eq(_shown(typewriter), NUM_CHARS)


func test_resetting_on_ready_blanks_the_label_as_soon_as_it_is_in_the_tree():
	var typewriter := _make_typewriter({"reset_on_ready": true})

	assert_eq(_shown(typewriter), 0)


func test_resetting_on_ready_does_not_write_the_text_out_by_itself():
	var typewriter := _make_typewriter({"reset_on_ready": true})

	await wait_seconds(WAIT_TIME)

	assert_eq(_shown(typewriter), 0)


func test_a_typewriter_that_triggers_on_shown_stays_quiet_while_its_parent_is_hidden():
	var typewriter := _make_typewriter({"trigger_on_shown": true, "visible": false})

	await wait_seconds(WAIT_TIME)

	assert_eq(_shown(typewriter), ALL_SHOWN)


func test_a_typewriter_that_triggers_on_shown_writes_the_text_out_when_its_parent_is_shown():
	var typewriter := _make_typewriter({"trigger_on_shown": true, "visible": false})

	_label_of(typewriter).show()
	await wait_seconds(WAIT_TIME)

	assert_eq(_shown(typewriter), NUM_CHARS)


# The trigger is the parent's visibility changing, not the parent becoming
# visible, so hiding the label sets the effect off just the same.
func test_hiding_the_parent_also_writes_the_text_out():
	var typewriter := _make_typewriter({"trigger_on_shown": true, "visible": true})

	_label_of(typewriter).hide()
	await wait_seconds(WAIT_TIME)

	assert_eq(_shown(typewriter), NUM_CHARS)


# reset_on_shown is only ever acted on from the visibility handler, and that
# handler is only connected when trigger_on_shown is set, so a typewriter that
# is told to reset on shown and nothing else never hears about its parent being
# shown at all. This pins down what the flag does today, not what it promises.
func test_resetting_on_shown_does_nothing_without_the_shown_trigger():
	var typewriter := _make_typewriter({"reset_on_shown": true, "visible": false})

	_label_of(typewriter).show()

	assert_eq(_shown(typewriter), ALL_SHOWN, "the label should have been left alone")


func test_the_ready_trigger_and_the_shown_trigger_are_independent():
	var typewriter := _make_typewriter({"trigger_on_shown": true, "reset_on_ready": true})

	await wait_seconds(WAIT_TIME)

	assert_eq(_shown(typewriter), 0, "the shown trigger should not have fired on ready")

#endregion
