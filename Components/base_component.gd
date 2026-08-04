extends Node
class_name BaseComponent
## Represents a component that can be added to other nodes. Includes several
## useful properties, methods...


func _ready()-> void:
	var p = get_parent()
	p.ready.connect(_on_parent_ready)
	
	
func _on_parent_ready()-> void:
	pass
