extends Node

# Manages different sources of pause requests (game, hud, external...)
# and pauses/unpauses as appropriate.
# TODO: not sure if this is necessary.

signal paused
signal unpaused
@warning_ignore("unused_signal")
signal paused_externally

var pause_sources:Array[Object] = []
var can_pause:bool = true : set = set_can_pause # TODO: wtf is this for


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	

func set_can_pause(value:bool)-> void:
	can_pause = value
	update_pause_state()
	
	
func add_pause_source(new_source)-> void:
	#assert(new_source not in pause_sources)
	if new_source not in pause_sources: 
		pause_sources.append(new_source)
		print("%s added as pause source (%s)" % [new_source.name, new_source])
	update_pause_state()
	
	
func remove_pause_source(source)-> void:
	#assert(source in pause_sources)
	if source in pause_sources:
		pause_sources.erase(source)
		print("%s removed as pause source" % source)
	update_pause_state()
	
		
func toggle_pause(source:Object)-> void:
	if source not in pause_sources:
		add_pause_source(source)
		return
		
	elif source in pause_sources:
		remove_pause_source(source)
		return
	
	
func force_unpaused()-> void:
	for ps in pause_sources.duplicate():
		remove_pause_source(ps)
	
	
func must_pause()-> bool:
	return not pause_sources.is_empty()
	
	
func is_paused()-> bool:
	return get_tree().paused
	
	
func update_pause_state()-> void:
	if must_pause() and not is_paused():
		get_tree().paused = true
		print("PAUSED")
		paused.emit()
		return
		
	if not must_pause() and is_paused():
		get_tree().paused = false
		print("UNPAUSED")
		unpaused.emit()
		return


#func _input(event: InputEvent) -> void:
	#if event.is_action_pressed("ui_cancel"):
		#get_viewport().set_input_as_handled()
		#toggle_pause(self)
