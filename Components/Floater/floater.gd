extends Node
class_name Floater
## Makes parent move up or down

enum TriggerType {
	MANUAL,
	ON_READY,
	ON_SHOWN,
}

@export var final_pos:Vector2
@export var final_alpha:float = 0
@export var float_time_s:float = 0.5
## How much randomness will be added to the float time
@export_range(0, 1.0) var float_time_fluctuation:float = 0
@export var trigger:TriggerType = TriggerType.ON_READY


func _ready()-> void:
	var p = get_parent()
	p.ready.connect(_on_parent_ready)
	
	if not p.has_signal("visibility_changed"):
		push_error("Parent has no visibility_changed signal")
		
	p.visibility_changed.connect(func(): if p.visible: _on_parent_shown())
	
	
func _on_parent_shown()-> void:
	if trigger == TriggerType.ON_SHOWN:
		float_away()
		
		
func _on_parent_ready()-> void:
	if trigger == TriggerType.ON_READY:
		float_away()
	
	
func float_away()-> void:
	var p = get_parent()
	var t = float_time_s
	t *= 1.0+randf_range(-float_time_fluctuation, float_time_fluctuation)
	var tw = p.create_tween()	
	tw.tween_property(p, "modulate:a", final_alpha, t)
	tw.set_parallel()
	tw.tween_property(p, "position", final_pos, t).as_relative()
		
	await tw.finished
	
	queue_free()
