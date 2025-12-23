extends Camera2D
class_name DraggableCamera


@export var zoom_enabled:bool = true
@export_flags(
	"LeftClick:%d" % MOUSE_BUTTON_MASK_LEFT, 
	"RightClick:%d" % MOUSE_BUTTON_MASK_RIGHT, 
	"MouseWheel:%d" % MOUSE_BUTTON_MASK_MIDDLE, 
	) var drag_actions:int = MOUSE_BUTTON_MASK_LEFT + MOUSE_BUTTON_MASK_MIDDLE


var drag_enabled:bool = true	
	
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

@export var keyboard_movement_speed:float = 500
@export var joystick_movement_speed:float = 10

var state:States = States._undef# : set = set_state
var zoom_factor:float = 1 : set = set_zoom_factor
var last_mouse_position:Vector2 = Vector2.INF


func _ready()-> void:
	state = States.IDLE 
	center()
	
	
func set_zoom_factor(value:float)-> void:
	zoom_factor = clamp(value, MIN_ZOOM_FACTOR, MAX_ZOOM_FACTOR)
	zoom = Vector2.ONE*zoom_factor
	
	
func center()-> void:
	position = Vector2.ZERO
	#position = get_viewport().get_visible_rect().size/2
	#print("Camera centerd at %s" % position)
	

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
		zoom_factor += ZOOM_WHEEL_SENSIBILITY*factor
	
		
@warning_ignore("unused_parameter")
func _on_mouse_movement(event:InputEventMouseMotion)-> void:	
	pass	
	if state == States.DRAGGING_MAP:
		update_map_dragging(event.relative)
	
	
func _physics_process(_delta: float) -> void:
	if not visible: return
	if not drag_enabled: return
	
	match state:
		States.IDLE:
			#print("Mouse moved while IDLE")
			pass
		#States.DRAGGING_MAP:	
			##print("Mouse moved at '%s' while DRAGGING_MAP" % event.global_position)
			#update_map_dragging()
			
	var move:Vector2 = Vector2.ZERO
	
	# Keyboard movement
	if keyboard_movement_speed > 0:
		var move_dir = InputManager.get_direction("drag")
		move += move_dir*keyboard_movement_speed*_delta
		
	# Joystick movement
	if joystick_movement_speed > 0:
		var jpos = InputManager.get_right_joystick_position()
		if jpos.length() >= 0.1:
			move += jpos*joystick_movement_speed
			
		
	position += move
	
	clamp_position()
					
#endregion

#region Dragging

func start_dragging_map(_pos:Vector2)-> void:
	var mouse_pos = get_global_mouse_position()
	last_mouse_position = mouse_pos
	state = States.DRAGGING_MAP
	
	
func stop_dragging_map()-> void:
	state = States.IDLE
	
	
func update_map_dragging(diff)-> void:	
	position -= diff/zoom_factor	
	clamp_position()
	
	
func clamp_position()-> void:
	position.x = clamp(position.x, min_x, max_x)
	position.y = clamp(position.y, min_y, max_y)
	
		
#endregion


func _unhandled_input(event: InputEvent) -> void:	
	#print("world received unhandled input")
	if not visible:return
	
	if event is InputEventMouseButton:
		var click = event as InputEventMouseButton
		match click.button_index:
			MOUSE_BUTTON_LEFT:
				_on_left_click(click.position - position)
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
		
