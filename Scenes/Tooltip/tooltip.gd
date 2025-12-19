@tool
extends Control
class_name Tooltip
const SCENE = preload("res://GodotBase/Scenes/Tooltip/tooltip.tscn")

@export var target_controls:Array[Control] = []
@export var on_hover:bool = true
@export var on_focus:bool = false
@export var use_default_contents:bool = true : set = set_use_default_contents
@export var multiline:bool = false
@export var verbose:bool = false


@export_multiline var text:String : get = get_text, set = set_text

var hovered_controls:Array[Control] = []
var focused_controls:Array[Control] = []


@onready var text_contents = %TextContents


func _ready()-> void:
	for c in target_controls:
		add_target_control(c)
	
	update_visiblity()
	
	
func get_text()-> String:
	return text
	
	
func set_text(value:String)-> void:
	text = value
	update_info()
	
	
func set_use_default_contents(value:bool)-> void:
	use_default_contents = value
	update_info()
	
	
func add_target_control(control:Control)-> void:
	control.mouse_entered.connect(_on_mouse_entered_target_control.bind(control))
	control.mouse_exited.connect(_on_mouse_exited_target_control.bind(control))
	control.focus_entered.connect(_on_focus_entered_target_control.bind(control))
	control.focus_exited.connect(_on_focus_exited_target_control.bind(control))
	
	
func _on_mouse_entered_target_control(control:Control)-> void:
	if not on_hover: return
	if not control in hovered_controls:
		hovered_controls.append(control)
	update_visiblity()
		
		
func _on_mouse_exited_target_control(control:Control)-> void:
	if control in hovered_controls:
		hovered_controls.erase(control)
	update_visiblity()
		
		
func _on_focus_entered_target_control(control:Control)-> void:
	if not on_focus: return
	if not control in focused_controls:
		focused_controls.append(control)
	update_visiblity()
	
	
func _on_focus_exited_target_control(control:Control)-> void:
	if control in focused_controls:
		focused_controls.erase(control)
	update_visiblity()
		
	
func update_visiblity()-> void:
	if focused_controls.is_empty() and hovered_controls.is_empty():
		hide()
	else:
		appear()
		
	if use_default_contents:
		%TextContents.show()
		if text_contents.text == "":
			push_warning("Tooltip being shown, but text is empty")
			hide()
	else:
		%TextContents.hide()
		
		
func appear()-> void:
	update_info()
	show()
	
	
func disappear()-> void:
	hide()
	
	
func update_info()-> void:
	if not is_node_ready(): return
	
	text_contents.text = text
				
	
