extends Resource
class_name Modifier

enum Mode {
	_undef,
	ADDITIVE,
	MULTIPLICATIVE,
}

@export var key:String
@export var value:float = 0 : get = get_value
@export var mode:Mode = Mode.ADDITIVE
@export var description:String
@export_group("Debug")
@export var override_value:float
@export var apply_override:bool = false

var origin:Resource

## TODO: turn into a wrapper for apply, to avoid code duplication
@warning_ignore("shadowed_variable")
static func apply_all(base_value, key:String, sources:Array)-> float:
	var result = base_value
	for s in sources:
		assert(s is Array[Modifier])
		for mod:Modifier in s:
			if mod.key == key:
				result = mod.apply(result)
				
	return result


@warning_ignore("shadowed_variable")
static func apply_list(base_value, key:String, modifiers:Array[Modifier])-> float:
	var result = base_value
	for mod:Modifier in modifiers:
		if mod.key == key:
			result = mod.apply(result)				
	return result


@warning_ignore("shadowed_variable")
static func make_new_additive(key:String, value:float)-> Modifier:
	var m = Modifier.new()
	m.key = key
	m.value = value
	m.mode = Mode.ADDITIVE
	return m
	

@warning_ignore("shadowed_variable")
static func make_new_multiplicative(key:String, value:float)-> Modifier:
	var m = Modifier.new()
	m.key = key
	m.value = value
	m.mode = Mode.MULTIPLICATIVE
	return m
	
	
func apply(base_value)-> float:
	match mode:
		Mode.ADDITIVE:
			return base_value + value
		Mode.MULTIPLICATIVE:
			return base_value * (1.0+value)
		_:
			push_error("Unknown mode %s" % mode)
			return NAN
			
			
func get_value()-> float:
	if Engine.is_editor_hint():
		# Skip the override in the editor to avoid getter errors
		return value

	if apply_override and Flags.DEBUG:
		return override_value
	else:
		return value
		
		
## Returns the value, transforming to % if it's a multiplicative mod
func get_value_str()-> String:
	match mode:
		Mode.ADDITIVE:
			return "%1.0f" % value
		Mode.MULTIPLICATIVE:
			return "%1.0f" % (100*value) + "%"
		_:
			return ""
	
