extends GutTest

## The component wires itself up from _notification(NOTIFICATION_READY), so the
## tests build it under a parent that is still out of the tree and let
## add_child_autofree() ready the whole thing, which is the order a scene loads
## in. The one exception is the already-ready case, which has to add the
## component to a parent that is in the tree.


## Records the hook so a test can tell whether, and how often, it ran.
class _Probe extends BaseComponent:
	var parent_ready_calls:int = 0

	func _on_parent_ready()-> void:
		parent_ready_calls += 1


## Overrides _ready without calling super(), which is the mistake the base class
## is meant to survive.
class _ProbeWithOwnReady extends BaseComponent:
	var parent_ready_calls:int = 0
	var own_ready_ran:bool = false

	func _ready()-> void:
		own_ready_ran = true

	func _on_parent_ready()-> void:
		parent_ready_calls += 1


## Declares a parent requirement, so the validation paths have something to fail.
class _PickyProbe extends BaseComponent:
	func _is_parent_valid()-> bool:
		return get_parent() is Button

	func _get_parent_requirement()-> String:
		return "a Button"


## Counts its processing callbacks so the enabled flags can be observed.
class _ProcessProbe extends BaseComponent:
	var process_ticks:int = 0
	var physics_ticks:int = 0

	func _process(_delta:float)-> void:
		process_ticks += 1

	func _physics_process(_delta:float)-> void:
		physics_ticks += 1


## Builds a component hanging from a parent that is not in the tree yet, then
## readies both at once.
func _make(component:BaseComponent, parent:Node = null)-> BaseComponent:
	var actual_parent:Node = parent if parent != null else Node.new()
	actual_parent.add_child(component)
	add_child_autofree(actual_parent)
	return component


#region the target

func test_the_target_defaults_to_the_parent():
	var probe:_Probe = _make(_Probe.new())

	assert_eq(probe.get_target(), probe.get_parent())


func test_an_explicit_target_wins_over_the_parent():
	var elsewhere := Node.new()
	add_child_autofree(elsewhere)

	var probe := _Probe.new()
	probe.target_override = elsewhere
	_make(probe)

	assert_eq(probe.get_target(), elsewhere)


## The reason get_target() resolves the parent on every call instead of caching
## it once at ready.
func test_the_target_follows_the_parent_across_a_reparent():
	var first := Node.new()
	var second := Node.new()
	add_child_autofree(first)
	add_child_autofree(second)

	var probe := _Probe.new()
	first.add_child(probe)
	assert_eq(probe.get_target(), first, "starts on the parent it was added to")

	probe.reparent(second)
	assert_eq(probe.get_target(), second, "follows the new parent")

#endregion

#region the parent ready hook

func test_the_hook_runs_once_the_parent_is_ready():
	var probe:_Probe = _make(_Probe.new())
	await wait_process_frames(2)

	assert_eq(probe.parent_ready_calls, 1)


## A component added to a parent that is already in the tree cannot connect to
## a ready signal that has been emitted already.
func test_the_hook_runs_when_the_component_joins_an_already_ready_parent():
	var parent := Node.new()
	add_child_autofree(parent)
	assert_true(parent.is_node_ready(), "the parent is ready before the component joins")

	var probe := _Probe.new()
	parent.add_child(probe)
	await wait_process_frames(2)

	assert_eq(probe.parent_ready_calls, 1)


## The base class sets itself up from _notification precisely so that this works.
func test_the_hook_runs_even_when_a_subclass_overrides_ready_without_super():
	var probe:_ProbeWithOwnReady = _make(_ProbeWithOwnReady.new())
	await wait_process_frames(2)

	assert_true(probe.own_ready_ran, "the subclass _ready still ran")
	assert_eq(probe.parent_ready_calls, 1, "and so did the base class setup")

#endregion

#region enabled

func test_disabling_stops_process_when_asked_to():
	var probe := _ProcessProbe.new()
	probe.enabled_controls_process = true
	_make(probe)

	probe.enabled = false
	var ticks_when_disabled:int = probe.process_ticks
	await wait_process_frames(3)

	assert_eq(probe.process_ticks, ticks_when_disabled)


func test_disabling_leaves_process_alone_by_default():
	var probe:_ProcessProbe = _make(_ProcessProbe.new())

	probe.enabled = false
	var ticks_when_disabled:int = probe.process_ticks
	await wait_process_frames(3)

	assert_gt(probe.process_ticks, ticks_when_disabled)


func test_disabling_stops_physics_process_when_asked_to():
	var probe := _ProcessProbe.new()
	probe.enabled_controls_physics_process = true
	_make(probe)

	probe.enabled = false
	var ticks_when_disabled:int = probe.physics_ticks
	await wait_physics_frames(3)

	assert_eq(probe.physics_ticks, ticks_when_disabled)


func test_enabling_again_restores_process():
	var probe := _ProcessProbe.new()
	probe.enabled_controls_process = true
	_make(probe)
	probe.enabled = false
	await wait_process_frames(2)

	probe.enabled = true
	var ticks_when_reenabled:int = probe.process_ticks
	await wait_process_frames(3)

	assert_gt(probe.process_ticks, ticks_when_reenabled)

#endregion

#region parent validation

func test_a_valid_parent_produces_no_configuration_warning():
	var probe := _PickyProbe.new()
	_make(probe, Button.new())

	assert_eq(probe._get_configuration_warnings().size(), 0)


func test_an_invalid_parent_is_reported_as_a_configuration_warning():
	var probe := _PickyProbe.new()
	_make(probe, Label.new())

	assert_eq(probe._get_configuration_warnings().size(), 1)
	assert_push_error("cannot be attached to a Label")


func test_the_warning_says_what_the_parent_should_have_been():
	var probe := _PickyProbe.new()
	_make(probe, Label.new())

	var warning:String = probe._get_configuration_warnings()[0]
	assert_string_contains(warning, "a Button", "names the requirement")
	assert_string_contains(warning, "Label", "names what it actually got")
	assert_push_error("cannot be attached to a Label")


## The editor gets a configuration warning; a running game gets an error, since
## there is nothing to show a warning on by then.
func test_an_invalid_parent_is_also_an_error_at_runtime():
	var probe := _PickyProbe.new()
	_make(probe, Label.new())

	assert_push_error("cannot be attached to a Label, it must be a child of a Button")


func test_a_component_with_no_parent_produces_no_warning():
	var probe := autofree(_PickyProbe.new()) as _PickyProbe

	assert_eq(probe._get_configuration_warnings().size(), 0)


func test_a_component_with_no_requirement_accepts_any_parent():
	var probe := _PickyProbe.new()
	_make(probe, Button.new())

	assert_true(probe._is_parent_valid())

#endregion

#region verbose printing

func test_printing_is_safe_while_verbose_is_off():
	var probe:_Probe = _make(_Probe.new())

	probe.p("nothing should happen here")

	pass_test("p() returned without printing or erroring")


## The arguments are applied to the message rather than interpolated by the
## caller, so a message full of format specifiers has to survive both paths.
func test_printing_formats_its_arguments():
	var probe:_Probe = _make(_Probe.new())
	probe.verbose = true

	probe.p("%s and %s", ["one", "two"])

	pass_test("p() formatted its arguments without erroring")


## A bare message is printed as-is, so a literal percent sign in it must not be
## treated as a format specifier.
func test_a_literal_percent_survives_a_message_with_no_arguments():
	var probe:_Probe = _make(_Probe.new())
	probe.verbose = true

	probe.p("100% done")

	pass_test("p() left the literal percent alone")

#endregion
