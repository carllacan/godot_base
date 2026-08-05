extends GutTest

## The animator is driven by hand in these tests: _make_animator turns physics
## processing off so the engine cannot tick a node in the middle of a test, and
## the tests call _physics_process(delta) themselves. The one test that checks
## the engine really drives the node turns processing back on.

const DELTA:float = 0.001


## Builds an animator hanging from the node it animates, which is how it is used
## in the game's scenes. The animated node is wrapped in a holder so tests can
## hide it from above.
func _make_animator(opts:Dictionary = {})-> PropertyAnimator:
	var holder := Node2D.new()
	var parent := Node2D.new()
	holder.add_child(parent)

	var animator := PropertyAnimator.new()
	animator.target_override = opts.get("target", null)
	animator.property = opts.get("property", "rotation")
	animator.mode = opts.get("mode", PropertyAnimator.Mode.PERIODIC)
	animator.period = opts.get("period", 1.0)
	animator.pause_between_cycles = opts.get("pause_between_cycles", 0.0)
	animator.autostart = opts.get("autostart", true)
	animator.min_value = opts.get("min_value", 0.0)
	animator.max_value = opts.get("max_value", 10.0)
	animator.value_offset = opts.get("value_offset", null)
	animator.transform_to_degrees = opts.get("transform_to_degrees", false)
	animator.invert_ends = opts.get("invert_ends", false)

	parent.add_child(animator)
	add_child_autofree(holder)
	animator.set_physics_process(false)
	return animator


func _value(animator:PropertyAnimator)-> Variant:
	return animator.get_target().get_indexed(animator.property)


#region ready

func test_the_target_defaults_to_the_parent():
	var animator := _make_animator()

	assert_eq(animator.get_target(), animator.get_parent())


func test_an_explicit_target_is_kept():
	var other:Node2D = add_child_autofree(Node2D.new())
	var animator := _make_animator({"target": other})

	assert_eq(animator.get_target(), other)


func test_autostart_leaves_the_animator_playing():
	var animator := _make_animator({"autostart": true})

	assert_eq(animator.state, PropertyAnimator.State.PLAYING)


func test_without_autostart_the_animator_stays_stopped():
	var animator := _make_animator({"autostart": false})

	assert_eq(animator.state, PropertyAnimator.State.STOPPED)

#endregion


#region actual values

func test_the_actual_ends_are_the_configured_ones():
	var animator := _make_animator({"min_value": 2.0, "max_value": 8.0})

	assert_almost_eq(animator.actual_min, 2.0, DELTA)
	assert_almost_eq(animator.actual_max, 8.0, DELTA)


func test_the_ends_can_be_given_in_degrees():
	var animator := _make_animator({
		"min_value": 0.0,
		"max_value": 180.0,
		"transform_to_degrees": true,
	})

	assert_almost_eq(animator.actual_min, 0.0, DELTA)
	assert_almost_eq(animator.actual_max, PI, DELTA)


func test_the_offset_moves_both_ends():
	var animator := _make_animator({
		"min_value": 0.0,
		"max_value": 10.0,
		"value_offset": 100.0,
	})

	assert_almost_eq(animator.actual_min, 100.0, DELTA)
	assert_almost_eq(animator.actual_max, 110.0, DELTA)


func test_the_offset_is_in_degrees_too_when_the_ends_are():
	var animator := _make_animator({
		"min_value": 0.0,
		"max_value": 90.0,
		"value_offset": 90.0,
		"transform_to_degrees": true,
	})

	assert_almost_eq(animator.actual_min, PI / 2, DELTA)
	assert_almost_eq(animator.actual_max, PI, DELTA)


func test_inverting_the_ends_swaps_them():
	var animator := _make_animator({
		"min_value": 2.0,
		"max_value": 8.0,
		"invert_ends": true,
	})

	assert_almost_eq(animator.actual_min, 8.0, DELTA)
	assert_almost_eq(animator.actual_max, 2.0, DELTA)


func test_the_ends_are_inverted_after_the_offset_is_applied():
	var animator := _make_animator({
		"min_value": 0.0,
		"max_value": 10.0,
		"value_offset": 100.0,
		"invert_ends": true,
	})

	assert_almost_eq(animator.actual_min, 110.0, DELTA)
	assert_almost_eq(animator.actual_max, 100.0, DELTA)


func test_changing_an_end_recalculates_the_actual_values():
	var animator := _make_animator({"min_value": 0.0, "max_value": 10.0})

	animator.max_value = 20.0

	assert_almost_eq(animator.actual_max, 20.0, DELTA)


func test_changing_the_offset_recalculates_the_actual_values():
	var animator := _make_animator({"min_value": 0.0, "max_value": 10.0})

	animator.value_offset = 5.0

	assert_almost_eq(animator.actual_min, 5.0, DELTA)
	assert_almost_eq(animator.actual_max, 15.0, DELTA)


func test_nothing_is_calculated_while_an_end_is_missing():
	# An animator whose ends have not been filled in yet
	var animator := _make_animator({"min_value": 5.0, "max_value": null})

	assert_almost_eq(animator.actual_min, 0.0, DELTA)
	assert_almost_eq(animator.actual_max, 0.0, DELTA)

#endregion


#region update_property

func test_a_periodic_animation_starts_halfway_between_the_ends():
	var animator := _make_animator({"mode": PropertyAnimator.Mode.PERIODIC})

	animator.update_property()

	assert_almost_eq(_value(animator), 5.0, DELTA)


func test_a_periodic_animation_reaches_the_top_at_a_quarter_of_the_period():
	var animator := _make_animator({"mode": PropertyAnimator.Mode.PERIODIC})

	animator.cycle_time = 0.25
	animator.update_property()

	assert_almost_eq(_value(animator), 10.0, DELTA)


func test_a_periodic_animation_reaches_the_bottom_at_three_quarters():
	var animator := _make_animator({"mode": PropertyAnimator.Mode.PERIODIC})

	animator.cycle_time = 0.75
	animator.update_property()

	assert_almost_eq(_value(animator), 0.0, DELTA)


func test_a_periodic_animation_is_back_to_the_middle_at_the_end_of_the_cycle():
	var animator := _make_animator({"mode": PropertyAnimator.Mode.PERIODIC})

	animator.cycle_time = 1.0
	animator.update_property()

	assert_almost_eq(_value(animator), 5.0, DELTA)


func test_a_restarting_animation_starts_at_the_bottom():
	var animator := _make_animator({"mode": PropertyAnimator.Mode.RESTART})

	animator.update_property()

	assert_almost_eq(_value(animator), 0.0, DELTA)


func test_a_restarting_animation_is_halfway_at_half_the_period():
	var animator := _make_animator({"mode": PropertyAnimator.Mode.RESTART})

	animator.cycle_time = 0.5
	animator.update_property()

	assert_almost_eq(_value(animator), 5.0, DELTA)


func test_a_restarting_animation_reaches_the_top_at_the_end_of_the_cycle():
	var animator := _make_animator({"mode": PropertyAnimator.Mode.RESTART})

	animator.cycle_time = 1.0
	animator.update_property()

	assert_almost_eq(_value(animator), 10.0, DELTA)


func test_the_period_scales_the_animation():
	var animator := _make_animator({"mode": PropertyAnimator.Mode.RESTART, "period": 4.0})

	animator.cycle_time = 2.0
	animator.update_property()

	assert_almost_eq(_value(animator), 5.0, DELTA)


func test_a_subproperty_can_be_animated():
	var animator := _make_animator({
		"property": "position:x",
		"mode": PropertyAnimator.Mode.RESTART,
	})

	animator.cycle_time = 0.5
	animator.update_property()

	assert_almost_eq(animator.get_target().position.x, 5.0, DELTA)


func test_the_animated_values_take_the_offset_into_account():
	var animator := _make_animator({
		"mode": PropertyAnimator.Mode.RESTART,
		"value_offset": 100.0,
	})

	animator.cycle_time = 0.5
	animator.update_property()

	assert_almost_eq(_value(animator), 105.0, DELTA)


func test_nothing_is_animated_without_a_property_name():
	var animator := _make_animator({"property": ""})

	animator.get_target().rotation = 3.0
	animator.update_property()

	assert_almost_eq(animator.get_target().rotation, 3.0, DELTA)


func test_nothing_is_animated_while_an_end_is_missing():
	var animator := _make_animator({"max_value": null})

	animator.get_target().rotation = 3.0
	animator.update_property()

	assert_almost_eq(animator.get_target().rotation, 3.0, DELTA)

#endregion


#region start, stop and reset

func test_starting_plays_from_the_beginning_of_the_cycle():
	var animator := _make_animator({"autostart": false})

	animator.cycle_time = 0.4
	animator.start()

	assert_eq(animator.state, PropertyAnimator.State.PLAYING)
	assert_almost_eq(animator.cycle_time, 0.0, DELTA)


func test_starting_an_animator_that_is_already_playing_does_not_restart_it():
	var animator := _make_animator()

	animator.cycle_time = 0.4
	animator.start()

	assert_almost_eq(animator.cycle_time, 0.4, DELTA)


func test_stopping_rewinds_the_property_to_the_start_of_the_cycle():
	var animator := _make_animator({"mode": PropertyAnimator.Mode.RESTART})

	animator.cycle_time = 0.75
	animator.stop()

	assert_eq(animator.state, PropertyAnimator.State.STOPPED)
	assert_almost_eq(animator.cycle_time, 0.0, DELTA)
	assert_almost_eq(_value(animator), 0.0, DELTA)


func test_stopping_an_animator_that_is_already_stopped_leaves_the_property_alone():
	var animator := _make_animator({"autostart": false})

	animator.get_target().rotation = 3.0
	animator.stop()

	assert_almost_eq(animator.get_target().rotation, 3.0, DELTA)


func test_resetting_rewinds_the_cycle_and_the_property():
	var animator := _make_animator({"mode": PropertyAnimator.Mode.RESTART})

	animator.cycle_time = 0.75
	animator.reset()

	assert_eq(animator.state, PropertyAnimator.State.PLAYING)
	assert_almost_eq(animator.cycle_time, 0.0, DELTA)
	assert_almost_eq(_value(animator), 0.0, DELTA)


func test_resetting_a_stopped_animator_plays_it_again():
	var animator := _make_animator({"autostart": false})

	animator.reset()

	assert_eq(animator.state, PropertyAnimator.State.PLAYING)


func test_finishing_the_cycle_and_stopping_keeps_playing_for_now():
	var animator := _make_animator()

	animator.finish_cycle_and_stop()

	assert_eq(animator.state, PropertyAnimator.State.WAITING_FOR_CYCLE_TO_STOP)


func test_a_stopped_animator_is_not_asked_to_finish_its_cycle():
	var animator := _make_animator({"autostart": false})

	animator.finish_cycle_and_stop()

	assert_eq(animator.state, PropertyAnimator.State.STOPPED)


func test_the_animator_stops_once_the_cycle_it_was_finishing_is_over():
	var animator := _make_animator()

	animator.finish_cycle_and_stop()
	animator._physics_process(0.5)
	assert_eq(animator.state, PropertyAnimator.State.WAITING_FOR_CYCLE_TO_STOP,
		"the cycle is only halfway through")

	animator._physics_process(0.6)

	assert_eq(animator.state, PropertyAnimator.State.STOPPED)
	assert_almost_eq(animator.cycle_time, 0.0, DELTA)

#endregion


#region advancing the cycle

func test_advancing_accumulates_time():
	var animator := _make_animator()

	animator.advance_cycle(0.3)
	animator.advance_cycle(0.3)

	assert_almost_eq(animator.cycle_time, 0.6, DELTA)


func test_the_time_past_the_end_of_the_cycle_is_carried_over():
	var animator := _make_animator({"period": 1.0})

	animator.advance_cycle(0.6)
	animator.advance_cycle(0.6)

	assert_almost_eq(animator.cycle_time, 0.2, DELTA)


func test_finishing_a_cycle_is_announced():
	var animator := _make_animator()
	watch_signals(animator)

	animator.advance_cycle(1.5)

	assert_signal_emit_count(animator, "finished_cycle", 1)


func test_the_cycle_is_not_announced_before_the_period_is_over():
	var animator := _make_animator({"period": 1.0})
	watch_signals(animator)

	animator.advance_cycle(1.0)

	assert_signal_emit_count(animator, "finished_cycle", 0)


func test_the_next_cycle_starts_right_away_without_a_pause():
	var animator := _make_animator({"pause_between_cycles": 0.0})

	animator.advance_cycle(1.2)

	assert_eq(animator.state, PropertyAnimator.State.PLAYING)
	assert_almost_eq(animator.cycle_time, 0.2, DELTA)


func test_the_pause_between_cycles_starts_when_a_cycle_ends():
	var animator := _make_animator({"pause_between_cycles": 0.5})

	animator.advance_cycle(1.2)

	assert_eq(animator.state, PropertyAnimator.State.WAITING_BETWEEN_CYCLES)
	assert_almost_eq(animator.intercycle_time, 0.5, DELTA)
	assert_almost_eq(animator.cycle_time, 0.0, DELTA,
		"the leftover time is dropped, the cycle starts over after the pause")


func test_an_animator_finishing_its_last_cycle_skips_the_pause():
	var animator := _make_animator({"pause_between_cycles": 0.5})

	animator.finish_cycle_and_stop()
	animator.advance_cycle(1.2)

	assert_eq(animator.state, PropertyAnimator.State.STOPPED)
	assert_almost_eq(animator.intercycle_time, 0.0, DELTA)

#endregion


#region physics process

func test_a_playing_animator_advances_and_updates_the_property():
	var animator := _make_animator({"mode": PropertyAnimator.Mode.RESTART})

	animator._physics_process(0.25)

	assert_almost_eq(animator.cycle_time, 0.25, DELTA)
	assert_almost_eq(_value(animator), 2.5, DELTA)


func test_a_stopped_animator_is_left_alone():
	var animator := _make_animator({"autostart": false})

	animator.get_target().rotation = 3.0
	animator._physics_process(0.25)

	assert_almost_eq(animator.cycle_time, 0.0, DELTA)
	assert_almost_eq(animator.get_target().rotation, 3.0, DELTA)


func test_an_animator_finishing_its_cycle_keeps_advancing():
	var animator := _make_animator({"mode": PropertyAnimator.Mode.RESTART})

	animator.finish_cycle_and_stop()
	animator._physics_process(0.25)

	assert_almost_eq(animator.cycle_time, 0.25, DELTA)
	assert_almost_eq(_value(animator), 2.5, DELTA)


func test_the_pause_between_cycles_counts_down():
	var animator := _make_animator({"pause_between_cycles": 0.5})
	animator.advance_cycle(1.2)

	animator._physics_process(0.2)

	assert_eq(animator.state, PropertyAnimator.State.WAITING_BETWEEN_CYCLES)
	assert_almost_eq(animator.intercycle_time, 0.3, DELTA)
	assert_almost_eq(animator.cycle_time, 0.0, DELTA, "the cycle waits for the pause to be over")


func test_the_animator_plays_again_once_the_pause_is_over():
	var animator := _make_animator({"pause_between_cycles": 0.5})
	animator.advance_cycle(1.2)

	animator._physics_process(0.6)

	assert_eq(animator.state, PropertyAnimator.State.PLAYING)
	assert_almost_eq(animator.intercycle_time, 0.0, DELTA,
		"the time past the end of the pause is dropped")


func test_an_invisible_target_is_not_animated():
	var animator := _make_animator()

	animator.get_target().visible = false
	animator._physics_process(0.25)

	assert_almost_eq(animator.cycle_time, 0.0, DELTA)


func test_a_target_hidden_by_an_ancestor_is_not_animated():
	var animator := _make_animator()

	animator.get_target().get_parent().visible = false
	animator._physics_process(0.25)

	assert_almost_eq(animator.cycle_time, 0.0, DELTA)


func test_the_engine_drives_a_playing_animator():
	var animator := _make_animator({"mode": PropertyAnimator.Mode.RESTART})

	animator.set_physics_process(true)
	await wait_physics_frames(2)

	assert_gt(animator.cycle_time, 0.0)
	assert_gt(_value(animator), 0.0)

#endregion
