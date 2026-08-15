extends GutTest

## PerfToggle on its own: the recording and restoring, which is what makes a
## measurement trustworthy. A toggle that restores to a guessed default rather
## than to what was there produces a scene nobody asked about.


class _Probe extends Node:
	var flag:bool = true
	var number:int = 5


func _toggle(apply:Callable)-> PerfToggle:
	return PerfToggle.new("t", "test toggle", apply)


func test_change_applies_and_restores_the_previous_value()-> void:
	var probe := _Probe.new()
	var toggle := _toggle(func(t:PerfToggle): t.change(probe, "flag", false))

	toggle.activate()
	assert_false(probe.flag, "applied")
	assert_true(toggle.active)

	toggle.deactivate()
	assert_true(probe.flag, "restored")
	assert_false(toggle.active)
	probe.free()


func test_restores_to_what_was_there_not_to_a_default()-> void:
	## The whole point. A node that shipped with flag already false must come
	## back false -- a toggle that "restores" it to true has quietly changed the
	## scene and any later measurement describes something else.
	var probe := _Probe.new()
	probe.flag = false

	var toggle := _toggle(func(t:PerfToggle): t.change(probe, "flag", false))
	toggle.activate()
	toggle.deactivate()

	assert_false(probe.flag, "still false, never turned on")
	probe.free()


func test_repeated_changes_unwind_to_the_original()-> void:
	var probe := _Probe.new()
	var toggle := _toggle(func(t:PerfToggle):
		t.change(probe, "number", 10)
		t.change(probe, "number", 20))

	toggle.activate()
	assert_eq(probe.number, 20, "last write wins")

	toggle.deactivate()
	assert_eq(probe.number, 5, "unwound all the way, not to the intermediate")
	probe.free()


func test_missing_targets_is_flagged()-> void:
	## A toggle that finds nothing must say so. Silently doing nothing is worse
	## than failing: it reads as "I turned that off and it made no difference".
	var toggle := _toggle(func(_t:PerfToggle): pass)
	toggle.activate()

	assert_true(toggle.active)
	assert_true(toggle.missing_targets, "nothing was acted on")
	assert_eq(toggle.target_count(), 0)


func test_target_count_counts_distinct_objects()-> void:
	var a := _Probe.new()
	var b := _Probe.new()
	var toggle := _toggle(func(t:PerfToggle):
		t.change(a, "flag", false)
		t.change(a, "number", 1)
		t.change(b, "flag", false))

	toggle.activate()
	assert_eq(toggle.target_count(), 2, "two objects, three changes")
	assert_false(toggle.missing_targets)
	a.free()
	b.free()


func test_activating_twice_does_not_double_record()-> void:
	var probe := _Probe.new()
	var toggle := _toggle(func(t:PerfToggle): t.change(probe, "number", 99))

	toggle.activate()
	toggle.activate()
	toggle.deactivate()

	assert_eq(probe.number, 5, "still restores cleanly")
	probe.free()


func test_survives_targets_being_freed()-> void:
	## Scene teardown between activate and deactivate is normal here -- prestige
	## rebuilds the world. Restoring must not error on the corpses.
	var probe := _Probe.new()
	var toggle := _toggle(func(t:PerfToggle): t.change(probe, "flag", false))

	toggle.activate()
	probe.free()
	toggle.deactivate()

	assert_false(toggle.active, "deactivated without erroring")


func test_forget_drops_changes_without_restoring()-> void:
	var probe := _Probe.new()
	var toggle := _toggle(func(t:PerfToggle): t.change(probe, "flag", false))

	toggle.activate()
	toggle.forget()

	assert_false(probe.flag, "left as-is, deliberately not restored")
	assert_false(toggle.active)
	probe.free()


func test_custom_undo_runs_in_addition_to_restoring()-> void:
	var probe := _Probe.new()
	var extra:Array[bool] = []
	var toggle := PerfToggle.new("t", "test",
		func(t:PerfToggle): t.change(probe, "flag", false),
		-1,
		func(_t:PerfToggle): extra.append(true))

	toggle.activate()
	toggle.deactivate()

	assert_true(probe.flag, "properties still restored")
	assert_eq(extra.size(), 1, "custom undo also ran")
	probe.free()
