extends AudioStreamPlayer
class_name SoundRandomizer


var original_pitch:float = NAN

@export var pitch_range:Vector2 = Vector2.ONE


func _ready()-> void:
	original_pitch = pitch_scale
	

func play_randomized(from_position:float = 0)-> void:
	var pitch_factor = randf_range(pitch_range.x, pitch_range.y)
	
	pitch_scale = original_pitch*pitch_factor
	play(from_position)
	await finished
