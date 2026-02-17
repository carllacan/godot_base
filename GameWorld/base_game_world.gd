extends Node2D
class_name BaseGameWorld

@warning_ignore("unused_signal")
signal hovered_changed(new_element)
signal selection_changed(new_selection)

## PLacing as finished or canceled. Returns the placement position in the first place
## and null otherwise.
signal placing_finished(result)

enum State {
	_undef,
	# Components can be selected and hovered
	IDLE,
	# Nothing can be done with the world elements
	BLOCKED,
	# A component has been selected
	SELECTED,
	# Components can be clicked in order to place other elements on them
	PLACING,
}

@export var placing_indicator:Node2D
@export_group("Grid")
@export var grid_enabled:bool = false
@export var grid_size:Vector2 = Vector2(32, 32)
@export var grid_odd_rows_offset:float = 0
@export var grid_even_rows_offset:float = 0

var state:State = State._undef : set = set_state

var actors:Array[BaseActor] = []

var selected_actor:BaseActor = null

var hovered_actor:BaseActor = null

var placing_actor:BaseActor = null
var place_new_task:Task


#var round_info:RoundInfo : set = set_round_info


#func set_round_info(new_value:RoundInfo)-> void:
	#round_info = new_value
	
	
var run:GameState : set = set_run

func set_run(new_value:GameState)-> void:
	var old_value = run
	run = new_value
	var changed:bool = new_value != old_value
	
	if changed:
		_on_run_changed(new_value, old_value)
	
	
func _ready()-> void:
	pass
		
		
@warning_ignore("unused_parameter")
func _on_run_changed(new_value:GameState, old_value:GameState)-> void:
	return
	
	
#region State

func set_state(new_value:State)-> void:
	var old_value = state
	var has_changed:bool = old_value != new_value
	state = new_value
	
	match state:
		State.IDLE:
			set_all_actors_to_state(BaseActor.State.IDLE)
			placing_indicator.hide()
		State.BLOCKED:
			set_all_actors_to_state(BaseActor.State.DISABLED)
			placing_indicator.hide()
		State.SELECTED:
			set_all_actors_to_state(BaseActor.State.IDLE, [selected_actor])
			placing_indicator.hide()
		State.PLACING:
			set_all_actors_to_state(BaseActor.State.DISABLED)
			placing_indicator.show()
	
	if has_changed:
		print("World state changed to %s" % State.keys()[state])
		
func get_valid_rect()-> Rect2:
	return Rect2(0, 0, 0, 0)
	
		
func is_position_valid(_pos:Vector2)-> bool:
	return true
	
	
func get_closest_position(pos:Vector2)-> Vector2:
	var closest = pos
		
	var r = get_valid_rect()	
	if not r.has_point(pos) and r.get_area() > 0:
		closest = Utils.get_rect_segment_intersection(r, closest, r.get_center())
				
	if grid_enabled:
		var row := int(round(closest.y / grid_size.y))
		var y := row * grid_size.y
		var x_offset := grid_even_rows_offset if (row % 2 == 0) else grid_odd_rows_offset
		var col := int(round((closest.x - x_offset) / grid_size.x))
		var x := col * grid_size.x + x_offset

		closest = Vector2(x, y)


	return closest
	
		
#region Selection
		
func select_actor(actor:BaseActor)-> void:
	var changed:bool = selected_actor != actor
	if not changed:
		return
		
	if is_something_selected():
		unselect_current()
		
	selected_actor = actor
	state = State.SELECTED
	selected_actor.state = BaseActor.State.SELECTED
	selection_changed.emit(selected_actor)
	
	
func unselect_current()-> void:
	selected_actor = null
	
	
func is_something_selected()-> bool:
	return selected_actor != null
	

func get_actors_at_position(pos:Vector2)-> BaseActor:
	for actor in actors:
		if get_closest_position(actor.position) == pos:
			return actor
	return null
	
#endregion Selection


#region Hovering

func cancel_selection()-> void:
	assert(state == State.SELECTED)
	unselect_current()
	state = State.IDLE
	
	
func start_hovering(actor:BaseActor)-> void:
	hovered_actor = actor
	hovered_actor.state = BaseActor.State.HOVERED
	
	
func stop_hovering_current()-> void:
	hovered_actor = null
	hovered_actor.state = BaseActor.State.IDLE
	
		
func is_something_hovered()-> bool:
	return selected_actor != null
	
#endregion

#region Placing


func start_placing(what:BaseActor)-> void:	
	placing_actor = what
	
	%PlacingActor.add_child(placing_actor)
		
	placing_actor.state = BaseActor.State.BEING_PLACED
	set_state(BaseGameWorld.State.PLACING)
	
		
func finish_placing(result = null)-> void:
	%PlacingActor.remove_child(placing_actor)
	placing_actor.set_deferred("state", BaseActor.State.IDLE)
	placing_actor = null
	
	state = State.IDLE
	placing_finished.emit(result)
	
	
func update_placing_actor(_delta: float)-> void:
	var mpos = get_local_mouse_position()	
	
	
	if placing_must_be_shown(mpos):
		placing_actor.show()
		placing_indicator.show()
	else:
		placing_actor.hide()
		placing_indicator.hide()
		return
		
	var candidate_position = mpos
	if grid_enabled:
		candidate_position = get_closest_position(mpos)	
		
	var valid = placing_actor.can_be_placed(candidate_position, self)
	
	if not is_position_valid(candidate_position):
		valid = false
	
	if not valid:
		placing_actor.state = BaseActor.State.INVALID_PLACING
	else:
		placing_actor.state = BaseActor.State.BEING_PLACED
		
	if placing_indicator != null:
		placing_indicator.position = candidate_position
		placing_indicator.valid = valid
		
	placing_actor.position = lerp(placing_actor.position, candidate_position, 0.9)
	
	
func can_place_right_now()-> bool:
	if not is_position_valid(placing_actor.position):
		return false
		
	if not placing_actor.can_be_placed(placing_actor.position, self):
		return false
		
	return true
	
	
## Returns whether the actor being placed should be shown if the player
## is trying to place it at this position. Useful for hiding the preview
## if the valid area is not being hovered
func placing_must_be_shown(_candidate_position:Vector2)-> bool:
	return true


	
func on_wrong_placement_attempt()-> void:
	print("WRONG")
	
	
#endregion


func confirm_current_action()-> void:
	match state:
		State.IDLE:
			if is_something_hovered():
				select_actor(hovered_actor)
		State.PLACING:
			if can_place_right_now():
				finish_placing(placing_actor.position)
			else:
				on_wrong_placement_attempt()
			
			
func cancel_current_action()-> void:
	match state:
		State.SELECTED:
			unselect_current()
			#state = State.SELECTING
		State.PLACING:
			finish_placing()

#region Actors

func clear_actors()-> void:
	for actor in actors.duplicate():
		remove_actor(actor)
	actors.clear()
	
	
func add_actor(new_actor:BaseActor)-> void:
	actors.append(new_actor)
	
	new_actor.run = run
	new_actor.effect_dropped.connect(_on_actor_effect_dropped.bind(new_actor))
	new_actor.effect_emitted.connect(_on_actor_effect_emitted.bind(new_actor))
	new_actor.dropped.connect(_on_actor_dropped.bind(new_actor))
	new_actor.destroyed.connect(_on_actor_destroyed.bind(new_actor))
	
	new_actor.pressed.connect(_on_actor_pressed.bind(new_actor))
	new_actor.hovered.connect(_on_actor_hovered.bind(new_actor))
	
	%Actors.add_child(new_actor)
	
	
func remove_actor(target:BaseActor)-> void:	
	if not target in actors:
		push_warning("Tried to remove actor %s, but it was not on the actors list"% target)
	actors.erase(target)
	target.queue_free()
	%Actors.remove_child(target)
	
	
func _on_actor_effect_dropped(effect:BaseEffect, actor:BaseActor)-> void:
	_on_actor_effect_emitted(effect, actor.global_position, actor)
	
		
func _on_actor_effect_emitted(
	effect:BaseEffect, actor_global_position:Vector2, _actor:BaseActor
	)-> void:	
	effect.global_position = actor_global_position
	add_child(effect)
	await effect.finished
	effect.queue_free()
	
		
func _on_actor_dropped(what:BaseActor, _actor:BaseActor)-> void:
	add_actor(what)
	
	
func _on_actor_destroyed(target:BaseActor)-> void:
	remove_actor(target)
	
	
func _on_actor_pressed(target:BaseActor)-> void:
	
	if not target.selectable: return
	
	match state:
		State.IDLE:
			select_actor(target)
		State.PLACING:
			pass
		State.SELECTED:
			select_actor(target)
		State.BLOCKED:
			pass
	
	
func _on_actor_hovered(target:BaseActor)-> void:
	if not target.selectable: return
	
	match state:
		State.IDLE:
			select_actor(target)
		State.PLACING:
			pass
		State.SELECTED:
			select_actor(target)
		State.BLOCKED:
			pass
	
	
func _on_actor_unhovered(target:BaseActor)-> void:
	if not is_something_hovered(): return
	if not target.selectable: return
	if not hovered_actor == target: return
	
	match state:
		State.IDLE:
			select_actor(target)
		State.PLACING:
			pass
		State.SELECTED:
			select_actor(target)
		State.BLOCKED:
			pass
	
	
	
func set_all_actors_to_state(
	new_state:BaseActor.State, exceptions:Array = [])-> void:
	for actor in actors:
		if actor in exceptions: continue
		actor.state = new_state
	
#endregion Actors


func _process(delta: float) -> void:
	#print(state)
	match state:
		State.PLACING:
			update_placing_actor(delta)



func _on_mouse_right_click()-> void:	
	cancel_current_action()


func _on_mouse_left_click()-> void:	
	confirm_current_action()
		
	
	
func _unhandled_input(event: InputEvent) -> void:
	
	if event is InputEventMouseButton:
		if event.is_released():
			if event.button_index == MouseButton.MOUSE_BUTTON_RIGHT:
				_on_mouse_right_click()
			if event.button_index == MouseButton.MOUSE_BUTTON_LEFT:
				_on_mouse_left_click()
			
	if event.is_action("ui_accept"):
		confirm_current_action()
			
	if event.is_action("ui_cancel"):
		cancel_current_action()
