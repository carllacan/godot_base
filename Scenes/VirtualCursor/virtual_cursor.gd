extends Node2D
class_name VirtualCursor

signal clicked

@export var min_velocity:float = 2
@export var max_velocity:float = 8
@export var current:bool = false : set = set_current
@export var click_action:String = "ui_accept"
@export var simulate_mouse_click:InputEventMouseButton

@export_category("Limits")
@export var min_x:float = -500
@export var max_x:float = 500
@export var min_y:float = -500
@export var max_y:float = 500
@export var use_custom_limits:bool = false

var target_position:Vector2 = Vector2.INF
	

func set_current(value:bool)-> void:
	var old_value = current
	current = value
	
	if current != old_value:
		InputManager.virtual_cursor = self
		force_position(Vector2.ZERO)
		
	
func is_active()-> bool:
	return visible and is_node_ready()
	
	
func force_position(to:Vector2)-> void:
	target_position = to
	position = to
	
	
func _on_visibility_changed()-> void:
	if visible: 		
		global_position = get_viewport().get_mouse_position()	
		
		#force_position(get_viewport().get_mouse_position())
	
	
func _input(event: InputEvent) -> void:			
	if click_action != "" and event.is_action_pressed(click_action):
		if is_active():
			clicked.emit()
			

func _process(_delta: float) -> void:	
	if not is_visible_in_tree(): return
	
	var jpos = InputManager.get_left_joystick_position()
		
	var strength = jpos.length()
	
	if strength > 0.1:
		var vel = lerp(min_velocity, max_velocity, strength)
		var candidate_pos = target_position + jpos*vel		
					
		if not use_custom_limits:	
			var cam = get_viewport().get_camera_2d()		
			var half_size = get_viewport_rect().size * 0.5 / cam.zoom
			var cam_pos = cam.global_position
			var rect = Rect2(cam_pos - half_size, half_size * 2)
			
			target_position.x = clampf(candidate_pos.x, 
				rect.position.x, rect.position.x + rect.size.x)
			target_position.y = clampf(candidate_pos.y, 
				rect.position.y, rect.position.y + rect.size.y)
		else:
			var ws = DisplayServer.window_get_size()
			target_position.x = clampf(candidate_pos.x, ws.x, max_x)
			target_position.y = clampf(candidate_pos.y, min_y, max_y)
					
					
	if target_position != Vector2.INF:
		#position = lerp(position, target_position, 0.9)
		position = lerp(position, target_position, 0.9)
		
