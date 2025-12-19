extends Node
#class_name BaseInputManager

const TYPE_CHANGE_DEADTIME = 0.5

signal type_changed(new_type:ControllerTypes)
signal virtual_cursor_clicked
signal joypad_disconnected


enum ControllerTypes {
	KBM,
	JOYPAD
}

var current_controller_type:ControllerTypes = ControllerTypes.KBM :
	set = set_current_controller_type

var virtual_cursor:VirtualCursor : set = set_virtual_cursor
var type_change_deadtime:float = 0


func _ready()-> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	Input.joy_connection_changed.connect(_on_joy_connection_changed)
	

func _on_joy_connection_changed(device: int, connected: bool)-> void:
	# Send a pause event if a joypad was active but was disconnected
	if is_joypad():
		if device == 0: # no support for several controllers yet
			if not connected:
				joypad_disconnected.emit()	
				Pause.paused_externally.emit()
	
	
func _input(event: InputEvent) -> void:	
	# Change the current type if a KBM or joypad event comes.
	# Ignore changes for a while after a change to avoid glitches.
	if type_change_deadtime > 0:
		return
		
	# If the event is a Joypad input, change the type
	if event is InputEventJoypadButton or event is InputEventJoypadMotion:
		var must_change := true
		if event is InputEventJoypadMotion:
			var strength = abs(event.axis_value)
			
			if strength < 0.05:
				must_change = false
				
		if must_change:
			current_controller_type = ControllerTypes.JOYPAD
		
	# If the event is a mouse input, change the type
	if event is InputEventMouse:
		var must_change := true
		if event is InputEventMouseMotion:
			var strength = event.screen_relative.length()
			if strength < 5:
				must_change = false
		
		if must_change:
			current_controller_type = ControllerTypes.KBM
			

func set_virtual_cursor(value:VirtualCursor)-> void:
	if virtual_cursor != null:
		virtual_cursor.clicked.disconnect(virtual_cursor_clicked.emit)
		
	virtual_cursor = value	
	virtual_cursor.clicked.connect(virtual_cursor_clicked.emit)
	

func set_current_controller_type(value:ControllerTypes)-> void:
	var old_value = current_controller_type
	current_controller_type = value
	
	if old_value != current_controller_type:
		_on_controller_type_changed()
		
	
func _on_controller_type_changed()-> void:
	type_changed.emit(current_controller_type)
	# Reset the change timeout
	type_change_deadtime = TYPE_CHANGE_DEADTIME
	#print("Controller type changed to %s" % current_controller_type)
	match current_controller_type:
		ControllerTypes.KBM:
			Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		ControllerTypes.JOYPAD:
			Input.mouse_mode = Input.MOUSE_MODE_HIDDEN
	
	
func is_joypad()-> bool:
	return current_controller_type == ControllerTypes.JOYPAD
	
	
func is_kbm()-> bool:
	return current_controller_type == ControllerTypes.KBM
	
		
# Returns the vector resulting from summing 4 actions that correspond to the
# four directions.
func get_actions_directions(
	action_up:String,
	action_right:String,
	action_down:String,
	action_left:String
	)-> Vector2:
		
	# Assume none at the start
	var move_dir = Vector2.ZERO
	
	# Sum the vector corresponding to each action
	if Input.is_action_pressed(action_up, true):
		move_dir += Vector2.UP
	if Input.is_action_pressed(action_right, true):
		move_dir += Vector2.RIGHT
	if Input.is_action_pressed(action_down, true):
		move_dir += Vector2.DOWN
	if Input.is_action_pressed(action_left, true):
		move_dir += Vector2.LEFT
		
	# Normalize unless no action has resulted
	if move_dir != Vector2.ZERO:
		move_dir = move_dir.normalized()
		
	return move_dir
		
		
# Get the resulting vector from summing 4 actions with a common prefix and ended
# with _up, _right, _down and _left.
func get_direction(action_prefix:String)-> Vector2:
	return get_actions_directions(
		action_prefix + "_up",
		action_prefix + "_right",
		action_prefix + "_down",
		action_prefix + "_left",
	)
		
		
func get_right_joystick_position(device:int = 0)-> Vector2:	
	# TODO: cache position, lazy-update it every frame
	var x = Input.get_joy_axis(device, JOY_AXIS_RIGHT_X)
	var y = Input.get_joy_axis(device, JOY_AXIS_RIGHT_Y)
	return Vector2(x, y)
	
	
func get_left_joystick_position(device:int = 0)-> Vector2:	
	# TODO: cache position, lazy-update it every frame
	var x = Input.get_joy_axis(device, JOY_AXIS_LEFT_X)
	var y = Input.get_joy_axis(device, JOY_AXIS_LEFT_Y)
	return Vector2(x, y)
	
	
func get_cursor_pos(viewport:Viewport = null)-> Vector2:
	if is_kbm():
		if viewport == null:
			return get_viewport().get_mouse_position()
		else:
			return viewport.get_mouse_position()
	else:
		return get_virtual_cursor_pos()
			
						
func has_virtual_cursor()-> bool:
	if virtual_cursor == null: return false
	if not virtual_cursor.is_node_ready(): return false
	
	return true
	
			
func get_virtual_cursor_pos(viewport:Viewport = null)-> Vector2:
	if not has_virtual_cursor():
		return Vector2.INF
		
	if virtual_cursor.get_viewport() == viewport:
		return virtual_cursor.position
	else:
		var gpos = virtual_cursor.get_global_position()
		if viewport == null:
			return gpos
		else:
			var transform = viewport.get_canvas_transform()
			return transform.affine_inverse().basis_xform(gpos)
	

func _process(delta: float) -> void:
	# Discount some dead time, then clamp to zero
	if type_change_deadtime >= 0:
		type_change_deadtime -= delta
		if type_change_deadtime < 0: type_change_deadtime = 0
