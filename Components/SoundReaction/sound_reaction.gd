@tool
extends BaseComponent
class_name SoundReaction

## Plays a sound when the target emits a signal. Default: 'pressed'
@export var target_signals:Array[String] = []
@export var target_sound:AudioStreamPlayer = null
@export_group("On actions")
@export var target_actions:Array[String]


func _ready()-> void:
	if target_sound == null:
		var msg := "Undefined target_sound on SoundReaction(path: '%s')" % [get_path()]
		push_warning(msg)


# TODO: the "pressed" default never happens. A typed Array export is never null,
# so an unconfigured component returns [] here and listens to nothing. Use
# target_signals.is_empty() instead to get the default the class comment promises.
func get_target_signals()-> Array[String]:
	if target_signals == null:
		return ["pressed"]
	return target_signals
	
	
func _on_parent_ready()-> void:
	# _input fires on editor input too, so a wired-up component would play sounds
	# while a scene is merely being edited.
	if Engine.is_editor_hint(): return

	var t := get_target()
	for t_sig in get_target_signals():
		if not t.has_signal(t_sig):
			push_warning("'%s' has no signal named '%s'" % [
				t.name, t_sig
			])
			continue
		t.connect(t_sig, play_target_sound)

	#if t is Control and not target_actions.is_empty():
		#t.gui_input.connect(_on_parent_gui_input)
		
		
func _input(event:InputEvent)-> void:
	if Engine.is_editor_hint(): return
	if not get_target().is_visible_in_tree(): return
	for ta in target_actions:
		if event.is_action_pressed(ta):
			play_target_sound()
			
		
func play_target_sound()-> void:
	if target_sound == null: return
	if not enabled: return
	
	target_sound.play()

	
