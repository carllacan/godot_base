extends RefCounted
class_name ModifierManager

var modifiers:Array[Modifier] = []
var additive:Dictionary[String, float] = {}
var multiplicative:Dictionary[String, float] = {}

var verbose:bool = false

func p(msg:String)-> void:
	if not verbose: return
	print(msg)
	

func add_modifier(mod:Modifier)-> void:
	modifiers.append(mod)
	match mod.mode:
		Modifier.Mode.ADDITIVE:
			if mod.key not in additive:
				additive[mod.key] = 0
			additive[mod.key] += mod.value
		Modifier.Mode.MULTIPLICATIVE:
			if mod.key not in multiplicative:
				multiplicative[mod.key] = 0
			multiplicative[mod.key] += mod.value
			
	p("modifier for %s added" % mod.key)


func remove_modifier(mod:Modifier)-> void:
	var idx = modifiers.find(mod)
	if idx == -1:
		return
	modifiers.remove_at(idx)
	match mod.mode:
		Modifier.Mode.ADDITIVE:
			additive[mod.key] -= mod.value
		Modifier.Mode.MULTIPLICATIVE:
			multiplicative[mod.key] -= mod.value


func apply_modifiers(base_value:float, key:String, times:int = 1)-> float:
	var result = base_value
	if key in additive:
		result += additive[key]*times
	if key in multiplicative:
		result *= pow(1.0 + multiplicative[key], times)
	return result
