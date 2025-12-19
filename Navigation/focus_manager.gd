extends Node
class_name FocusManager


@export var first_focus:Control
@export var persist_focus:bool = true
@export var focus_on_joypad:bool = false
@export var unfocus_on_kbm:bool = false
@export_group("Focus change")
@export var sound_on_focus_change:AudioStreamPlayer

var focus_change_played_this_frame:bool = false
var last_focused_control:Control


func _ready()-> void:
	get_parent().ready.connect(_on_parent_ready)
	InputManager.type_changed.connect(_on_input_type_changed)
	
	
func _on_parent_ready()-> void:
	var p = get_parent()
	
	p.visibility_changed.connect(_on_parent_visibility_changed)
	p.get_viewport().gui_focus_changed.connect(_on_focus_changed)
	
	
func _on_focus_changed(_receiver:Control)-> void:
	if not get_parent().is_visible_in_tree(): return
	
	if not focus_change_played_this_frame:
		if sound_on_focus_change != null:
			if get_parent().is_ancestor_of(_receiver):
				sound_on_focus_change.play()
				focus_change_played_this_frame = true
				await get_tree().process_frame
				focus_change_played_this_frame = false
	
	
func focus()-> void:
	var to_focus:Control
	if persist_focus and last_focused_control != null:
		to_focus = last_focused_control
	else:
		if first_focus != null:
			to_focus = first_focus
			
	if to_focus != null:
		#print("Focusing control '%s'" % to_focus)
		to_focus.grab_focus()
	
	
func unfocus()-> void:
	if persist_focus:
		last_focused_control = get_viewport().gui_get_focus_owner()
		#print("Last focused control: '%s'" % last_focused_control)
	get_viewport().gui_release_focus()
	
	
	
func _on_input_type_changed(_new_type)-> void:
	match InputManager.current_controller_type:
		InputManager.ControllerTypes.KBM:
			if unfocus_on_kbm and get_parent().is_visible_in_tree():
				unfocus()
		InputManager.ControllerTypes.JOYPAD:
			if focus_on_joypad and get_parent().is_visible_in_tree():
				focus()
				
				
func _on_parent_visibility_changed()-> void:
	var p = get_parent()
	
	if p.is_visible_in_tree(): # if was SHOWN
		focus()
		focus_change_played_this_frame = true
		await get_tree().process_frame
		focus_change_played_this_frame = false
	else: # if it was HIDDEN
		unfocus()
