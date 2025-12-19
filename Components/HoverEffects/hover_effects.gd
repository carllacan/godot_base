extends Node
class_name HoverEffects


@export var on_hover:bool = true
@export var on_focus:bool = false
@export var modulate_factor:Color = Color(1.0, 1.0, 1.0, 0.8)

var original_modulate:Color

var is_parent_hovered:bool = false : set = set_is_parent_hovered
var is_parent_focused:bool = false : set = set_is_parent_focused


func _ready()-> void:
	get_parent().ready.connect(_on_parent_ready)
	original_modulate = get_parent().modulate
	
	
func set_is_parent_hovered(new_value:bool)-> void:
	is_parent_hovered = new_value
	update_effects()
	
	
func set_is_parent_focused(new_value:bool)-> void:
	is_parent_focused = new_value
	update_effects()
	
	
func _on_parent_ready()-> void:
	var p = get_parent()
	p.mouse_entered.connect(_on_mouse_entered_target_control.bind(p))
	p.mouse_exited.connect(_on_mouse_exited_target_control.bind(p))
	p.focus_entered.connect(_on_focus_entered_target_control.bind(p))
	p.focus_exited.connect(_on_focus_exited_target_control.bind(p))
		
	
func _on_mouse_entered_target_control(_control:Control)-> void:
	if not on_hover: return
	is_parent_hovered = true
		
		
func _on_mouse_exited_target_control(_control:Control)-> void:
	if not on_hover: return
	is_parent_hovered = false
		
		
func _on_focus_entered_target_control(_control:Control)-> void:
	if not on_focus: return
	is_parent_focused = true
	
	
func _on_focus_exited_target_control(_control:Control)-> void:
	if not on_focus: return
	is_parent_focused = false
		
		
func update_effects()-> void:
	if is_parent_hovered or is_parent_focused:
		get_parent().modulate = original_modulate*modulate_factor
	else:
		get_parent().modulate = original_modulate
