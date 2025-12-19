@tool
extends Node
class_name TypewriterEffect


## Total time, in seconds, that it will take for all the characters to appear
@export var total_time:float = 0.5
## Minimum time between one character and the next
@export var min_character_time:float = 0.05
## Sound to be played, instead of the default one
@export var write_sound:AudioStreamPlayer = null
@export_group("Triggers")
@export var trigger_on_ready:bool = false
@export var trigger_on_shown:bool = false
## Plays the effect inside the editor
@export_tool_button("Play") var play_button = play


func _ready()-> void:
	var target = get_parent()
	
	if trigger_on_ready:
		target.ready.connect(_on_parent_ready)
	if trigger_on_shown:
		target.visibility_changed.connect(_on_parent_visibility_changed)
	
	
func _on_parent_ready()-> void:
	if trigger_on_ready:
		play()
		
		
func _on_parent_visibility_changed()-> void:
	if trigger_on_shown:
		play()
		
		
func _get_configuration_warnings() -> PackedStringArray:
	var warnings = []
	if get_parent() is not RichTextLabel:
		warnings.append("Parent should be a RichTextLabel")
	return warnings
	

func play(time_s:float = NAN)-> void:
	if not is_node_ready(): return
	
	var target = get_parent()
	assert(target is RichTextLabel)
	
	if is_nan(time_s):
		time_s = total_time
		
	var click_player
	if write_sound == null:
		click_player = %DefaultClickPlayer
		
	target.visible_characters = 0
	var num_chars = target.get_total_character_count()
	var char_time = total_time/float(num_chars)
	char_time = max(min_character_time, char_time)
	for c in range(num_chars):
		click_player.play()
		target.visible_characters += 1
		await get_tree().create_timer(char_time).timeout
		
	
