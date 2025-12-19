extends Node2D
class_name GhostGenerator


@export var target:CanvasItem
@export var period_s:float = 1
@export var length_s:float = 0.5
@export var scale_factor = 1.25
@export var one_shot:bool = false
@export var autostart:bool = false
@export var initial_modulate:Color = Color.WHITE
@export var modulate_factor:Color = Color(1.0, 1.0, 1.0, 0.0)


var active:bool = false : set = set_active

var time_until_next_s:float = NAN


func _ready()-> void:
	if autostart:
		start()
	
	
func set_active(value:bool)-> void:
	var was_active = active
	active = value
	
	if active and not was_active:
		start()
	if not active and was_active:
		stop()
	
	
func generate_ghost()-> void:		
	var ghost = target.duplicate()
	ghost.modulate = initial_modulate
	
	add_child(ghost)
	
	var original_scale:Vector2 = target.scale
	var original_modulate:Color = target.modulate
	var tween:Tween = target.create_tween()
	
	var final_scale = original_scale*scale_factor
	var final_modulate = original_modulate*modulate_factor
	
	tween.set_parallel()
	tween.tween_property(
		ghost, "scale", final_scale, length_s
		).from(original_scale)
	tween.tween_property(
		ghost, "modulate", final_modulate, length_s
		).from(original_modulate)
	
	await tween.finished
	remove_child(ghost)
	
	
# Generates a ghost and, if one_short is false, starts the cycle
func start()-> void:
	if active:
		return
		
	active = true
		
	# Generate one ghost and wait for it to vanish
	await generate_ghost()
	if one_shot:
		active = false
	else:
		time_until_next_s = period_s
	
	
# Stops the cycle
func stop()-> void:
	time_until_next_s = NAN		
	if active:
		active = false
		

func _physics_process(delta: float) -> void:
	
	if not active: return
	
	time_until_next_s -= delta
	if time_until_next_s <= 0:
		generate_ghost()
		time_until_next_s = period_s
