extends Node
class_name Floater
## Makes parent move up or down

enum TriggerType {
	MANUAL,
	ON_READY,
	ON_SHOWN,
}

var _final_pos:Vector2 = Vector2(0, -50)

## Sets the position the target will float to via coordinates. 
## Seting it changes final_distance and direction.
@export var final_pos:Vector2 = Vector2(0, -50) : set = set_final_pos
## Sets how far away the target node will float. 
## Seting it changes final_pos.
@export var final_distance:float = 50 : set = set_final_distance
## Sets how the direction in which the target node will float. 
## Seting it changes final_pos.
@export var direction:float = -90 : set = set_direction
@export var final_alpha:float = 0
@export var float_time_s:float = 0.5
## How much randomness will be added to the float time
@export_range(0, 1.0) var float_time_fluctuation:float = 0
@export var trigger:TriggerType = TriggerType.ON_READY

## Calculate position the target will float to.
func _apply_final_pos(value:Vector2)-> void:
	_final_pos = value
	if final_pos != value:
		final_pos = value
	var dist = value.length()
	if final_distance != dist:
		final_distance = dist
	# TODO: the direction is re-derived from the position, and Vector2.angle()
	# returns the half turn as -PI, so setting direction to 180 reads back as
	# -180. The float goes the right way, but the value the caller set is lost.
	var angle = rad_to_deg(value.angle())
	if direction != angle:
		direction = angle


func set_final_pos(value:Vector2)-> void:
	if final_pos == value: return
	final_pos = value
	_apply_final_pos(value)


func set_final_distance(value:float)-> void:
	if final_distance == value: return
	final_distance = value
	_apply_final_pos(Vector2.from_angle(deg_to_rad(direction)) * value)


func set_direction(value:float)-> void:
	if direction == value: return
	direction = value
	_apply_final_pos(Vector2.from_angle(deg_to_rad(direction)) * final_distance)


func _ready()-> void:
	var p = get_parent()
	p.ready.connect(_on_parent_ready)
	
	# TODO: this check buys nothing: the connect below runs anyway and crashes on
	# a parent without the signal. Either return after the error or drop the check.
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
	tw.tween_property(p, "position", _final_pos, t).as_relative()
		
	await tw.finished

	# TODO: this frees the floater, not the node it floated away. The faded out
	# parent stays in the tree, and neither FloatingLabel nor CoinsToast frees
	# itself, so they pile up invisible nodes.
	queue_free()
