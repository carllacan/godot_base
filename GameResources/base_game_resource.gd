extends Resource
class_name BaseGameResource

## Used to refer to this resource internally
@export var id:String
## Displayed in indicators, inline...
@export var icon:Texture
@export_group("DisplayedInfo")
## The name the player will see for this resource
@export var dname:String
## A description that might show up in tooltips
@export var description:String


func _to_string() -> String:
	return dname


func get_bbcode(size:int = 12)-> String:
	return "[img=%dx%d]%s[/img]" % [size, size, icon.resource_path]
