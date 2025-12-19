extends Control
class_name InteractiveNode
const SCENE = preload("uid://dllaklutysa0")


signal pressed
signal released
signal hovered
signal unhovered


enum Styles {
	_undef,
	NORMAL,
	DISABLED,
	HOVERED,
	PRESSED,
}

#var state:States = States._undef : set = set_state
var style:Styles = Styles._undef : set = set_style

var is_pressed:bool = false : set = set_is_pressed
var mouse_inside:bool = false : set = set_mouse_inside
var is_focused:bool = false : set = set_is_focused

# Tracks how much of the hovering animation has passed, from 0.0 to 1.0
var style_animation_progress:float = 0 : set = set_style_animation_progress

@export_subgroup("Configuration")
@export var ignore_mouse_movements:bool = false
@export var is_clickable:bool = false
@export var is_disabled:bool = false : set = set_is_disabled
@export var default_focus:bool = false 

@export_subgroup("Hover effects")
@export var hover_animation_length_s:float = 0.1
@export var hovered_scale_target:Vector2 = Vector2.ONE
@export var hovered_modulate_target:Color = Color.WHITE
@export var hovered_rotation_degrees_target:float = 0
#@export var hovered_position_degrees_target:Vector2 = Vector2.ZERO

@export_subgroup("Colors", "color_")
@export var color_normal:Color = Color.WHITE
@export var color_hovered:Color = Color.YELLOW
@export var color_pressed:Color = Color.DARK_KHAKI
@export var color_disabled:Color = Color.GRAY

@export_subgroup("Debug")
@export var verbose:bool = false

@onready var base_sprite:Node2D = %ButtonSprite
@onready var normal_sprite:Sprite2D = %NormalSprite
@onready var click_area:Area2D = %ClickArea


func _ready()-> void:
	focus_entered.connect(_on_focused)
	focus_exited.connect(_on_unfocused)
	
	click_area.mouse_entered.connect(_on_mouse_entered_click_area)
	click_area.mouse_exited.connect(_on_mouse_exited_click_area)

	if default_focus:
		call_deferred("grab_focus")
	
	#style = Styles.NORMAL
	update_style()
	

func set_is_disabled(value:bool)-> void:
	is_disabled = value
	#update_state()
	update_style()
	
	
func set_is_pressed(value:bool)-> void:
	is_pressed = value
	#update_state()
	update_style()
	
	
func set_is_focused(value:bool)-> void:
	#var old_value = is_focused
	is_focused = value
	update_style()
	#if old_value == true and is_focused == false:
		#_on_focused()
		#unfocused.emit()
	#if old_value == false and is_focused == true:
		#_on_unfocused()
		#focused.emit()		
	
	
func is_mouse_inside()-> bool:
	return mouse_inside
	
	
func set_mouse_inside(value:bool)-> void:
	var old_value = mouse_inside
	mouse_inside = value
	#update_state()
	update_style()
	if old_value == true and mouse_inside == false:
		unhovered.emit()
	if old_value == false and mouse_inside == true:
		hovered.emit()
	
#region Styling

func update_style()-> void:
	if not is_node_ready(): return
	
	if is_pressed:
		style = Styles.PRESSED
	else:
		if is_disabled:
			style = Styles.DISABLED
		else:
			#style = Styles.NORMAL			
			if is_mouse_inside() or is_focused:
				style = Styles.HOVERED
			else:
				style = Styles.NORMAL
				
				
func set_style(value:Styles)-> void:
	var old_value = style
	style = value
	if not is_inside_tree(): return
	
	if old_value != style:
		match style:
			Styles.NORMAL:
				set_normal_style()
			Styles.DISABLED:
				set_disabled_style()
			Styles.PRESSED:
				set_pressed_style()
			Styles.HOVERED:
				set_hovered_style()
		
	_on_style_animation_progress_changed()
	
			
func set_normal_style()-> void:
	base_sprite.modulate = color_normal
	
			
func set_disabled_style()-> void:
	base_sprite.modulate = color_disabled
	
			
func set_pressed_style()-> void:
	base_sprite.modulate = color_pressed
	
			
func set_hovered_style()-> void:
	base_sprite.modulate = color_hovered
	

#endregion styling
		
#region Control
	
func press_button()-> void:
	_on_pressed()
	
	
#endregion

#region Animations

func update_style_animation(delta: float) -> void:
	if not is_pressed:
		if mouse_inside and not is_disabled:
			style_animation_progress += delta/hover_animation_length_s
		else:
			style_animation_progress -= delta/hover_animation_length_s
	

func set_style_animation_progress(value:float)-> void:
	var old_value = style_animation_progress
	
	style_animation_progress = clamp(value, 0.0, 1.0)	
	if is_zero_approx(old_value - style_animation_progress): return
	_on_style_animation_progress_changed()
	
	
func _on_style_animation_progress_changed()-> void:
	base_sprite.scale = lerp(Vector2.ONE, hovered_scale_target, style_animation_progress)
	base_sprite.rotation_degrees = lerp(0.0, hovered_rotation_degrees_target, style_animation_progress)
	
	
#endregion

#region Callbacks

func _on_mouse_entered_click_area()-> void:
	mouse_entered.emit()
	if ignore_mouse_movements: return
	mouse_inside = true
	
	
func _on_mouse_exited_click_area()-> void:
	mouse_exited.emit()
	if ignore_mouse_movements: return
	mouse_inside = false
	
	
func _on_focused()-> void:
	pass
	is_focused = true
	
	
func _on_unfocused()-> void:
	is_focused = false
	pass
	
	
func _on_pressed()-> void:
	pressed.emit()
	
	
#endregion

func _physics_process(delta: float) -> void:
	update_style_animation(delta)
	
	
func update_is_mouse_inside()-> void:
	return
	
	
func _on_gui_input_catcher_focus_exited() -> void:
	pass
	#update_is_mouse_inside()
	
	
func _gui_input_catcher_gui_input(event: InputEvent) -> void:
#func _gui_input_catcher_gui_input(event: InputEvent) -> void:
	#print(name + " gui event " + str(Engine.get_frames_drawn()))
	if is_disabled: return
	if not visible: return
	
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT:
			#if event.is_pressed():			
				#if is_mouse_inside():
					#is_pressed = true
			if event.is_released():		
				if is_mouse_inside():
					press_button()
				is_pressed = false
				released.emit()
				
	#if event is InputEventMouseMotion:
		#update_is_mouse_inside()
			
	
	if is_focused:
		if event.is_action_pressed("ui_accept"):
			press_button()
