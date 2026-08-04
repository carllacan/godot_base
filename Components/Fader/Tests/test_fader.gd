extends GutTest

## The fader is driven by hand in these tests: _make_fader turns processing off
## so the engine cannot tick a fader in the middle of a test, and the tests call
## _process(delta) themselves. The one test that checks the engine really drives
## the fader turns processing back on.

const DELTA:float = 0.001


## Builds a fader hanging from the node it fades, which is how it is used in the
## game's scenes. The parent's alpha is set before the fader enters the tree
## because that is the alpha the fader takes as its visible one.
func _make_fader(opts:Dictionary = {})-> FaderComponent:
	var parent := Node2D.new()
	parent.modulate.a = opts.get("alpha", 1.0)

	var fader := FaderComponent.new()
	fader.initial_state = opts.get("initial_state", FaderComponent.States.INVISIBLE)
	fader.invisible_time = opts.get("invisible_time", 3.0)
	fader.visible_time = opts.get("visible_time", 3.0)
	fader.transition_time = opts.get("transition_time", 1.0)
	fader.autostart = opts.get("autostart", false)

	parent.add_child(fader)
	add_child_autofree(parent)
	fader.set_process(false)
	return fader


func _alpha(fader:FaderComponent)-> float:
	return fader.get_parent().modulate.a


#region ready

func test_a_fader_starting_invisible_hides_its_parent():
	var fader := _make_fader({"initial_state": FaderComponent.States.INVISIBLE})

	assert_eq(fader.state, FaderComponent.States.INVISIBLE)
	assert_almost_eq(_alpha(fader), 0.0, DELTA)
	assert_almost_eq(fader.time_left, 3.0, DELTA)


func test_a_fader_starting_visible_leaves_its_parent_alone():
	var fader := _make_fader({"initial_state": FaderComponent.States.VISIBLE, "alpha": 0.8})

	assert_eq(fader.state, FaderComponent.States.VISIBLE)
	assert_almost_eq(_alpha(fader), 0.8, DELTA)
	assert_almost_eq(fader.time_left, 3.0, DELTA)


func test_a_fader_can_start_in_the_middle_of_a_fade_in():
	var fader := _make_fader({
		"initial_state": FaderComponent.States.FADING_IN,
		"transition_time": 2.0,
	})

	assert_eq(fader.state, FaderComponent.States.FADING_IN)
	assert_almost_eq(fader.time_left, 2.0, DELTA)


func test_a_fader_can_start_in_the_middle_of_a_fade_out():
	var fader := _make_fader({
		"initial_state": FaderComponent.States.FADING_OUT,
		"transition_time": 2.0,
	})

	assert_eq(fader.state, FaderComponent.States.FADING_OUT)
	assert_almost_eq(fader.time_left, 2.0, DELTA)


func test_the_parents_alpha_is_remembered_as_the_visible_one():
	var fader := _make_fader({"initial_state": FaderComponent.States.INVISIBLE, "alpha": 0.5})

	assert_almost_eq(fader.original_alpha, 0.5, DELTA)


func test_autostart_activates_the_fader():
	var fader := _make_fader({"autostart": true})

	assert_true(fader.is_active)


func test_without_autostart_the_fader_stays_inactive():
	var fader := _make_fader({"autostart": false})

	assert_false(fader.is_active)


# Activation happens before the initial state is applied, so an autostarted
# fader does not fade in right away: it waits out its first period instead.
func test_autostarting_does_not_skip_the_initial_period():
	var fader := _make_fader({
		"autostart": true,
		"initial_state": FaderComponent.States.INVISIBLE,
		"invisible_time": 3.0,
	})

	assert_eq(fader.state, FaderComponent.States.INVISIBLE)
	assert_almost_eq(fader.time_left, 3.0, DELTA)

#endregion


#region activation

func test_activating_an_invisible_fader_starts_the_fade_in():
	var fader := _make_fader({
		"initial_state": FaderComponent.States.INVISIBLE,
		"transition_time": 2.0,
	})

	fader.is_active = true

	assert_eq(fader.state, FaderComponent.States.FADING_IN)
	assert_almost_eq(fader.time_left, 2.0, DELTA)


func test_deactivating_a_visible_fader_starts_the_fade_out():
	var fader := _make_fader({
		"initial_state": FaderComponent.States.VISIBLE,
		"transition_time": 2.0,
	})
	fader.is_active = true

	fader.is_active = false

	assert_eq(fader.state, FaderComponent.States.FADING_OUT)
	assert_almost_eq(fader.time_left, 2.0, DELTA)


func test_activating_a_visible_fader_changes_nothing():
	var fader := _make_fader({"initial_state": FaderComponent.States.VISIBLE})

	fader.is_active = true

	assert_eq(fader.state, FaderComponent.States.VISIBLE)
	assert_almost_eq(fader.time_left, 3.0, DELTA)


func test_deactivating_an_inactive_fader_changes_nothing():
	var fader := _make_fader({"initial_state": FaderComponent.States.INVISIBLE})

	fader.is_active = false

	assert_eq(fader.state, FaderComponent.States.INVISIBLE)
	assert_almost_eq(fader.time_left, 3.0, DELTA)


# Fades are not interruptible: a fader deactivated while it is fading in keeps
# fading in, and only fades out once the visible period after it is over.
func test_deactivating_a_fader_that_is_fading_in_lets_the_fade_finish():
	var fader := _make_fader({"initial_state": FaderComponent.States.FADING_IN})
	fader.is_active = true

	fader.is_active = false

	assert_eq(fader.state, FaderComponent.States.FADING_IN)


func test_activating_a_fader_that_is_fading_out_lets_the_fade_finish():
	var fader := _make_fader({"initial_state": FaderComponent.States.FADING_OUT})

	fader.is_active = true

	assert_eq(fader.state, FaderComponent.States.FADING_OUT)

#endregion


#region starting periods

func test_a_fade_in_can_only_start_while_invisible():
	var fader := _make_fader({"initial_state": FaderComponent.States.VISIBLE})

	fader.start_fading_in()

	assert_eq(fader.state, FaderComponent.States.VISIBLE)
	assert_almost_eq(fader.time_left, 3.0, DELTA)


func test_a_fade_out_can_only_start_while_visible():
	var fader := _make_fader({"initial_state": FaderComponent.States.INVISIBLE})

	fader.start_fading_out()

	assert_eq(fader.state, FaderComponent.States.INVISIBLE)
	assert_almost_eq(fader.time_left, 3.0, DELTA)


func test_the_visible_period_lasts_the_visible_time():
	var fader := _make_fader({"initial_state": FaderComponent.States.INVISIBLE, "visible_time": 5.0})

	fader.start_visible_period()

	assert_eq(fader.state, FaderComponent.States.VISIBLE)
	assert_almost_eq(fader.time_left, 5.0, DELTA)


func test_the_invisible_period_lasts_the_invisible_time():
	var fader := _make_fader({
		"initial_state": FaderComponent.States.VISIBLE,
		"invisible_time": 5.0,
	})

	fader.start_invisible_period()

	assert_eq(fader.state, FaderComponent.States.INVISIBLE)
	assert_almost_eq(fader.time_left, 5.0, DELTA)

#endregion


#region fading

func test_fading_in_raises_the_alpha():
	var fader := _make_fader({
		"initial_state": FaderComponent.States.FADING_IN,
		"transition_time": 1.0,
	})

	fader._process(0.25)

	assert_almost_eq(_alpha(fader), 0.25, DELTA)
	assert_almost_eq(fader.time_left, 0.75, DELTA)


func test_fading_in_only_goes_up_to_the_parents_own_alpha():
	var fader := _make_fader({
		"initial_state": FaderComponent.States.FADING_IN,
		"transition_time": 1.0,
		"alpha": 0.5,
	})

	fader._process(0.5)

	assert_almost_eq(_alpha(fader), 0.25, DELTA)


func test_fading_out_lowers_the_alpha():
	var fader := _make_fader({
		"initial_state": FaderComponent.States.FADING_OUT,
		"transition_time": 1.0,
	})

	fader._process(0.25)

	assert_almost_eq(_alpha(fader), 0.75, DELTA)
	assert_almost_eq(fader.time_left, 0.75, DELTA)


func test_fading_out_starts_from_the_parents_own_alpha():
	var fader := _make_fader({
		"initial_state": FaderComponent.States.FADING_OUT,
		"transition_time": 1.0,
		"alpha": 0.5,
	})

	fader._process(0.5)

	assert_almost_eq(_alpha(fader), 0.25, DELTA)


func test_the_transition_time_scales_the_fade():
	var fader := _make_fader({
		"initial_state": FaderComponent.States.FADING_IN,
		"transition_time": 4.0,
	})

	fader._process(1.0)

	assert_almost_eq(_alpha(fader), 0.25, DELTA)

#endregion


#region period changes

func test_a_finished_fade_in_opens_the_visible_period():
	var fader := _make_fader({
		"initial_state": FaderComponent.States.FADING_IN,
		"transition_time": 1.0,
		"visible_time": 5.0,
		"alpha": 0.5,
	})

	fader._process(1.0)

	assert_eq(fader.state, FaderComponent.States.VISIBLE)
	assert_almost_eq(fader.time_left, 5.0, DELTA)
	assert_almost_eq(_alpha(fader), 0.5, DELTA)


func test_a_finished_fade_out_opens_the_invisible_period():
	var fader := _make_fader({
		"initial_state": FaderComponent.States.FADING_OUT,
		"transition_time": 1.0,
		"invisible_time": 5.0,
	})

	fader._process(1.0)

	assert_eq(fader.state, FaderComponent.States.INVISIBLE)
	assert_almost_eq(fader.time_left, 5.0, DELTA)
	assert_almost_eq(_alpha(fader), 0.0, DELTA)


func test_an_active_fader_fades_in_when_the_invisible_period_is_over():
	var fader := _make_fader({
		"autostart": true,
		"initial_state": FaderComponent.States.INVISIBLE,
		"invisible_time": 1.0,
		"transition_time": 2.0,
	})

	fader._process(1.0)

	assert_eq(fader.state, FaderComponent.States.FADING_IN)
	assert_almost_eq(fader.time_left, 2.0, DELTA)


func test_an_active_fader_fades_out_when_the_visible_period_is_over():
	var fader := _make_fader({
		"autostart": true,
		"initial_state": FaderComponent.States.VISIBLE,
		"visible_time": 1.0,
		"transition_time": 2.0,
	})

	fader._process(1.0)

	assert_eq(fader.state, FaderComponent.States.FADING_OUT)
	assert_almost_eq(fader.time_left, 2.0, DELTA)


func test_an_inactive_fader_stays_invisible_when_the_period_is_over():
	var fader := _make_fader({
		"autostart": false,
		"initial_state": FaderComponent.States.INVISIBLE,
		"invisible_time": 1.0,
	})

	fader._process(1.0)
	fader._process(1.0)

	assert_eq(fader.state, FaderComponent.States.INVISIBLE)
	assert_almost_eq(_alpha(fader), 0.0, DELTA)


func test_an_inactive_fader_stays_visible_when_the_period_is_over():
	var fader := _make_fader({
		"autostart": false,
		"initial_state": FaderComponent.States.VISIBLE,
		"visible_time": 1.0,
		"alpha": 0.5,
	})

	fader._process(1.0)
	fader._process(1.0)

	assert_eq(fader.state, FaderComponent.States.VISIBLE)
	assert_almost_eq(_alpha(fader), 0.5, DELTA)


func test_an_active_fader_cycles_through_all_its_periods():
	var fader := _make_fader({
		"autostart": true,
		"initial_state": FaderComponent.States.INVISIBLE,
		"invisible_time": 1.0,
		"visible_time": 1.0,
		"transition_time": 1.0,
	})

	fader._process(1.0)
	assert_eq(fader.state, FaderComponent.States.FADING_IN, "the invisible period is over")

	fader._process(1.0)
	assert_eq(fader.state, FaderComponent.States.VISIBLE, "the fade in is over")

	fader._process(1.0)
	assert_eq(fader.state, FaderComponent.States.FADING_OUT, "the visible period is over")

	fader._process(1.0)
	assert_eq(fader.state, FaderComponent.States.INVISIBLE, "the fade out is over")

	fader._process(1.0)
	assert_eq(fader.state, FaderComponent.States.FADING_IN, "the cycle starts again")

#endregion


#region processing

# A fader that is not in the tree yet has no state to run, so it does nothing
func test_a_fader_without_a_state_is_not_processed():
	var fader:FaderComponent = autofree(FaderComponent.new())

	fader._process(1.0)

	assert_true(is_nan(fader.time_left))


func test_the_engine_drives_a_fading_fader():
	var fader := _make_fader({
		"initial_state": FaderComponent.States.FADING_IN,
		"transition_time": 10.0,
	})

	fader.set_process(true)
	await wait_process_frames(2)

	assert_lt(fader.time_left, 10.0)
	assert_gt(_alpha(fader), 0.0)

#endregion
