extends Node
class_name PropertyAnimator

signal finished_cycle

enum State {
	STOPPED,
	PLAYING,
	WAITING_FOR_CYCLE_TO_STOP,
	WAITING_BETWEEN_CYCLES,
}

@export var target:Node
@export var property:String
@export var min_value:Variant
@export var max_value:Variant
@export var period:float = 1.0
@export var pause_between_cycles:float = 0.0
@export var autostart:bool = true
@export_group("Debug")
@export var verbose:bool = false


var state:State = State.STOPPED
var cycle_time:float = 0
var intercycle_time:float = 0


func _ready()-> void:
	finished_cycle.connect(_on_cycle_finished)
	if autostart:
		start()


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
	
	state = State.WAITING_FOR_CYCLE_TO_STOP
	

func update_property()-> void:	
	if not is_node_ready(): return
	
	var phase = cycle_time/period
	var c = sin(2*PI*phase)
	
	var value = lerp(min_value, max_value, inverse_lerp(-1, 1, c))
	target.set(property, value)
	
	if verbose:
		print("%s->%s" % [cycle_time, value])
	
	
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
	
