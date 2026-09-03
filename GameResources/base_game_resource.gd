extends Resource
class_name BaseGameResource


@export var dname:String
@export var icon:Texture
@export var description:String


func _to_string() -> String:
	return dname


func get_bbcode(size:int = 12)-> String:
	return "[img=%dx%d]%s[/img]" % [size, size, icon.resource_path]
