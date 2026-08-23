extends GutTest

## The statistics are pure enough to test without a tree: _ready only sizes the
## ring buffer and resolves the target, so the sampling tests build the buffer
## themselves and drive _record() directly. The two tests that need real
## engine state add the node instead.


func _make_bare()-> PerformanceStats:
	## A stats object that has not been through _ready, with just the buffer set
	## up. Keeps the sampling tests clear of autoloads and viewport resolution.
	var stats := PerformanceStats.new()
	stats._samples.resize(PerformanceStats.CAPACITY)
	return stats


func _feed(stats:PerformanceStats, values:Array)-> void:
	for v in values:
		stats._record(float(v))


func test_percentiles_are_nearest_rank()-> void:
	var stats := _make_bare()
	var values:Array = range(1, 101)  # 1..100 ms
	values.shuffle()  # order must not matter
	_feed(stats, values)

	assert_eq(stats.sample_count(), 100, "every sample recorded")
	assert_almost_eq(stats.p50(), 50.0, 0.001, "median of 1..100")
	assert_almost_eq(stats.p95(), 95.0, 0.001, "95th of 1..100")
	assert_almost_eq(stats.p99(), 99.0, 0.001, "99th of 1..100")
	assert_almost_eq(stats.max_ms(), 100.0, 0.001, "max of 1..100")
	stats.free()


func test_percentiles_expose_hitches_a_mean_would_hide()-> void:
	## The case the class exists for: 99 fast frames and one 120 ms stall. The
	## mean says 9.1 ms and looks healthy; p99 has to show the stall.
	var stats := _make_bare()
	var values:Array = []
	for i in 99: values.append(8.0)
	values.append(120.0)
	_feed(stats, values)

	var mean:float = (99.0 * 8.0 + 120.0) / 100.0
	assert_almost_eq(mean, 9.12, 0.01, "the mean really is this misleading")
	assert_almost_eq(stats.p50(), 8.0, 0.001, "typical frame is still fast")
	assert_almost_eq(stats.p99(), 8.0, 0.001, "99th is the last fast frame")
	assert_almost_eq(stats.max_ms(), 120.0, 0.001, "the stall is visible as max")
	stats.free()


func test_empty_buffer_reports_zero_rather_than_erroring()-> void:
	var stats := _make_bare()
	assert_eq(stats.sample_count(), 0)
	assert_almost_eq(stats.p50(), 0.0, 0.001)
	assert_almost_eq(stats.max_ms(), 0.0, 0.001)
	stats.free()


func test_ring_buffer_drops_oldest_when_full()-> void:
	var stats := _make_bare()
	# Fill with 1.0, then overwrite the whole buffer with 2.0.
	for i in PerformanceStats.CAPACITY: stats._record(1.0)
	assert_eq(stats.sample_count(), PerformanceStats.CAPACITY, "buffer is full")
	assert_almost_eq(stats.p50(), 1.0, 0.001, "all ones so far")

	for i in PerformanceStats.CAPACITY: stats._record(2.0)
	assert_eq(stats.sample_count(), PerformanceStats.CAPACITY, "count is capped")
	assert_almost_eq(stats.p50(), 2.0, 0.001, "the ones aged out entirely")
	stats.free()


func test_ring_buffer_keeps_a_partial_window_after_wrapping()-> void:
	var stats := _make_bare()
	for i in PerformanceStats.CAPACITY: stats._record(1.0)
	# Half a buffer of 3.0 on top: the window should now be half and half.
	for i in PerformanceStats.CAPACITY / 2: stats._record(3.0)

	assert_eq(stats.sample_count(), PerformanceStats.CAPACITY)
	assert_almost_eq(stats.p50(), 1.0, 0.001, "median sits on the boundary")
	assert_almost_eq(stats.max_ms(), 3.0, 0.001, "newest values are present")
	stats.free()


func test_reset_clears_counters_and_window()-> void:
	var stats := _make_bare()
	_feed(stats, [5.0, 90.0, 7.0])
	stats.hitches = 4
	stats.peak_ms = 90.0
	stats.worst_ms = 90.0

	stats.reset()

	assert_eq(stats.sample_count(), 0, "samples dropped")
	assert_eq(stats.hitches, 0, "hitches cleared")
	assert_almost_eq(stats.peak_ms, 0.0, 0.001, "peak cleared")
	assert_almost_eq(stats.worst_ms, 0.0, 0.001, "worst cleared")
	stats.free()


func test_settling_waits_for_compilation_to_stop_not_a_frame_count()-> void:
	## Measured over three runs of one unchanging scene, the first
	## representative frame arrived at frame 4 twice and frame 5 once, so a
	## fixed count cannot do this job. Settling tracks the compile counters.
	var stats := _make_bare()
	assert_false(stats.is_settled(), "not settled before anything has happened")

	# Something compiles every frame for a long stretch: still starting up, no
	# matter how many frames have gone by.
	for i in PerformanceStats.SETTLE_QUIET_FRAMES * 3:
		stats._frames += 1
		stats._pipeline_delta["mesh"] = 1
		stats._update_settling()
	assert_false(stats.is_settled(), "compiles keep it unsettled indefinitely")

	# Compilation stops. One frame short of the quiet window, still unsettled.
	stats._pipeline_delta["mesh"] = 0
	for i in PerformanceStats.SETTLE_QUIET_FRAMES - 1:
		stats._frames += 1
		stats._update_settling()
	assert_false(stats.is_settled(), "not settled until the window is complete")

	stats._frames += 1
	stats._update_settling()
	assert_true(stats.is_settled(), "settled once nothing compiled for the window")
	stats.free()


func test_settling_gives_up_eventually()-> void:
	## A game that compiles shaders throughout play would never go quiet, and
	## never reporting any numbers would be worse than reporting noisy ones.
	var stats := _make_bare()
	stats._frames = PerformanceStats.SETTLE_MAX_FRAMES
	stats._pipeline_delta["mesh"] = 1
	stats._update_settling()
	assert_true(stats.is_settled(), "gave up waiting and measured anyway")
	stats.free()


func test_settling_discards_the_startup_samples()-> void:
	var stats := _make_bare()
	_feed(stats, [400.0, 350.0, 300.0])  # scene loading, shader compilation
	stats.hitches = 3
	stats.peak_ms = 400.0

	stats._frames = PerformanceStats.SETTLE_MAX_FRAMES
	stats._update_settling()

	assert_true(stats.is_settled())
	assert_eq(stats.sample_count(), 0, "startup samples thrown away, not kept")
	assert_eq(stats.hitches, 0, "startup hitches do not count against the game")
	assert_almost_eq(stats.peak_ms, 0.0, 0.001)
	stats.free()


func test_render_time_liveness_is_observed_not_counted()-> void:
	## The measurement reads 0.0 until it has been running a couple of frames.
	## That is detected by watching for the first real reading, so it holds on
	## any driver rather than only on the one it was developed against.
	var stats := _make_bare()
	assert_false(stats.has_render_time(), "nothing measured yet")
	assert_almost_eq(stats.render_time_gpu_ms(), 0.0, 0.001)

	# No valid RID, so liveness cannot be established however long it runs.
	for i in PerformanceStats.RENDER_TIME_SETTLE_FRAMES * 2:
		stats._update_render_time_liveness()
	assert_false(stats.has_render_time(), "no viewport, no reading")
	stats.free()


func test_a_viewport_that_costs_nothing_stops_reading_as_pending()-> void:
	## A viewport drawing nothing reads 0.00 forever. That is a true answer, and
	## it must eventually stop being displayed as "waiting for first reading".
	var stats := PerformanceStats.new()
	var was_auto:bool = GodotBase.settings.perf_auto_add_debug_info
	GodotBase.settings.perf_auto_add_debug_info = false
	add_child_autofree(stats)
	await wait_process_frames(PerformanceStats.RENDER_TIME_SETTLE_FRAMES + 5)

	assert_true(stats.has_render_time(),
		"gave up waiting and treats the reading as real")

	GodotBase.settings.perf_auto_add_debug_info = was_auto


func test_falls_back_to_the_root_viewport_when_group_is_empty()-> void:
	var stats := PerformanceStats.new()
	var was_auto:bool = GodotBase.settings.perf_auto_add_debug_info
	GodotBase.settings.perf_auto_add_debug_info = false
	add_child_autofree(stats)
	await wait_physics_frames(2)

	assert_eq(stats.target_viewport, stats.get_viewport(),
		"with nothing marked, the root viewport is measured")
	assert_eq(stats.target_name(), "root")
	assert_true(stats._measured_rid.is_valid(), "measurement was enabled")

	GodotBase.settings.perf_auto_add_debug_info = was_auto


func test_switches_off_the_fallback_when_a_target_appears_later()-> void:
	## Autoloads are ready before the main scene, so the first look at the group
	## always comes up empty. If the root-viewport fallback latched there, a
	## project that marks a SubViewport would measure the wrong thing forever.
	var stats := PerformanceStats.new()
	var was_auto:bool = GodotBase.settings.perf_auto_add_debug_info
	GodotBase.settings.perf_auto_add_debug_info = false
	add_child_autofree(stats)
	await wait_process_frames(2)

	assert_eq(stats.target_name(), "root", "nothing marked yet")

	# The scene loads and brings its marked viewport with it.
	var sub := SubViewport.new()
	sub.size = Vector2i(64, 64)
	sub.add_to_group(BaseGroups.PERF_TARGET)
	add_child_autofree(sub)
	await wait_process_frames(PerformanceStats.TARGET_RECHECK_FRAMES + 2)

	assert_eq(stats.target_viewport, sub, "picked up the late arrival")
	assert_false(stats._using_fallback, "no longer on the fallback")

	GodotBase.settings.perf_auto_add_debug_info = was_auto


func test_uses_a_marked_subviewport_over_the_root()-> void:
	var sub := SubViewport.new()
	sub.size = Vector2i(64, 64)
	sub.add_to_group(BaseGroups.PERF_TARGET)
	add_child_autofree(sub)

	var stats := PerformanceStats.new()
	var was_auto:bool = GodotBase.settings.perf_auto_add_debug_info
	GodotBase.settings.perf_auto_add_debug_info = false
	add_child_autofree(stats)
	await wait_physics_frames(2)

	assert_eq(stats.target_viewport, sub, "the marked viewport wins")
	assert_true(stats._measured_rid.is_valid())

	GodotBase.settings.perf_auto_add_debug_info = was_auto


## Custom monitors need no _ready() either -- no ring buffer, no viewport -- but
## unlike the statistics they are not self-contained: Performance registers them
## process-wide, so a monitor left behind by one test is still there for the
## next one and for every other script in the run. Hence the name prefix and the
## sweep in after_each.
const MONITOR_PREFIX:String = "test_perf_stats/"


## Stands in for the node a monitor is normally registered from. make_getter()
## captures self, which is the shape Callable.is_valid() can see through.
class MonitorOwner extends Node:
	var items:Array[int] = [1, 2, 3, 4]

	func make_getter()-> Callable:
		return func(): return len(items)


func after_each()-> void:
	for monitor_name in Performance.get_custom_monitor_names():
		if String(monitor_name).begins_with(MONITOR_PREFIX):
			Performance.remove_custom_monitor(monitor_name)


func _make_stats()-> PerformanceStats:
	var stats := PerformanceStats.new()
	autofree(stats)
	return stats


func test_a_registered_monitor_reads_and_announces_itself()-> void:
	var stats := _make_stats()
	var monitor_name:String = MONITOR_PREFIX + "items"
	var owner_node := MonitorOwner.new()
	autofree(owner_node)
	watch_signals(stats)

	stats.add_custom_monitor(monitor_name, owner_node.make_getter())

	assert_has(stats.custom_monitors, monitor_name, "tracked here")
	assert_true(Performance.has_custom_monitor(monitor_name),
		"and registered with the engine")
	assert_eq(float(stats.get_value(monitor_name)), 4.0, "reads the getter")
	assert_signal_emitted_with_parameters(
		stats, "monitor_added", [monitor_name])


func test_re_registering_replaces_the_getter_rather_than_being_ignored()-> void:
	## The prestige-reset case. BaseMainScene frees the game scene and builds a
	## new one, so the same monitor name arrives again with a fresh getter while
	## the old getter is still holding the freed node. Skipping that second
	## registration is what leaves a monitor erroring on every read for the rest
	## of the session.
	##
	## Both owners are deliberately kept alive. Freeing the first one would make
	## this pass whether or not the getter is replaced: the second node tends to
	## land on the freed one's address, and a lambda that captured self follows
	## the address rather than the identity -- so the dead getter starts
	## answering for the new node and reads correctly by accident.
	var stats := _make_stats()
	var monitor_name:String = MONITOR_PREFIX + "items"

	var first := MonitorOwner.new()
	autofree(first)
	stats.add_custom_monitor(monitor_name, first.make_getter())
	assert_eq(float(stats.get_value(monitor_name)), 4.0, "reads the first getter")

	watch_signals(stats)
	var second := MonitorOwner.new()
	autofree(second)
	second.items = [1, 2]
	stats.add_custom_monitor(monitor_name, second.make_getter())

	assert_eq(float(stats.get_value(monitor_name)), 2.0,
		"the second registration replaced the getter instead of being ignored")
	assert_signal_not_emitted(stats, "monitor_added",
		"the row already exists, so no second one is announced")


func test_a_getter_whose_node_died_is_pruned()-> void:
	var stats := _make_stats()
	var monitor_name:String = MONITOR_PREFIX + "items"
	var owner_node := MonitorOwner.new()
	stats.add_custom_monitor(monitor_name, owner_node.make_getter())

	watch_signals(stats)
	owner_node.free()
	stats._prune_dead_monitors()

	assert_does_not_have(stats.custom_monitors, monitor_name, "dropped here")
	assert_false(Performance.has_custom_monitor(monitor_name),
		"and unregistered from the engine, not just forgotten")
	assert_signal_emitted_with_parameters(
		stats, "monitor_removed", [monitor_name])


func test_a_healthy_monitor_without_an_owner_survives_pruning()-> void:
	## Most monitors declare no owner, so the owner lookup has to check for the
	## key before reading it -- a missing-key read is an error that aborts the
	## caller rather than returning null.
	var stats := _make_stats()
	var monitor_name:String = MONITOR_PREFIX + "items"
	var owner_node := MonitorOwner.new()
	autofree(owner_node)
	stats.add_custom_monitor(monitor_name, owner_node.make_getter())
	assert_false(stats.custom_monitor_owner_ids.has(monitor_name),
		"no owner was declared, so the lookup has nothing to find")

	stats._prune_dead_monitors()

	assert_has(stats.custom_monitors, monitor_name, "a live monitor is kept")


func test_a_declared_owner_catches_what_the_callable_cannot()-> void:
	## The case the owner registry exists for. A getter that captures only a
	## local has the GDScript itself as its object, and that never dies, so
	## Callable.is_valid() stays true however long ago the node was freed.
	var stats := _make_stats()
	var monitor_name:String = MONITOR_PREFIX + "detached"
	var owner_node := MonitorOwner.new()
	stats.add_custom_monitor(monitor_name,
		func(): return len(owner_node.items), [],
		Performance.MonitorType.MONITOR_TYPE_QUANTITY, owner_node)

	owner_node.free()
	assert_true(stats.custom_monitors[monitor_name].is_valid(),
		"is_valid() cannot see this death, which is why the owner is recorded")

	stats._prune_dead_monitors()

	assert_does_not_have(stats.custom_monitors, monitor_name,
		"the declared owner is what catches it")


func test_an_owner_is_kept_by_id_so_a_refcounted_one_can_still_die()-> void:
	## A Dictionary holds a strong reference, so storing the object itself would
	## mean a RefCounted owner is kept alive by the very registry meant to notice
	## it dying, and would never be pruned.
	var stats := _make_stats()
	var monitor_name:String = MONITOR_PREFIX + "refcounted"
	var owner_ref := RefCounted.new()
	stats.add_custom_monitor(monitor_name, func(): return 1.0, [],
		Performance.MonitorType.MONITOR_TYPE_QUANTITY, owner_ref)

	var owner_id:int = owner_ref.get_instance_id()
	owner_ref = null
	assert_false(is_instance_valid(instance_from_id(owner_id)),
		"the registry is not what is keeping the owner alive")

	stats._prune_dead_monitors()

	assert_does_not_have(stats.custom_monitors, monitor_name)


func test_get_value_is_null_while_a_dead_getter_waits_for_the_next_prune()-> void:
	## Pruning is periodic, so the readout can ask for a value in the window
	## between a node dying and the sweep noticing.
	var stats := _make_stats()
	var monitor_name:String = MONITOR_PREFIX + "items"
	var owner_node := MonitorOwner.new()
	stats.add_custom_monitor(monitor_name, owner_node.make_getter())

	owner_node.free()

	assert_null(stats.get_value(monitor_name),
		"no reading rather than a zero, and no engine error")


func test_get_value_is_null_for_an_unknown_monitor()-> void:
	var stats := _make_stats()
	assert_null(stats.get_value(MONITOR_PREFIX + "never_registered"))


func test_removing_a_monitor_unregisters_and_announces_it()-> void:
	var stats := _make_stats()
	var monitor_name:String = MONITOR_PREFIX + "items"
	var owner_node := MonitorOwner.new()
	autofree(owner_node)
	stats.add_custom_monitor(monitor_name, owner_node.make_getter())

	watch_signals(stats)
	stats.remove_custom_monitor(monitor_name)

	assert_does_not_have(stats.custom_monitors, monitor_name)
	assert_false(Performance.has_custom_monitor(monitor_name))
	assert_signal_emitted_with_parameters(
		stats, "monitor_removed", [monitor_name])
	assert_null(stats.get_value(monitor_name), "and no longer readable")
