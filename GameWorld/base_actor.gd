extends RigidBody2D
class_name BaseActor


@warning_ignore("unused_signal")
signal effect_dropped(effect:BaseEffect)
@warning_ignore("unused_signal")
signal effect_emitted(effect:BaseEffect, global_pos:Vector2)
signal dropped(what)
signal destruction_started
signal destroyed

@warning_ignore("unused_signal")
signal hovered
signal unhovered
signal pressed # it was clicked or otherwise selected
#signal selected


enum State {
	_undef,
	IDLE,
	HOVERED, # I might need to turn this into a bool
	SELECTED,
	DISABLED,
	BEING_PLACED,
	# These next state might have to be put in another enum
	BEING_DESTROYED,
	DESTROYED,
	INVALID_PLACING, # can't be placed there
}

@export var selectable:bool = true

var state:State = State._undef : set = set_state

var just_for_show:bool = false
var being_destroyed:bool : 
	get: 
		return state == State.BEING_DESTROYED
		

func _ready()-> void:
	update_state_representation()
	
	
func set_state(new_value:State)-> void:
	var old_value = state
	state = new_value
	var _has_changed:bool = old_value != new_value
	
	#print("%s state changed to %s from %s" % [
		#self.name, State.keys()[new_value], State.keys()[old_value], ])
	update_state_representation()
	

func is_hovered()-> bool:
	return state == State.HOVERED
	
	
func is_being_destroyed()-> bool:
	return state == State.BEING_DESTROYED
	
	
func _on_pressed()-> void:
	pressed.emit()	
	
	
func start_hover()-> void:
	#assert(not is_hovered())
	if is_hovered(): return
	state = State.HOVERED
	update_state_representation()
	hovered.emit()
	
	
func stop_hover()-> void:
	#assert(is_hovered())
	if not is_hovered(): return
	state = State.IDLE
	update_state_representation()
	unhovered.emit()
	

func update_state_representation()-> void:
	match state:
		State.IDLE:
			modulate = Color.WHITE
		State.SELECTED:
			modulate = Color.BLUE
		State.HOVERED:
			modulate = Color.YELLOW
		State.DISABLED:
			modulate = Color.DARK_GRAY
		State.INVALID_PLACING:
			modulate = Color.RED
		State.BEING_PLACED:
			modulate = Color.WHITE
	
	
func play_destruction_animation(_mode:String = "")-> void:
	return 
	

func destroy(mode:String = "")-> void:
	if state in [State.BEING_DESTROYED, State.DESTROYED]:
		return
		
	state = State.BEING_DESTROYED
	destruction_started.emit()
	@warning_ignore("redundant_await")
	await play_destruction_animation(mode)
	state = State.DESTROYED
	destroyed.emit()
	
	
func drop(what)-> void:
	dropped.emit(what)


#func spawn_projectile(projectile:BaseProjectile)-> void:
	#Events.projectile_spawned.emit(projectile)
	

func can_be_placed(_position:Vector2, _world:BaseGameWorld)-> bool:
	return true
	
	
	
