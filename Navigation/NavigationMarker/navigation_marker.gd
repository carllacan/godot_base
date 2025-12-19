extends Node

signal performed

@export var to_hide:Array[Node]
@export var to_show:Array[Node]
@export var action_shortcut:String = ""


func _ready()-> void:
	var parent = get_parent()
	parent.ready.connect(_on_parent_ready)
	
	if null in to_hide or null in to_show:
		push_error("Null references in '%s'" % get_path())
	
	if parent is Button:
		parent.pressed.connect(_on_parent_button_pressed)
	else:
		push_error("Unexpected parent type")
		

func _on_parent_ready()-> void:
	return


func _on_parent_button_pressed()-> void:
	perform_navigation()
	
	
func perform_navigation()-> void:
	for node in to_hide:
		node.hide()
	for node in to_show:
		node.show()
	performed.emit()


func can_perform()-> bool:
	if not is_node_ready(): return false
	
	# check if any of the elements that must be shown is already visible
	if to_show.any(func(n): return n.visible): 
		return false
	# check if any of the elements that must be shown is already invisible
	if to_hide.any(func(n): return not n.visible): 
		return false
		
	return true
		

func _input(event: InputEvent) -> void:
	if action_shortcut == "": return
	if not can_perform(): 
		return
	
	if event.is_action_pressed(action_shortcut):
		get_viewport().set_input_as_handled()
		perform_navigation()
