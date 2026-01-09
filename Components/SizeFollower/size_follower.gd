@tool
extends Node
class_name SizeFollower


@export var control_followed:Control
@export var follow_visibility:bool = true


func _ready()-> void:
	get_parent().ready.connect(_on_parent_ready)
	
	
func _on_parent_ready()-> void:
	if control_followed == null: return
	
	control_followed.ready.connect(_on_target_ready)
	control_followed.resized.connect(_on_target_resized)
	control_followed.visibility_changed.connect(_on_target_visibility_changed)
	follow_size()
	
	
func _on_target_ready()-> void:
	follow_size()
	
		
func _on_target_resized()-> void:
	follow_size()
	
	
func _on_target_visibility_changed()-> void:
	follow_size()
	
	
func follow_size()-> void:
	if get_parent() == null or not get_parent().is_node_ready(): return
	
	var new_size:Vector2 = control_followed.size
		
	get_parent().custom_minimum_size = new_size
	get_parent().size = new_size
	
	if follow_visibility:
		get_parent().visible = control_followed.visible
