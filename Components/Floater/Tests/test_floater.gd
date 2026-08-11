extends GutTest

## The floater animates its parent with a real tween, so these tests let the
## engine run. Where the float is started by hand the tests await float_away(),
## which finishes with the tween; the tests that check what triggers a float
## have nothing to await and wait WAIT_TIME instead, which is long enough for a
## FLOAT_TIME float to be well and truly over.

const DELTA:float = 0.001
const POS_DELTA:Vector2 = Vector2(DELTA, DELTA)
const FLOAT_TIME:float = 0.1
const WAIT_TIME:float = 0.4


## Builds a floater hanging from the node it moves, which is how it is used in
## the game's scenes. The exports are set before the parent enters the tree, so
## the floater is configured by the time it reacts to anything, like a scene
## loading its properties.
##
## free_parent_at_end is off here, against the component's own default, so that
## the parent is still around to be looked at once the float is over. The tests
## that are about the freeing itself set it explicitly.
func _make_floater(opts:Dictionary = {})-> Floater:
	var parent := Node2D.new()
	parent.visible = opts.get("visible", true)
	parent.position = opts.get("position", Vector2.ZERO)

	var floater := Floater.new()
	# Set in the order they are declared, which is the order a scene sets them in
	if opts.has("final_pos"): floater.final_pos = opts["final_pos"]
	if opts.has("final_distance"): floater.final_distance = opts["final_distance"]
	if opts.has("direction"): floater.direction = opts["direction"]
	floater.final_alpha = opts.get("final_alpha", 0.0)
	floater.float_time_s = opts.get("float_time_s", FLOAT_TIME)
	floater.float_time_fluctuation = opts.get("float_time_fluctuation", 0.0)
	floater.trigger = opts.get("trigger", Floater.TriggerType.MANUAL)
	floater.free_parent_at_end = opts.get("free_parent_at_end", false)

	parent.add_child(floater)
	add_child_autofree(parent)
	return floater


## The parent is the node that floats, and the floater frees itself on the way
## out, so tests hold on to the parent before letting a float run.
func _parent_of(floater:Floater)-> Node2D:
	return floater.get_parent()


## The default float: up by 50 pixels and all the way to transparent
func _assert_floated_away(parent:Node2D)-> void:
	assert_almost_eq(parent.position, Vector2(0, -50), POS_DELTA, "should have floated up")
	assert_almost_eq(parent.modulate.a, 0.0, DELTA, "should have faded out")


func _assert_stayed_put(parent:Node2D)-> void:
	assert_almost_eq(parent.position, Vector2.ZERO, POS_DELTA, "should not have moved")
	assert_almost_eq(parent.modulate.a, 1.0, DELTA, "should not have faded")


func _all_alphas_equal(parents:Array)-> bool:
	var first:float = parents[0].modulate.a
	return parents.all(func(parent:Node2D): return is_equal_approx(parent.modulate.a, first))


#region where the parent floats to

func test_the_distance_and_the_direction_follow_the_final_position():
	var floater := _make_floater({"final_pos": Vector2(30, 0)})

	assert_almost_eq(floater.final_distance, 30.0, DELTA)
	assert_almost_eq(floater.direction, 0.0, DELTA)


func test_the_final_position_follows_the_distance():
	# The direction is left at its default, straight up
	var floater := _make_floater({"final_distance": 100.0})

	assert_almost_eq(floater.final_pos, Vector2(0, -100), POS_DELTA)
	assert_almost_eq(floater.direction, -90.0, DELTA)


func test_the_final_position_follows_the_direction():
	# The distance is left at its default, 50
	var floater := _make_floater({"direction": 0.0})

	assert_almost_eq(floater.final_pos, Vector2(50, 0), POS_DELTA)
	assert_almost_eq(floater.final_distance, 50.0, DELTA)


func test_the_distance_and_the_direction_survive_each_other():
	var floater := _make_floater({"final_distance": 100.0, "direction": 135.0})

	assert_almost_eq(floater.final_pos, Vector2(-70.711, 70.711), POS_DELTA)
	assert_almost_eq(floater.final_distance, 100.0, DELTA)
	assert_almost_eq(floater.direction, 135.0, DELTA)


# The direction is read back off the final position, and Vector2.angle() returns
# the half turn as -PI, so a direction of 180 is stored as -180. The floater
# still goes the right way.
func test_a_half_turn_direction_is_stored_as_its_negative():
	var floater := _make_floater({"direction": 180.0})

	assert_almost_eq(floater.final_pos, Vector2(-50, 0), POS_DELTA)
	assert_almost_eq(floater.direction, -180.0, DELTA)


func test_the_final_position_can_be_changed_after_the_floater_is_in_the_tree():
	var floater := _make_floater()

	floater.final_pos = Vector2(0, 25)

	assert_almost_eq(floater.final_distance, 25.0, DELTA)
	assert_almost_eq(floater.direction, 90.0, DELTA)

#endregion


#region what starts a float

func test_an_on_ready_floater_floats_as_soon_as_it_is_in_the_tree():
	var floater := _make_floater({"trigger": Floater.TriggerType.ON_READY})
	var parent := _parent_of(floater)

	await wait_seconds(WAIT_TIME)

	_assert_floated_away(parent)


func test_a_manual_floater_waits_to_be_told():
	var floater := _make_floater({"trigger": Floater.TriggerType.MANUAL})
	var parent := _parent_of(floater)

	await wait_seconds(WAIT_TIME)

	_assert_stayed_put(parent)


func test_an_on_shown_floater_does_not_float_on_ready():
	var floater := _make_floater({"trigger": Floater.TriggerType.ON_SHOWN})
	var parent := _parent_of(floater)

	await wait_seconds(WAIT_TIME)

	_assert_stayed_put(parent)


func test_an_on_shown_floater_floats_when_its_parent_is_shown():
	var floater := _make_floater({"trigger": Floater.TriggerType.ON_SHOWN, "visible": false})
	var parent := _parent_of(floater)

	parent.show()
	await wait_seconds(WAIT_TIME)

	_assert_floated_away(parent)


func test_an_on_shown_floater_stays_put_while_its_parent_is_hidden():
	var floater := _make_floater({"trigger": Floater.TriggerType.ON_SHOWN, "visible": false})
	var parent := _parent_of(floater)

	await wait_seconds(WAIT_TIME)

	_assert_stayed_put(parent)


func test_hiding_the_parent_does_not_start_a_float():
	var floater := _make_floater({"trigger": Floater.TriggerType.ON_SHOWN})
	var parent := _parent_of(floater)

	parent.hide()
	await wait_seconds(WAIT_TIME)

	_assert_stayed_put(parent)


func test_a_manual_floater_floats_when_it_is_told_to():
	var floater := _make_floater({"trigger": Floater.TriggerType.MANUAL})
	var parent := _parent_of(floater)

	await floater.float_away()

	_assert_floated_away(parent)

#endregion


#region the float itself

func test_the_parent_floats_from_wherever_it_is():
	var floater := _make_floater({"position": Vector2(10, 10)})
	var parent := _parent_of(floater)

	await floater.float_away()

	assert_almost_eq(parent.position, Vector2(10, -40), POS_DELTA)


func test_the_parent_floats_to_the_distance_and_direction_that_were_set():
	var floater := _make_floater({"final_distance": 20.0, "direction": 0.0})
	var parent := _parent_of(floater)

	await floater.float_away()

	assert_almost_eq(parent.position, Vector2(20, 0), POS_DELTA)


func test_the_parent_fades_to_the_final_alpha():
	var floater := _make_floater({"final_alpha": 0.5})
	var parent := _parent_of(floater)

	await floater.float_away()

	assert_almost_eq(parent.modulate.a, 0.5, DELTA)


func test_the_float_is_still_going_partway_through():
	var floater := _make_floater({"float_time_s": 1.0})
	var parent := _parent_of(floater)

	floater.float_away()
	await wait_seconds(0.2)

	assert_between(parent.position.y, -49.0, -1.0, "should be on its way up")
	assert_between(parent.modulate.a, 0.02, 0.98, "should be on its way out")


func test_the_floater_frees_itself_once_the_float_is_over():
	var floater := _make_floater()

	await floater.float_away()
	await wait_process_frames(1)

	assert_freed(floater, "floater")


func test_the_floater_leaves_its_parent_behind():
	var floater := _make_floater()
	var parent := _parent_of(floater)

	await floater.float_away()
	await wait_process_frames(1)

	assert_not_freed(parent, "parent")

#endregion


#region the float time

func test_every_float_takes_the_same_time_without_fluctuation():
	var parents:Array = []
	for i in 5:
		var floater := _make_floater({"float_time_s": 0.6, "float_time_fluctuation": 0.0})
		parents.append(_parent_of(floater))
		floater.float_away()

	await wait_seconds(0.3)

	assert_true(_all_alphas_equal(parents), "floats started together should be in step")


func test_the_fluctuation_makes_floats_take_different_times():
	var parents:Array = []
	for i in 5:
		var floater := _make_floater({"float_time_s": 0.6, "float_time_fluctuation": 0.5})
		parents.append(_parent_of(floater))
		floater.float_away()

	await wait_seconds(0.3)

	assert_false(_all_alphas_equal(parents), "floats of different lengths should drift apart")

#endregion
