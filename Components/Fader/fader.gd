extends Node
class_name FaderComponent

enum States {
	_undef,
	INVISIBLE,
	FADING_IN,
	VISIBLE,
	FADING_OUT
}

@export var initial_state:States = States.INVISIBLE
@export var invisible_time:float = 3
@export var visible_time:float = 3
@export var transition_time:float = 1
@export var autostart:bool = false
@export var fade_in_when_activated:bool = true
@export var fade_on_when_deactivated:bool = true
# TODO: implement this
@export var loop:bool = true
@export_category("Debug")
@export var verbose:bool = false


var time_left:float = NAN
var state:States = States._undef : set = set_state
var original_alpha:float = NAN
var is_active:bool = false : set = set_is_active


func _ready()-> void:
	if autostart:
		is_active = true
	else:
		is_active = false
		
	original_alpha = get_parent().modulate.a
	match initial_state:
		States.INVISIBLE:
			get_parent().modulate.a = 0.0
			start_invisible_period()
		States.FADING_IN:
			state = States.INVISIBLE
			start_fading_in()
		States.VISIBLE:
			start_visible_period()
		States.FADING_OUT:
			state = States.VISIBLE
			start_fading_out()
	
	
func set_is_active(new_value:bool)-> void:
	var old_value = is_active
	is_active = new_value	
	var changed = old_value != new_value
	
	if changed and verbose: print("Active: %s" % is_active)
	
	if changed:
		if is_active and state not in [States.VISIBLE, States.FADING_IN]:
			start_fading_in()
		if not is_active and state not in [States.INVISIBLE, States.FADING_OUT]:
			start_fading_out()
	
	
func set_state(new_value:States)-> void:
	var old_value = state
	state = new_value
	
	var changed:bool = old_value != new_value
	
	if changed:
		match state:
			States.INVISIBLE:
				#get_parent().modulate.a = 0.0
				if verbose: print("INVISIBLE")
			States.FADING_IN:
				if verbose: print("FADING_IN")
			States.VISIBLE:
				#get_parent().modulate.a = original_alpha
				if verbose: print("VISIBLE")
			States.FADING_OUT:
				if verbose: print("FADING_OUT")
		
	
func start_fading_in()-> void:	
	if state != States.INVISIBLE:
		push_warning("Method 'start_appearing' can only be called in state INVISIBLE")
		return
	time_left = transition_time
	state = States.FADING_IN
		
		
func start_fading_out()-> void:	
	if state != States.VISIBLE:
		push_warning("Method 'start_appearing' can only be called in state INVISIBLE")
		return
	time_left = transition_time
	state = States.FADING_OUT
					

func start_visible_period()-> void:
	time_left = visible_time
	state = States.VISIBLE
	
	
func start_invisible_period()-> void:
	time_left = invisible_time
	state = States.INVISIBLE
		
		
func _process(delta:float)-> void:	
	if state == States._undef: return
	
	time_left -= delta
				
	match state:
		States.FADING_IN:
			var q = 1.0-time_left/transition_time
			var new_a = lerp(0.0, original_alpha, q)
			get_parent().modulate.a = new_a
			#if verbose:print("FADING_IN: %s" % new_a)
		States.FADING_OUT:
			var q = 1.0-time_left/transition_time
			var new_a = lerp(original_alpha, 0.0, q)
			get_parent().modulate.a = new_a
			#if verbose:print("FADING_OUT: %s" % new_a)
	
	
	if time_left <= 0:
		match state:
			States.INVISIBLE:
				if is_active:
					start_fading_in()
			States.FADING_IN:
				start_visible_period()
			States.VISIBLE:
				if is_active:
					start_fading_out()
			States.FADING_OUT:
				start_invisible_period()
