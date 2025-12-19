extends CanvasLayer


@export var zoom_enabled:bool = true
@export_flags(
	"LeftClick:%d" % MOUSE_BUTTON_MASK_LEFT, 
	"RightClick:%d" % MOUSE_BUTTON_MASK_RIGHT, 
	"MouseWheel:%d" % MOUSE_BUTTON_MASK_MIDDLE, 
	) var drag_actions:int = MOUSE_BUTTON_MASK_RIGHT + MOUSE_BUTTON_MASK_MIDDLE


var drag_enabled:bool = true
var camera:Node2D : get = get_camera

	
	
const ZOOM_WHEEL_SENSIBILITY:float = 0.1
const MIN_ZOOM_FACTOR:float = 0.5
const MAX_ZOOM_FACTOR:float = 1.5

enum States {
	_undef,
	BLOCKED,
	IDLE,
	DRAGGING_MAP,
}

@export var initial_zoom_float = 1.0

@export var min_x:float = -1000
@export var max_x:float = +1000
@export var min_y:float = -1000
@export var max_y:float = +1000

@export var keyboard_movement_speed:float = 75
@export var joystick_movement_speed:float = 10

var state:States = States._undef : set = set_state

##region Mouse following
## Element that will follow the mouse
#var attached_to_mouse:BaseWorldElement
## Position where the attached element should go, which will then be clamped
## (needs to be made persistent so that it is not clamped itself)
#var attached_element_target_position:Vector2
##endregion

##region Hovering
#var hovered_elements:Array[BaseWorldElement] = []
##endregion

#region Map dragging
var initial_drag_position:Vector2
var last_mouse_position:Vector2
var camera_position:Vector2 = Vector2.ZERO : set = set_camera_position
var camera_zoom_factor:float = 1.0 : set = set_camera_zoom_factor
var camera_size:Vector2 = Vector2(1920, 1080)
#endregion


func _ready()-> void:
	state = States.IDLE
	camera_zoom_factor = initial_zoom_float
	camera_position = Vector2.ZERO
	
	#var vp = get_viewport()
	#vp.physics_object_picking = true
	

func get_camera()-> Camera2D:
	#return get_children()[0]
	return get_viewport().get_camera_2d()
	
	
func get_viewport_rect()-> Rect2:
	return Rect2(Vector2.ZERO, camera_size)#get_viewport().get_visible_rect()
	
	
func get_global_mouse_position()-> Vector2:
	return get_viewport().get_mouse_position()
	
		
func set_camera_position(value:Vector2)-> void:
	#print("Trying to set camera pos at %s" % value)
	camera_position = value
	
	# Actual camera size
	var acs = get_viewport_rect().size/camera_zoom_factor
	
	var real_min_x = min_x
	var real_min_y = min_y
	var real_max_x = max_x
	var real_max_y = max_y
	#if max_x - min_x < camera_size.x:
		#min_x = -camera_size.x / 2
		#max_x = camera_size.x / 2
		#var center_x = min_x+(max_x-min_x)/2
		#real_min_x = center_x-camera_size.x / 2
		#real_max_x = center_x+camera_size.x / 2
		
	#if max_y - min_y < camera_size.y:
		#min_y = -camera_size.y / 2
		#max_y = camera_size.y / 2
		#var center_y = min_y+(max_y-min_y)/2
		#real_min_y = center_y-camera_size.y / 2
		#real_max_y = center_y+camera_size.y / 2
		
	#if max_x - min_x < camera_size.x:
		#min_x = -camera_size.x / 2
		#max_x = camera_size.x / 2
	#if min_y < -camera_size.y/2:
		#min_y = -camera_size.y / 2
	#if min_x < -camera_size.x/2:
		#real_min_x = -camera_size.x/2
	#if min_y < -camera_size.y/2:
		#real_min_y = -camera_size.y/2
	#if max_y > camera_size.y/2:
		#real_max_y = camera_size.y/2
		
		
	var min_x_position = real_min_x + acs.x/2
	var max_x_position = real_max_x - acs.x/2
	
	var min_y_position = real_min_y + acs.y/2
	var max_y_position = real_max_y - acs.y/2
		
	 #Fix case where the limited area is smaller than the camera size
	#if max_x_position - min_x_position < camera_size.x:
		#min_x_position = -camera_size.x / 2
		#max_x_position = camera_size.x / 2
		#min_x_position = 0
		#max_x_position = 0
	#if max_y_position - min_y_position < camera_size.y:
		#min_y_position = -camera_size.y / 2
		#max_y_position = camera_size.y / 2
		#min_y_position = 0
		#max_y_position = 0
		
	#if min_y_position < -camera_size.y/2:
		#min_y_position = -camera_size.y / 2
	#if max_y_position > camera_size.y/2:
		#max_y_position = camera_size.y / 2
		
	camera_position.x = clamp(camera_position.x, min_x_position, max_x_position)
	camera_position.y = clamp(camera_position.y, min_y_position, max_y_position)


	#camera.position = camera_position
	offset = -camera_position + get_viewport_rect().size/2
	#print(camera_position)
		
		
func set_camera_zoom_factor(value:float)-> void:
	camera_zoom_factor = clamp(value, MIN_ZOOM_FACTOR, MAX_ZOOM_FACTOR)
	#camera.zoom = Vector2.ONE*camera_zoom_factor
	scale = Vector2.ONE*camera_zoom_factor 
	camera_position = camera_position # force update
	
			
func clamp_position(pos:Vector2)-> Vector2:
	pos.x = clamp(pos.x, min_x, max_x)
	pos.y = clamp(pos.y, min_y, max_y)
	return pos
	
	
#region State machine
func set_state(value:States)-> void:
	var old_value = state
	state = value
	#print(state)
	match old_value:
		#States.DRAGGING_ELEMENT:
			#stopped_dragging_elements.emit()
		_:
			pass
#endregion

#region Input

func get_mouse_pos()-> Vector2:	
	var pos = %ElementsLayer.get_viewport().get_mouse_position()
	var viewport_offset = %ElementsLayer.get_viewport().get_visible_rect().size/2
	var corrected_pos = pos/camera_zoom_factor + camera_position/camera_zoom_factor + viewport_offset
	
	return corrected_pos
	

func _unhandled_input(event: InputEvent) -> void:	
	#print("world received unhandled input")
	if not visible:return
	
	if event is InputEventMouseButton:
		var click = event as InputEventMouseButton
		match click.button_index:
			MOUSE_BUTTON_LEFT:
				_on_left_click(click.position - camera_position)
				if click.is_pressed():
					_on_left_click_pressed(click.position)
				if click.is_released():
					_on_left_click_released(click.position)					
			MOUSE_BUTTON_RIGHT:
				_on_right_click(click.position)
				if click.is_pressed():
					_on_right_click_pressed(click.position)
				if click.is_released():
					_on_right_click_released(click.position)	
			MOUSE_BUTTON_MIDDLE:
				if click.is_pressed():
					_on_middle_click_pressed(click.position)
				if click.is_released():
					_on_middle_click_released(click.position)						
			MOUSE_BUTTON_WHEEL_UP:
				_on_mouse_wheel_moved(click.factor)
			MOUSE_BUTTON_WHEEL_DOWN:
				_on_mouse_wheel_moved(-click.factor)
				
	if event is InputEventMouseMotion:
		_on_mouse_movement(event)
		
		
@warning_ignore("unused_parameter")
func _on_left_click(pos:Vector2)-> void:
	match state:
		States.IDLE:
			#print("Left click while IDLE")
			pass
			
			
func _on_left_click_pressed(pos:Vector2)-> void:	
	match state:
		States.IDLE:
			#print("Left click pressed while IDLE")			
			if drag_actions & MOUSE_BUTTON_MASK_LEFT:
				start_dragging_map(pos)
		#States.DRAGGING_ELEMENT:	
			#print("Left click pressed while DRAGGING_ELEMENT")
			
			
@warning_ignore("unused_parameter")
func _on_left_click_released(pos:Vector2)-> void:
	match state:
		#States.IDLE:
			#print("Left click released while IDLE")
		States.DRAGGING_MAP:
			#print("Left click released while DRAGGING_MAP")
			if drag_actions & MOUSE_BUTTON_MASK_LEFT:
				stop_dragging_map()
		
@warning_ignore("unused_parameter")
func _on_right_click(pos:Vector2)-> void:
	pass
	#match state:
		#States.IDLE:
			#print("Right click while IDLE")
		#States.DRAGGING_ELEMENT:	
			#print("Right click while DRAGGING_ELEMENT")
			
		
func _on_right_click_pressed(pos:Vector2)-> void:
	match state:
		States.IDLE:
			#print("Right click pressed while IDLE")	
			if drag_actions & MOUSE_BUTTON_MASK_RIGHT:
				start_dragging_map(pos)
			
		
@warning_ignore("unused_parameter")
func _on_right_click_released(pos:Vector2)-> void:
	match state:
		#States.IDLE:
			#print("Right click released while IDLE")
		#States.DRAGGING_ELEMENT:	
			#print("Right click released while DRAGGING_ELEMENT")
		States.DRAGGING_MAP:
			#print("Right click released while DRAGGING_MAP")
			if drag_actions & MOUSE_BUTTON_MASK_RIGHT:
				stop_dragging_map()
			
			
		
func _on_middle_click_pressed(pos:Vector2)-> void:
	match state:
		States.IDLE:
			#print("Middle click pressed while IDLE")	
			if drag_actions & MOUSE_BUTTON_MASK_MIDDLE:
				start_dragging_map(pos)
				
				
func _on_middle_click_released(_pos:Vector2)-> void:
	match state:
		States.DRAGGING_MAP:
			#print("Middle click pressed while IDLE")	
			if drag_actions & MOUSE_BUTTON_MASK_MIDDLE:
				stop_dragging_map()
				
				
func _on_mouse_wheel_moved(factor:float)-> void:
	#print("Mouse wheel moved. Factor: %s" % factor)
	if zoom_enabled:
		camera_zoom_factor += ZOOM_WHEEL_SENSIBILITY*factor
	
		
@warning_ignore("unused_parameter")
func _on_mouse_movement(event:InputEventMouseMotion)-> void:	
	pass
	
	
func _physics_process(_delta: float) -> void:
	if not visible: return
	if not drag_enabled: return
	
	match state:
		States.IDLE:
			#print("Mouse moved while IDLE")
			pass
		States.DRAGGING_MAP:	
			#print("Mouse moved at '%s' while DRAGGING_MAP" % event.global_position)
			update_map_dragging()
			
	var move:Vector2 = Vector2.ZERO
			
	# Keyboard movement
	if keyboard_movement_speed > 0:
		var move_dir = Vector2.ZERO
		if Input.is_action_pressed("drag_up", true):
			move_dir += Vector2.UP
		if Input.is_action_pressed("drag_right", true):
			move_dir += Vector2.RIGHT
		if Input.is_action_pressed("drag_down", true):
			move_dir += Vector2.DOWN
		if Input.is_action_pressed("drag_left", true):
			move_dir += Vector2.LEFT
		if move_dir.length() > 0:
			move_dir = move_dir.normalized()
			
		#move += move_dir*keyboard_movement_speed*_delta
		
	# Joystick movement
	if joystick_movement_speed > 0:
		var x = Input.get_joy_axis(0, JOY_AXIS_RIGHT_X)
		var y = Input.get_joy_axis(0, JOY_AXIS_RIGHT_Y)
		
		var strength = max(abs(x), abs(y))
		if strength >= 0.25:
			move += Vector2(x, y).normalized()*joystick_movement_speed
		
	camera_position += move
					
#endregion

#region Dragging

@warning_ignore("unused_parameter")
func start_dragging_map(pos:Vector2)-> void:
	var mouse_pos = get_global_mouse_position()
	last_mouse_position = mouse_pos
	state = States.DRAGGING_MAP
	
	
func stop_dragging_map()-> void:
	state = States.IDLE
	
	
func update_map_dragging()-> void:	
	var mouse_pos = get_global_mouse_position()	
	var diff = mouse_pos - last_mouse_position
	camera_position -= diff/camera_zoom_factor	
	last_mouse_position = mouse_pos
	
		
#endregion
