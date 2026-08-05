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

var actual_max:float
var actual_min:float



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

	actual_max = max_value if not transform_to_degrees else deg_to_rad(max_value)
	actual_min = min_value if not transform_to_degrees else deg_to_rad(min_value)
	
	if value_offset != null:
		var offset_v  = value_offset if not transform_to_degrees else deg_to_rad(value_offset)
		
		actual_max += offset_v
		actual_min += offset_v
		
	if invert_ends:
		var _a = actual_max
		actual_max = actual_min
		actual_min = _a
	

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
	
	var phase = cycle_time/period
	var c:float
	var value:float
	
	
	match mode:
		Mode.PERIODIC:
			c = sin(2*PI*phase)
			value = lerp(actual_min, actual_max, inverse_lerp(-1, 1, c))
		Mode.RESTART:
			c = phase
			value = lerp(actual_min, actual_max, c)
	
	get_target().set_indexed(property, value)

	p("%s->%s", [cycle_time, value])
	
	
func advance_cycle(delta:float)-> void:
	cycle_time += delta
	if cycle_time > period:
		cycle_time -= period
		finished_cycle.emit()
		
		
func _on_cycle_finished()-> void:
	match state:
		State.WAITING_FOR_CYCLE_TO_STOP:
			stop()
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
	
