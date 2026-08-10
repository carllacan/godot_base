@tool
extends BaseComponent
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
# TODO: these two are never read anywhere, implement them or remove them
@export var fade_in_when_activated:bool = true
@export var fade_on_when_deactivated:bool = true
# TODO: implement this
@export var loop:bool = true


var time_left:float = NAN
var state:States = States._undef : set = set_state
var original_alpha:float = NAN
var is_active:bool = false : set = set_is_active


func _on_parent_ready()-> void:
	# Drives the target's modulate, which the editor would serialize into the scene.
	if Engine.is_editor_hint(): return

	# TODO: activation happens before the initial state is applied, so set_is_active
	# runs while the state is still _undef, tries to fade in and fails its own guard.
	# Every autostarted fader prints a warning on ready because of this. Setting the
	# initial state first would fix it (the tests pin the current behaviour)
	if autostart:
		is_active = true
	else:
		is_active = false

	# Captured here rather than at _ready: the target has run its own _ready by
	# now, so this is the alpha it actually starts out with.
	original_alpha = get_target().modulate.a
	match initial_state:
		States.INVISIBLE:
			get_target().modulate.a = 0.0
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
	
	if changed: p("Active: %s", [is_active])
	
	# TODO: fades cannot be interrupted. Deactivating while fading in (or activating
	# while fading out) hits the guard in start_fading_out/start_fading_in, warns and
	# does nothing, so the fader only reverses at the next period boundary
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
				#get_target().modulate.a = 0.0
				p("INVISIBLE")
			States.FADING_IN:
				p("FADING_IN")
			States.VISIBLE:
				#get_target().modulate.a = original_alpha
				p("VISIBLE")
			States.FADING_OUT:
				p("FADING_OUT")
		
	
func _is_parent_valid()-> bool:
	return get_target() is CanvasItem


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
	if Engine.is_editor_hint(): return
	if state == States._undef: return
	
	time_left -= delta

	# TODO: q is not clamped, so a delta bigger than the time left overshoots the
	# alpha past original_alpha (or below 0 when fading out). Nothing sets the alpha
	# again when the period changes, so the wrong value stays for the whole next one
	match state:
		States.FADING_IN:
			var q = 1.0-time_left/transition_time
			var new_a = lerp(0.0, original_alpha, q)
			get_target().modulate.a = new_a
			#if verbose:print("FADING_IN: %s" % new_a)
		States.FADING_OUT:
			var q = 1.0-time_left/transition_time
			var new_a = lerp(original_alpha, 0.0, q)
			get_target().modulate.a = new_a
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
