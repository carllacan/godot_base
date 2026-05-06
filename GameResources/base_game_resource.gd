extends Resource
class_name BaseGameResource


@export var dname:String
@export var icon:Texture
@export var description:String


func _to_string() -> String:
	return dname
