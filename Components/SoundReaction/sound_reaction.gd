extends Node
class_name SoundReaction

## Plays a sound when the parent emits a signal. Default: 'pressed'
@export var target_signals:Array[String] = []
@export var target_sound:AudioStreamPlayer = null
@export var enabled:bool = true
@export_group("On actions")
@export var target_actions:Array[String]


func _ready()-> void:	
	if target_sound == null:
		var msg := "Undefined target_sound on SoundReaction(path: '%s')" % [get_path()]
		push_warning(msg)
	get_parent().ready.connect(_on_parent_ready)
	
		
func get_target_signals()-> Array[String]:
	if target_signals == null:
		return ["pressed"]
	return target_signals
	
	
func _on_parent_ready()-> void:
	var p = get_parent()
	for t_sig in get_target_signals():
		if not p.has_signal(t_sig):
			push_warning("'%s' has no signal named '%s'" % [
				p.name, t_sig
			])
			continue
		p.connect(t_sig, play_target_sound)
		
	#if p is Control and not target_actions.is_empty():
		#p.gui_input.connect(_on_parent_gui_input)
		
		
func _input(event:InputEvent)-> void:	
	if not get_parent().is_visible_in_tree(): return
	for ta in target_actions:
		if event.is_action_pressed(ta):
			play_target_sound()
			
		
func play_target_sound()-> void:
	if target_sound == null: return
	if not enabled: return
	
	target_sound.play()

	
