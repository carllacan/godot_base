@tool
extends Label

@export var long:bool = true : set = set_long


func _ready()-> void:
	if Engine.is_editor_hint():
		text = "editor_build"
		return
		
	if long:
		text = Dist.get_version()
	else:
		text = Dist.get_version_num()
		
	if text == "":
		text = "no_version"
		

func set_long(value:bool)-> void:
	long = value
	if not is_node_ready(): return
	
	if long:
		text = "v1.2.3_something"
	else:
		text = "v1.2.3"
