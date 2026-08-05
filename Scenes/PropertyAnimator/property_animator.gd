@tool
extends BaseComponent
class_name PropertyAnimator

signal finished_cycle

enum State {
	STOPPED,
	PLAYING,
	WAITING_FOR_CYCLE_TO_STOP,
	WAITING_BETWEEN_CYCLES,
}

enum Mode {
	## Goes from min to max and then back in the opposite sense
	PERIODIC,
	## Goes from min to max and then wraps back to min
	RESTART,
}

@export var property:String
@export var mode:Mode
@export var period:float = 1.0
@export var pause_between_cycles:float = 0.0
@export var autostart:bool = true
## Whether the animation repeats. With this off it runs a single cycle and holds
## the value it ended on, rather than snapping back to the start.
@export var loop:bool = true
## Number of discrete values the animation is allowed to take. [code]0[/code]
## leaves it continuous.
##
## With [constant Mode.RESTART] each step lasts exactly the same slice of the
## period, so [code]steps[/code] equal to a spritesheet's frame count walks the
## frames evenly. Under [constant Mode.PERIODIC] the steps are evenly spaced in
## value rather than in time, because the sine that drives it is not linear.
@export var steps:int = 0
@export_group("Values")
@export var min_value:Variant : set = set_min_value
@export var max_value:Variant : set = set_max_value
@export var value_offset:Variant : set = set_value_offset
@export var transform_to_degrees:bool = false : set = set_transform_to_degrees
@export var invert_ends:bool = false : set = set_invert_ends
@export_group("Debug")
## Keep animating while the scene is open in the editor, so the effect can be
## previewed there. Specific to this component; most components have no business
## running at edit time.
@export var run_in_editor:bool = false


var state:State = State.STOPPED
var cycle_time:float = 0
var intercycle_time:float = 0

# Variant rather than float so the animator can drive Vector2, Vector3 and
# Color properties as well as numbers. Everything between here and
# update_property() goes through the generic lerp, which handles all of them.
var actual_max:Variant
var actual_min:Variant



func _ready()-> void:
	calculate_actual_values()
	
	#assert(property in target.get_property_list())
	finished_cycle.connect(_on_cycle_finished)
	if autostart:
		start()


func set_min_value(new_value:Variant)-> void:
	var old_value = min_value
	min_value = new_value
	var has_changed:bool = new_value != old_value

	if has_changed:
		calculate_actual_values()


func set_max_value(new_value:Variant)-> void:
	var old_value = max_value
	max_value = new_value
	var has_changed:bool = new_value != old_value

	if has_changed:
		calculate_actual_values()


func set_value_offset(new_value:Variant)-> void:
	var old_value = value_offset
	value_offset = new_value
	var has_changed:bool = new_value != old_value

	if has_changed:
		calculate_actual_values()


func set_transform_to_degrees(new_value:bool)-> void:
	var old_value = transform_to_degrees
	transform_to_degrees = new_value
	var has_changed:bool = new_value != old_value

	if has_changed:
		calculate_actual_values()


func set_invert_ends(new_value:bool)-> void:
	var old_value = invert_ends
	invert_ends = new_value
	var has_changed:bool = new_value != old_value

	if has_changed:
		calculate_actual_values()


func calculate_actual_values()-> void:
	if min_value == null or max_value == null: return

	# deg_to_rad has no meaning for a vector or a colour, so the conversion is
	# dropped rather than being applied to something it would mangle. Decided
	# once here rather than per end, so one bad setup reports one error.
	var as_degrees:bool = transform_to_degrees
	if as_degrees and typeof(min_value) not in [TYPE_FLOAT, TYPE_INT]:
		push_error("PropertyAnimator: transform_to_degrees only applies to numbers, not %s"
			% type_string(typeof(min_value)))
		as_degrees = false

	actual_max = deg_to_rad(max_value) if as_degrees else max_value
	actual_min = deg_to_rad(min_value) if as_degrees else min_value

	if value_offset != null:
		var offset_v:Variant = deg_to_rad(value_offset) if as_degrees else value_offset

		actual_max += offset_v
		actual_min += offset_v

	if invert_ends:
		var _a:Variant = actual_max
		actual_max = actual_min
		actual_min = _a


## Rounds [param weight] down to one of [member steps] evenly spaced values.
## Returns it untouched while [member steps] is 0.
func _quantize(weight:float)-> float:
	if steps <= 0: return weight
	if steps == 1: return 0.0

	# The index is capped because a weight of exactly 1 would otherwise land on
	# step number `steps`, one past the last one, and overshoot the maximum.
	var index:float = min(floor(weight * steps), steps - 1)
	return index / float(steps - 1)
	

func start()-> void:
	if not is_node_ready(): return
	
	if state != State.STOPPED:
		return
		
	state = State.PLAYING
	cycle_time = 0
	
	
func reset()-> void:
	if not is_node_ready(): return
	
	state = State.PLAYING
	cycle_time = 0
	update_property()
	
	
func stop()-> void:
	if not is_node_ready(): return
	
	if state == State.STOPPED:
		return
		
	state = State.STOPPED
	cycle_time = 0
	update_property()
	

func finish_cycle_and_stop()-> void:
	if not is_node_ready(): return
	if state != State.PLAYING: return
	
	state = State.WAITING_FOR_CYCLE_TO_STOP
	

func update_property()-> void:	
	if not is_node_ready(): return
	if min_value == null or max_value == null or property == "": return
	
	var phase:float = cycle_time/period
	var weight:float

	match mode:
		Mode.PERIODIC:
			weight = inverse_lerp(-1, 1, sin(2*PI*phase))
		Mode.RESTART:
			weight = phase

	# lerp is generic, so this is the same line whether the ends are floats,
	# Vector2s, Vector3s or Colors.
	var value:Variant = _refine_value(lerp(actual_min, actual_max, _quantize(weight)))

	get_target().set_indexed(property, value)

	p("%s->%s", [cycle_time, value])
	
	
func advance_cycle(delta:float)-> void:
	cycle_time += delta
	if cycle_time > period:
		cycle_time -= period
		finished_cycle.emit()
		
		
## Last chance to adjust a value before it is written. Overridden by subclasses
## driving a property that needs exact values, such as a whole-numbered one.
func _refine_value(value:Variant)-> Variant:
	return value


func _on_cycle_finished()-> void:
	match state:
		State.WAITING_FOR_CYCLE_TO_STOP:
			stop()
			return

	if not loop:
		# Holds the end of the cycle rather than resetting, so a one-shot leaves
		# the target where the animation took it. stop() would rewind it.
		state = State.STOPPED
		cycle_time = period
		update_property()
		return

	if pause_between_cycles != 0:
		cycle_time = 0
		intercycle_time = pause_between_cycles
		state = State.WAITING_BETWEEN_CYCLES
		
	
func _physics_process(delta: float) -> void:
	if not is_node_ready(): return
	if not run_in_editor and Engine.is_editor_hint(): return

	var t := get_target()
	if not t.visible: return
	if not t.is_visible_in_tree(): return
	
	match state:
		State.STOPPED:
			return
		State.PLAYING:		
			advance_cycle(delta)
		State.WAITING_FOR_CYCLE_TO_STOP:
			advance_cycle(delta)
		State.WAITING_BETWEEN_CYCLES:
			intercycle_time -= delta
			if intercycle_time <= 0:
				intercycle_time = 0
				state = State.PLAYING
	
	update_property()
	
