extends Control
class_name BaseDraggableGameWorld

## old class that attempted to create a world AND make it draggable

const ZOOM_WHEEL_SENSIBILITY:float = 0.1
const MIN_ZOOM_FACTOR:float = 0.5
const MAX_ZOOM_FACTOR:float = 1.5

signal stopped_dragging_elements
signal drag_or_place_finished(accepted)

enum States {
	_undef,
	BLOCKED,
	IDLE,
	DRAGGING_MAP,
	DRAGGING_ELEMENT,
	PLACING_ELEMENT,
}

@export var min_x:float = -1000
@export var max_x:float = +1000
@export var min_y:float = -1000
@export var max_y:float = +1000
@export var show_grid:bool = false : set = set_show_grid
@export var camera_enabled:bool = true : set = set_camera_enabled

var state:States = States._undef : set = set_state
var elements:Array[BaseWorldElement] = []
var target_element_is_new:bool = false

#region Mouse following
# Element that will follow the mouse
var attached_to_mouse:BaseWorldElement
# Position where the attached element should go, which will then be clamped
# (needs to be made persistent so that it is not clamped itself)
var attached_element_target_position:Vector2
#endregion

#region Hovering
var hovered_elements:Array[BaseWorldElement] = []
#endregion

#region Map dragging
var initial_drag_position:Vector2
var last_mouse_position:Vector2
var camera_position:Vector2 : set = set_camera_position
var camera_zoom_factor:float = 1.0 : set = set_camera_zoom_factor
#endregion

#region Drag&drop
var dragged_element:BaseWorldElement
# Where the currently dragged element started, so it can snap back if canceled
var dragged_element_initial_position:Vector2
var dragged_element_offset:Vector2
#endregion

#region Element placing
var placing_element:BaseWorldElement
# Where the currently placed element started, so it can snap back if canceled
var placing_element_initial_position:Vector2
#endregion

#region Grid

# A grid that can be shown for debugging or as a help for the player

var grid_cell_size:Vector2 = Vector2.ONE*5.0 : set = set_grid_cell_size
var grid_offset:Vector2 = Vector2.ZERO : set = set_grid_offset

#endregion
@onready var camera:Camera2D = %Camera 
@onready var grid:TextureRect = %Grid


func _ready()-> void:
	stopped_dragging_elements.connect(_on_dragging_elements_stopped)
	min_x = snapped(min_x, -grid_cell_size.x)
	max_x = snapped(max_x, grid_cell_size.x)
	update_grid()
	state = States.IDLE
	
	
func set_camera_position(value:Vector2)-> void:
	camera_position = value
	
	var camera_size = get_viewport_rect().size/camera_zoom_factor
	
	var min_x_position = min_x + camera_size.x/2
	var max_x_position = max_x - camera_size.x/2
	
	var min_y_position = min_y + camera_size.y/2
	var max_y_position = max_y - camera_size.y/2
	
	camera_position.x = clamp(camera_position.x, min_x_position, max_x_position)
	camera_position.y = clamp(camera_position.y, min_y_position, max_y_position)

	camera.position = camera_position
	grid_offset = camera_position
	#print(camera_position)
		
		
func set_camera_zoom_factor(value:float)-> void:
	camera_zoom_factor = clamp(value, MIN_ZOOM_FACTOR, MAX_ZOOM_FACTOR)
	%Camera.zoom = Vector2.ONE*camera_zoom_factor
	camera_position = camera_position
	update_grid()
	
		
func set_camera_enabled(value:bool)-> void:
	camera_enabled = value
	%Camera.enabled = camera_enabled
	
	
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
		States.DRAGGING_ELEMENT:
			stopped_dragging_elements.emit()
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
		States.DRAGGING_ELEMENT:	
			#print("Left click while DRAGGING")
			pass
			
			
func _on_left_click_pressed(pos:Vector2)-> void:	
	match state:
		States.IDLE:
			#print("Left click pressed while IDLE")
			
			var e = get_element_at(get_mouse_pos())
			if e != null and e.is_draggable:
				start_dragging_element(e)
			else:
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
			stop_dragging_map()
		States.DRAGGING_ELEMENT:	
			#print("Left click released while DRAGGING_ELEMENT")
			stop_dragging_element(true)
		States.PLACING_ELEMENT:	
			#print("Left click released while PLACING_ELEMENT")
			stop_placing_element(true)
			
		
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
			start_dragging_map(pos)
		States.DRAGGING_ELEMENT:	
			#print("Right click pressed while DRAGGING_ELEMENT")
			cancel_element_dragging()
		States.PLACING_ELEMENT:	
			#print("Right click pressed while DRAGGING_ELEMENT")
			cancel_placing_element()
			
		
@warning_ignore("unused_parameter")
func _on_right_click_released(pos:Vector2)-> void:
	match state:
		#States.IDLE:
			#print("Right click released while IDLE")
		#States.DRAGGING_ELEMENT:	
			#print("Right click released while DRAGGING_ELEMENT")
		States.DRAGGING_MAP:
			#print("Right click released while DRAGGING_MAP")
			stop_dragging_map()
			
			
func _on_mouse_wheel_moved(factor:float)-> void:
	#print("Mouse wheel moved. Factor: %s" % factor)
	camera_zoom_factor += ZOOM_WHEEL_SENSIBILITY*factor
	
		
@warning_ignore("unused_parameter")
func _on_mouse_movement(event:InputEventMouseMotion)-> void:	
	pass
	
	
func _physics_process(_delta: float) -> void:
	match state:
		States.IDLE:
			#print("Mouse moved while IDLE")
			pass
		States.DRAGGING_ELEMENT:	
			pass
			#print("Mouse moved at '%s' while DRAGGING_ELEMENT" % event.global_position)
			#update_element_dragging()
			# Stop/cancel dragging here as well, in case the press-release event started somewhere else
			# (When an element is dragged from other layer the input is not received until mouse release)
			if not Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
				stop_dragging_element(true)
			if Input.is_mouse_button_pressed(MOUSE_BUTTON_RIGHT):
				stop_dragging_element(false)
		States.DRAGGING_MAP:	
			#print("Mouse moved at '%s' while DRAGGING_MAP" % event.global_position)
			update_map_dragging()
			
	if attached_to_mouse != null:
		update_mouse_following()
		
#endregion

#region Grid

func set_show_grid(value:bool)-> void:
	show_grid = value
	update_grid()
	
	
func set_grid_cell_size(value:Vector2)-> void:
	grid_cell_size = value
	update_grid()
	
	
func set_grid_offset(value:Vector2)-> void:
	grid_offset = value
	update_grid()
	
	
func update_grid()-> void:
	if not is_node_ready(): return
	grid.visible = show_grid
	
	var target_size = get_viewport_rect().size
	var grad = %Grid.texture as GradientTexture2D
	if grad.width != target_size.x:
		grad.width = target_size.x
	if grad.height != target_size.y:
		grad.height = target_size.y
		
	var shader = grid.material as ShaderMaterial
	shader.set_shader_parameter("cell_size", grid_cell_size*camera_zoom_factor)
	shader.set_shader_parameter("offset", grid_offset*camera_zoom_factor)
	#print("Grid set to %s size, with %s offset" % [grid_cell_size, grid_offset])


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

#region Mouse following

func attach_element_to_mouse(element:BaseWorldElement)-> void:
	attached_element_target_position = element.position
	attached_to_mouse = element
	
	
func detach_element_from_mouse()-> void:
	attached_to_mouse = null
	
	
func update_mouse_following()-> void:	
	var mouse_pos = get_global_mouse_position()/camera_zoom_factor
	mouse_pos -= (get_viewport_rect().size/2)/camera_zoom_factor
	mouse_pos += camera_position
	attached_to_mouse.position = clamp_position(mouse_pos)
	
#endregion

#region Element drag&drop

func start_dragging_element(target_element:BaseWorldElement)-> void:
	if not Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
		push_warning("Can't drag an element if LMB is not pressed")
		drag_or_place_finished.emit(false)
		return
	#print("Started dragging element")
	state = States.DRAGGING_ELEMENT
	dragged_element_initial_position = target_element.position
	
	attach_element_to_mouse(target_element)
	dragged_element = target_element
	print("Started dragging element")
	
	
func drop_element(_target_element:BaseWorldElement)-> void:
	stop_dragging_element(true)
	# consequences
	
	
func cancel_element_dragging()-> void:
	stop_dragging_element(false)
	
	
func stop_dragging_element(success:bool)-> void:
	var e = dragged_element
	print("Stopped dragging element")
	detach_element_from_mouse()
	
	if not success:
		dragged_element.position = dragged_element_initial_position
			
	dragged_element = null
	
	if target_element_is_new:
		if not success: remove_element(e)
		target_element_is_new = false
		
	state = States.IDLE
	
	# When everything has been done, notify upwards
	drag_or_place_finished.emit(success)
		
	
	
func _on_dragging_elements_stopped()-> void:
	update_element_hovering()
	
	
func drag_new_element(new_element:BaseWorldElement)-> void:
	add_element(new_element)
	target_element_is_new = true
	start_dragging_element(new_element)
	
#endregion


#region Element placing
	
func start_placing_element(new_element)-> void:
	attach_element_to_mouse(new_element)
	placing_element = new_element
	placing_element_initial_position = placing_element.position
	state = States.PLACING_ELEMENT
	
	
func stop_placing_element(success:bool)-> void:
	var e = placing_element
	print("Stopped placing element")
	
	detach_element_from_mouse()
	if not success:
		placing_element.position = placing_element_initial_position
		
	placing_element = null
	
	if target_element_is_new:
		if not success: remove_element(e)
		target_element_is_new = false
		
	state = States.IDLE
	
	# When everything has been done, notify upwards
	drag_or_place_finished.emit(success)
	
	
func cancel_placing_element()-> void:
	stop_placing_element(false)
	
	
func place_new_element(new_element:BaseWorldElement)-> void:
	add_element(new_element)
	start_placing_element(new_element)
	target_element_is_new = true
	
#endregion

#region Element management

func add_element(new_element:BaseWorldElement)-> void:
	elements.append(new_element)
	
	new_element.ignore_mouse_movements = true
	new_element.mouse_entered.connect(_on_mouse_entered_element.bind(new_element))
	new_element.mouse_exited.connect(_on_mouse_exited_element.bind(new_element))
	new_element.released.connect(update_element_hovering)
		
	%ElementsLayer.add_child(new_element)
	
	
func add_element_at_pos(new_element:BaseWorldElement, pos:Vector2)-> void:
	new_element.position = pos
	add_element(new_element)
	
	
func _on_mouse_entered_element(element:BaseWorldElement)-> void:
	hovered_elements.append(element)
	update_element_hovering()
	
	
func _on_mouse_exited_element(element:BaseWorldElement)-> void:
	hovered_elements.erase(element)
	update_element_hovering()
	element.mouse_inside = false
	

func update_element_hovering()-> void:
	if hovered_elements.is_empty(): return
	
	var element_on_top = hovered_elements[0]
	for e in hovered_elements:
		e.mouse_inside = false
		if e.z_index >= element_on_top.z_index:
			element_on_top = e
	if state == States.DRAGGING_ELEMENT:
		pass
		#dragged_element.mouse_inside
	else:
		element_on_top.mouse_inside = true
			
	
func remove_element(target_element:BaseWorldElement)-> void:
	elements.erase(target_element)
	%ElementsLayer.remove_child(target_element)
	
	
func remove_all_elements()-> void:
	for e in elements.duplicate():
		remove_element(e)
	
	
# TODO: right now it just looks at the hovedwe elemenmt	
func get_element_at(_pos)-> BaseWorldElement:
	for element in elements:
		if element.is_mouse_inside():
			return element
			
	return null
	
	
#endregion
