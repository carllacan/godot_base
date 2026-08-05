extends GutTest

## The runner is a PropertyAnimator, so these tests drive it the same way that
## component's own tests do: physics processing is turned off so the engine
## cannot tick a node mid-test, and the tests set cycle_time and call
## update_property() themselves. The few that check the engine really drives the
## sprite turn processing back on and pick a short period to wait on.

const DELTA:float = 0.0001


## Builds a sprite with a runner under it and puts it in the tree, which is what
## makes the sprite emit "ready" and the runner configure itself from the sheet.
func _make_runner(opts:Dictionary = {})-> SpritesheetRunner:
	var sprite := Sprite2D.new()
	sprite.hframes = opts.get("hframes", 4)
	sprite.vframes = opts.get("vframes", 1)

	var runner := SpritesheetRunner.new()
	runner.period = opts.get("period", 1.0)
	runner.frame_start = opts.get("frame_start", 0)
	runner.frame_end = opts.get("frame_end", -1)

	sprite.add_child(runner)
	add_child_autofree(sprite)
	if not opts.get("driven_by_engine", false):
		runner.set_physics_process(false)
	return runner


## The frame the sprite shows at a given point of the run, as a fraction of the
## period, so the configured duration does not matter here.
func _frame_at(runner:SpritesheetRunner, phase:float)-> int:
	runner.cycle_time = phase * runner.period
	runner.update_property()
	return (runner.get_target() as Sprite2D).frame


#region reading the sheet

func test_the_sheet_length_comes_from_the_sprite():
	var runner := _make_runner({"hframes": 6})

	assert_eq(runner.get_frame_count(), 6)


## Sprite2D.frame indexes the whole grid row by row, so a sheet with rows is as
## long as its two dimensions multiplied.
func test_a_sheet_with_rows_counts_both_axes():
	var runner := _make_runner({"hframes": 8, "vframes": 2})

	assert_eq(runner.get_frame_count(), 16)


func test_the_run_covers_the_whole_sheet_by_default():
	var runner := _make_runner({"hframes": 8, "vframes": 2})

	assert_eq(runner.get_first_frame(), 0)
	assert_eq(runner.get_last_frame(), 15)


func test_the_animator_is_configured_from_the_sheet():
	var runner := _make_runner({"hframes": 4})

	assert_eq(runner.property, "frame")
	assert_eq(runner.mode, PropertyAnimator.Mode.RESTART)
	assert_eq(runner.steps, 4, "one step per frame")
	assert_false(runner.loop, "a sheet is run once, not looped")

#endregion


#region the frames shown

func test_the_sprite_starts_on_the_first_frame():
	var runner := _make_runner({"hframes": 4})

	assert_eq(_frame_at(runner, 0.0), 0)


func test_the_sprite_ends_on_the_last_frame():
	var runner := _make_runner({"hframes": 4})

	assert_eq(_frame_at(runner, 1.0), 3)


func test_every_frame_gets_the_same_share_of_the_run():
	var runner := _make_runner({"hframes": 4})

	assert_eq(_frame_at(runner, 0.1), 0)
	assert_eq(_frame_at(runner, 0.3), 1)
	assert_eq(_frame_at(runner, 0.6), 2)
	assert_eq(_frame_at(runner, 0.9), 3)


## Every frame of a two-row sheet has to be reachable, not just the first row.
func test_a_sheet_with_rows_runs_through_its_second_row_too():
	var runner := _make_runner({"hframes": 4, "vframes": 2})

	assert_eq(_frame_at(runner, 0.0), 0)
	assert_eq(_frame_at(runner, 0.5), 4)
	assert_eq(_frame_at(runner, 1.0), 7)


func test_a_single_frame_sheet_just_shows_its_one_frame():
	var runner := _make_runner({"hframes": 1})

	assert_eq(_frame_at(runner, 0.0), 0)
	assert_eq(_frame_at(runner, 1.0), 0)


## Frames are whole numbers, so a value that interpolates to just under the next
## frame has to round up to it rather than being truncated back down.
func test_no_frame_is_skipped_across_an_awkward_sheet_length():
	var runner := _make_runner({"hframes": 7})

	var seen:Array[int] = []
	for i in 200:
		var f:int = _frame_at(runner, i/200.0)
		if f not in seen: seen.append(f)

	seen.sort()
	assert_eq(seen, [0, 1, 2, 3, 4, 5, 6] as Array[int])

#endregion


#region running part of a sheet

func test_a_frame_range_narrows_the_run():
	var runner := _make_runner({
		"hframes": 8, "vframes": 2, "frame_start": 8, "frame_end": 15})

	assert_eq(runner.get_first_frame(), 8)
	assert_eq(runner.get_last_frame(), 15)
	assert_eq(runner.steps, 8)


func test_a_narrowed_run_stays_inside_its_range():
	var runner := _make_runner({
		"hframes": 8, "vframes": 2, "frame_start": 8, "frame_end": 15})

	assert_eq(_frame_at(runner, 0.0), 8)
	assert_eq(_frame_at(runner, 1.0), 15)


func test_a_frame_end_past_the_sheet_is_clamped_to_it():
	var runner := _make_runner({"hframes": 4, "frame_end": 99})

	assert_eq(runner.get_last_frame(), 3)


func test_a_frame_start_past_the_end_is_clamped_to_it():
	var runner := _make_runner({"hframes": 4, "frame_start": 99})

	assert_eq(runner.get_first_frame(), 3)


func test_changing_the_range_reconfigures_the_run():
	var runner := _make_runner({"hframes": 8})

	runner.frame_start = 4

	assert_eq(runner.steps, 4)
	assert_eq(_frame_at(runner, 0.0), 4)

#endregion


#region playing

func test_the_sheet_starts_playing_when_the_sprite_is_ready():
	var runner := _make_runner()

	assert_eq(runner.state, PropertyAnimator.State.PLAYING)


func test_an_offset_delays_the_start():
	var runner := _make_runner()
	runner.stop()

	runner.play_entire_sheet(0.2)

	assert_eq(runner.state, PropertyAnimator.State.STOPPED,
		"the offset has not passed yet")

	await wait_seconds(0.4)

	assert_eq(runner.state, PropertyAnimator.State.PLAYING)

#endregion


#region the engine driving it

func test_the_sprite_advances_on_its_own():
	var runner := _make_runner({"period": 0.4, "driven_by_engine": true})
	var sprite := runner.get_target() as Sprite2D

	await wait_seconds(0.25)

	assert_gt(sprite.frame, 0)


## The sheet is run once rather than looped, so what is left on screen when it is
## over is the last frame, not a snap back to the first.
func test_the_sheet_stops_on_the_last_frame_instead_of_looping():
	var runner := _make_runner({"period": 0.2, "driven_by_engine": true})
	var sprite := runner.get_target() as Sprite2D

	await wait_seconds(0.5)

	assert_eq(runner.state, PropertyAnimator.State.STOPPED)
	assert_eq(sprite.frame, 3)

#endregion


#region what it is attached to

func test_a_runner_under_a_sprite_has_nothing_to_complain_about():
	var runner := _make_runner()

	assert_true(runner._get_configuration_warnings().is_empty())


func test_a_runner_under_anything_else_complains():
	var parent := Node2D.new()
	var runner := SpritesheetRunner.new()
	parent.add_child(runner)
	add_child_autofree(parent)

	var warnings := runner._get_configuration_warnings()
	assert_eq(warnings.size(), 1)
	assert_string_contains(warnings[0], "a Sprite2D")
	assert_push_error("cannot be attached to a Node2D")

#endregion
