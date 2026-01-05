extends Resource
class_name Modifier

enum Mode {
	_undef,
	ADDITIVE,
	MULTIPLICATIVE,
}

@export var key:String
@export var value:float = 0
@export var mode:Mode = Mode.ADDITIVE


@warning_ignore("shadowed_variable")
static func apply_all(base_value, key:String, sources:Array)-> float:
	var result = base_value
	for s in sources:
		assert(s is Array[Modifier])
		for mod:Modifier in s:
			if mod.key == key:
				result = mod.apply(result)
				
	return result


func apply(base_value)-> float:
	match mode:
		Mode.ADDITIVE:
			return base_value + value
		Mode.MULTIPLICATIVE:
			return base_value * (1.0+value)
		_:
			push_error("Unknown mode %s" % mode)
			return NAN
