extends Node2D
class_name BaseSavingIndicator

enum State {
	_undef,
	OUT,
	ENTERING,
	RUNNING,
	EXITING,
}

@export var min_animation_length:float = 1

var state = State._undef : set = set_state
# How long the animation has been running
var animation_running_time:float = 0


func _ready()-> void:
	SaveManager.saving_started.connect(_on_saving_started)
	state = State.OUT


func set_state(new_value:State)-> void:
	state = new_value
	
	
func _on_saving_started()-> void:
	start()
	
	
func start()-> void:
	animation_running_time = 0
	if not is_running():
		enter()
		
	
func stop()-> void:
	if is_running():
		exit()
		
		
func enter()-> void:
	state = State.RUNNING
	
	
func exit()-> void:
	state = State.OUT
	
	
func is_running()-> bool:
	return state == State.RUNNING
	
	
func trigger_transitions()-> void:
	match state:
		State.OUT:
			if not SaveManager.is_saving:
				start()
		#State.ENTERING:
			#pass
		State.RUNNING:
			if not SaveManager.is_saving:
				if animation_running_time > min_animation_length:
					stop()
		#State.EXITING:
			#pass
	
	
func _physics_process(delta: float) -> void:
	if is_running():
		modulate.a = lerp(modulate.a, 1.0, 0.2)
		animation_running_time += delta
		trigger_transitions()
	else:		
		modulate.a = lerp(modulate.a, 0.0, 0.2)
	
