extends Node

@export var period:float = 1
@export var min_value:Variant
@export var max_value:Variant
@export var target:Node
@export var property:StringName


var phase:float = 0

func _physics_process(delta: float) -> void:
	phase += delta/period
	if phase >= 1.0:
		phase -= 1
		
	#var c = sin(phase)	
	
	target.set(property, lerp(min_value, max_value, sin(phase*2*PI)))
		
	
