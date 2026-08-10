@tool
extends BaseComponent
class_name SizeFollower


@export var control_followed:Control
@export var follow_visibility:bool = true


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
	var t := get_target()
	if t == null or not t.is_node_ready(): return

	var new_size:Vector2 = control_followed.size

	t.custom_minimum_size = new_size
	t.size = new_size

	if follow_visibility:
		t.visible = control_followed.visible


func _is_parent_valid()-> bool:
	return get_target() is Control
