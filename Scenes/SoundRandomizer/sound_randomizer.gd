@tool
extends AudioStreamPlayer
class_name SoundRandomizer


#var original_pitch:float = NAN

## Minimum and maximum pitches for this sound
@export var pitch_range:Vector2 = Vector2.ONE
@export_tool_button("Play randomized") var pb = play_randomized


#func _ready()-> void:
	#original_pitch = pitch_scale
	

func play_randomized(from_position:float = 0)-> void:
	#var pitch_factor = randf_range(pitch_range.x, pitch_range.y)	
	#pitch_scale = original_pitch*pitch_factor
	
	pitch_scale = randf_range(pitch_range.x, pitch_range.y)	
	play(from_position)
	await finished
