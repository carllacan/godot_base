extends Node
class_name SettingSetter

### This node will make its parent control become a setting controller

@export var target_setting:SettingInfo
@export var override_text:bool = true
@export var icon_overrides:Dictionary[Variant, Texture] = {}
@export_group("Controls")
@export var left_click_increases:bool = true
@export var right_click_decreases:bool = true
@export var increase_actions:Array[String] = ["ui_accept", "ui_right"]
@export var decrease_actions:Array[String] = ["ui_left"]

@export_group("Debug")
@export var verbose:bool = false

var original_icon:Texture


func _ready()-> void:
	Settings.setting_changed.connect(_on_setting_changed)
	
	var parent = get_parent()
	parent.ready.connect(_on_parent_ready)
	parent.gui_input.connect(_on_parent_received_input)
	
	if parent is Button:
		original_icon = parent.icon
		parent.pressed.connect(_on_parent_button_pressed)	
		if target_setting.is_bool():
			parent.toggle_mode = true
		else:
			parent.toggle_mode = false
	else:
		push_error("Unexpected parent type")
		
		
func _notification(what):
	if what == NOTIFICATION_TRANSLATION_CHANGED:
		update_parent()
	
	
func _on_parent_ready()-> void:
	update_parent()
	

func _on_parent_received_input(event:InputEvent)-> void:	
	if event is InputEventMouseButton:
		if not event.is_released():
			return
		if event.button_index == MouseButton.MOUSE_BUTTON_RIGHT:
			if right_click_decreases:
				Settings.cycle_setting(target_setting.name, -1)
		if event.button_index == MouseButton.MOUSE_BUTTON_LEFT:
			if left_click_increases:
				Settings.cycle_setting(target_setting.name, +1)
		
	# If the parent is focused right now we can listen to input actions
	# (not sure if we need to check for focus, but we do it just in case)
	var focused = get_parent().get_viewport().gui_get_focus_owner()		
	if get_parent() == focused:
		for a in decrease_actions:
			if event.is_action_pressed(a):
				Settings.cycle_setting(target_setting.name, -1)
		for a in increase_actions:
			if event.is_action_pressed(a):
				Settings.cycle_setting(target_setting.name, +1)
				
		
func _on_parent_button_pressed()-> void:
	return
	#Settings.cycle_setting(target_setting.name)
	
	
func _on_setting_changed(setting_name:String, _new_value:Variant)-> void:
	if setting_name == target_setting.name:
		await get_tree().process_frame # TODO: do this some way else
		update_parent()
		
		
func update_parent()-> void:
	if not is_node_ready(): return 
	
	var parent = get_parent()
	
	var n = target_setting.dname.to_upper()
	var val = Settings.get_setting_value_by_name(target_setting.name)
	
	# Generate a representative string
	var val_str:String = target_setting.get_value_representation(val)	
				
	if parent is Button:
		
		if override_text:
			parent.text = "%s: %s" % [n, val_str]	
			
		if target_setting.is_bool() and (parent as Button).toggle_mode:
			
			parent.set_pressed_no_signal(not val)
			
		# Change the button icon
		if not icon_overrides.is_empty():
			if val in icon_overrides.keys():
				parent.icon = icon_overrides[val]
			else:
				parent.icon = original_icon
	else:
		push_error("Unexpected parent type")
		
			
			
