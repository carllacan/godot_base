@tool
extends BaseComponent
class_name SettingSetterComponent

### This node will make its parent control become a setting controller

@export var target_setting:SettingInfo
## Whether to override the text of buttons or checkboxes it affects
@export var override_button_text:bool = true
## Whether to include the name of the setting when overriding text
@export var include_settings_name:bool = true
## Textures to be set to the parent "icon" property, indexed by value
@export var icon_overrides:Dictionary[Variant, Texture] = {}
## Strings to be shown in place of the setting's default representation
@export var value_representation_overrides:Dictionary[Variant, String] = {}
## Only values that have a value representation override will be shown
@export var show_only_overridden_values:bool = false
@export_group("Controls")
@export var left_click_increases:bool = true
@export var right_click_decreases:bool = true
@export var increase_actions:Array[String] = ["ui_accept", "ui_right"]
@export var decrease_actions:Array[String] = ["ui_left"]

var original_icon:Texture


func _ready()-> void:
	# Settings is an autoload, so it does not exist at edit time.
	if Engine.is_editor_hint(): return

	Settings.setting_changed.connect(_on_setting_changed)


func _is_parent_valid()-> bool:
	return get_target() is Button


func _notification(what):
	if what == NOTIFICATION_TRANSLATION_CHANGED:
		update_parent()
	
	
func _on_parent_ready()-> void:
	# Sets the target's toggle_mode, which the editor would serialize into the scene.
	if Engine.is_editor_hint(): return

	var t := get_target()
	t.gui_input.connect(_on_parent_received_input)

	if t is Button:
		original_icon = t.icon
		t.pressed.connect(_on_parent_button_pressed)
		t.toggle_mode = target_setting.is_bool()

	update_parent()
	
	
func must_show_value(value:Variant)-> bool:
	if not show_only_overridden_values: return true
	return value in icon_overrides or value in value_representation_overrides
	

func _on_parent_received_input(event:InputEvent)-> void:	
	if event is InputEventMouseButton:
		if not event.is_released():
			return
		if event.button_index == MouseButton.MOUSE_BUTTON_RIGHT:
			if right_click_decreases:
				cycle_setting(-1)
		if event.button_index == MouseButton.MOUSE_BUTTON_LEFT:
			if left_click_increases:
				cycle_setting(+1)
		
	# If the parent is focused right now we can listen to input actions
	# (not sure if we need to check for focus, but we do it just in case)
	var focused = get_target().get_viewport().gui_get_focus_owner()		
	if get_target() == focused:
		for a in decrease_actions:
			if event.is_action_pressed(a):
				cycle_setting(-1)
		for a in increase_actions:
			if event.is_action_pressed(a):
				cycle_setting(+1)
				
				
## The setting values that have an override, in the order they will be cycled
func get_shown_values()-> Array[Variant]:
	var values:Array[Variant] = []
	for value in icon_overrides.keys() + value_representation_overrides.keys():
		if value not in values:
			values.append(value)
	return values


func cycle_setting(steps:int = 1)-> void:
	if not show_only_overridden_values:
		Settings.cycle_setting(target_setting.name, steps)
		return

	var vals:Array[Variant] = get_shown_values()
	if vals.is_empty():
		push_error("Setting '%s' only shows overridden values, but has no overrides"
			% target_setting.name)
		return

	var current:Variant = Settings.get_setting_value_by_name(target_setting.name)
	var current_idx:int = vals.find(current)
	var next_idx:int
	if current_idx == -1:
		# The current value is not one of the shown ones, so we enter the
		# list of shown values from whichever end we are moving towards
		next_idx = 0 if steps >= 0 else len(vals) - 1
	else:
		next_idx = wrapi(current_idx + steps, 0, len(vals))

	p("%s cycles '%s' from %s to %s",
		[get_target().name, target_setting.name, str(current), str(vals[next_idx])])

	Settings.set_setting_value_by_name(target_setting.name, vals[next_idx])
		
		
func _on_parent_button_pressed()-> void:
	return
	
	
func _on_setting_changed(setting_name:String, _new_value:Variant)-> void:
	if setting_name == target_setting.name:
		await get_tree().process_frame # TODO: do this some other way.
		update_parent()
		
		
func update_parent()-> void:
	if not is_node_ready(): return
	# Overwrites the parent's text and icon, which the editor would serialize into
	# the scene, silently replacing whatever the button was authored with.
	# Reached from _notification too, which does fire at edit time.
	if Engine.is_editor_hint(): return

	var parent = get_target()
	
	var n = target_setting.dname.to_upper()
	var val = Settings.get_setting_value_by_name(target_setting.name)
	
	if not must_show_value(val):
		p("%s shows '%s' as %s, which has no override",
			[get_target().name, target_setting.name, str(val)])

	# Generate a representative string
	var val_str:String
	if val in value_representation_overrides:
		val_str = value_representation_overrides[val]
	else:
		val_str = target_setting.get_value_representation(val)

	if parent is Button:

		if override_button_text:
			if include_settings_name:
				parent.text = "%s: %s" % [n, val_str]
			else:
				parent.text = "%s" % [val_str]
			
		if target_setting.is_bool() and (parent as Button).toggle_mode:
			
			parent.set_pressed_no_signal(not val)
			
		# Change the button icon
		if not icon_overrides.is_empty():
			if val in icon_overrides.keys():
				parent.icon = icon_overrides[val]
			else:
				parent.icon = original_icon
		
			
			
