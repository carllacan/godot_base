extends Resource
class_name SettingInfo

@export var name:String
@export var dname:String : get = get_dname
# Just for reference purposes, will not be shown
@export_multiline var description:String = "" : get = get_description

@export var type:Variant.Type = Variant.Type.TYPE_BOOL
@export_group("If numeric type")
@export var min_value:float = 0 : get = get_min_value, set = set_min_value
@export var max_value:float = 10 : get = get_max_value, set = set_max_value
@export_group("If array type")
## Map from internal to external representation of this setting's possible values.
## Ex: {"en_EN":"English",es_ES": "Spanish"}
@export var options:Dictionary[String, String] = {}


func get_dname()-> String:
	return tr(dname)
	
	
func get_description()-> String:
	return tr(description)
	
	
func is_bool()-> bool:
	return type == Variant.Type.TYPE_BOOL


func get_min_value()-> float:
	match type:
		Variant.Type.TYPE_BOOL:
			return 0
		Variant.Type.TYPE_INT:
			return int(min_value)
		Variant.Type.TYPE_ARRAY:
			return NAN
		_:
			return min_value
	
	
func set_min_value(new_value:float)-> void:
	min_value = new_value
	
	
func get_max_value()-> float:
	match type:
		Variant.Type.TYPE_BOOL:
			return 1
		Variant.Type.TYPE_INT:
			return int(max_value)
		Variant.Type.TYPE_ARRAY:
			return NAN
		_:
			return max_value
	
	
func set_max_value(new_value:float)-> void:
	max_value = new_value


func get_value_representation(value:Variant)-> String:
	var val_str:String
	match type:
		Variant.Type.TYPE_BOOL:
			val_str = "ON" if value else "OFF"
		Variant.Type.TYPE_INT:
			val_str = str(value)
		Variant.Type.TYPE_ARRAY:
			if value in options:
				val_str = options[value]
			else:
				var msg = ""
				msg += "Value '%s' is not valid for setting '%s'" % [
					str(value), dname
				]
				msg += ", ".join(options.keys())
				push_error(msg)
		_:
			push_error("Unexpected setting type")
			
	return tr(val_str)
