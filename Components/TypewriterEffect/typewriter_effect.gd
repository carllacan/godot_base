@tool
extends BaseComponent
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
@export var reset_on_ready:bool = false
@export var reset_on_shown:bool = false
## Plays the effect inside the editor
@export_tool_button("Play") var play_button = play


func _ready()-> void:
	if reset_on_ready:
		reset()


func _on_parent_ready()-> void:
	# TODO: reset_on_shown is only ever acted on from
	# _on_parent_visibility_changed, which is connected here only when
	# trigger_on_shown is set. On its own the flag never fires at all, and
	# alongside trigger_on_shown it is redundant because play() resets anyway, so
	# it does nothing either way. Connect when either flag is set.
	if trigger_on_shown:
		get_target().visibility_changed.connect(_on_parent_visibility_changed)

	if reset_on_ready:
		reset()
	if trigger_on_ready:
		play()
		
		
func _on_parent_visibility_changed()-> void:
	# TODO: this fires on the parent being hidden as well as shown, so hiding the
	# label writes it out too. Check target.visible first if that is not wanted.
	if reset_on_shown:
		reset()
	if trigger_on_shown:
		play()
		
		
func _is_parent_valid()-> bool:
	return get_target() is RichTextLabel


func _get_parent_requirement()-> String:
	return "a RichTextLabel"


func reset()-> void:
	if not is_node_ready(): return

	var t := get_target()
	assert(t is RichTextLabel)

	t.visible_characters = 0


func play(time_s:float = NAN)-> void:
	if not is_node_ready(): return

	var t := get_target()
	assert(t is RichTextLabel)

	if is_nan(time_s):
		time_s = total_time
		
	var click_player
	if write_sound == null:
		click_player = %DefaultClickPlayer
	else:
		click_player = write_sound
		
	reset()
	var num_chars = t.get_total_character_count()
	# TODO: time_s is worked out above and then never used, so the pace comes from
	# total_time whatever play() was given. Should be time_s/float(num_chars).
	var char_time = total_time/float(num_chars)
	char_time = max(min_character_time, char_time)
	for c in range(num_chars):
		if click_player != null:
			click_player.play()
		t.visible_characters += 1
		# TODO: this waits after the last character too, so the effect lasts
		# num_chars*char_time rather than the total_time that was asked for.
		await get_tree().create_timer(char_time).timeout
		
	
