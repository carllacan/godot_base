extends Resource
class_name SettingsContainer

# A resource that contains a bunch of settings, so a whole configuration
# can be easily saved to a file.

@export var game_version:String
@export var values:Dictionary[SettingInfo, Variant] = {}


func get_setting_value(setting:SettingInfo)-> Variant:	
	if setting in values:
		return values[setting]
	else:
		return null
	
	
func get_setting_by_name(setting_name:String)-> SettingInfo:
	for s in values.keys():
		if s.name == setting_name:
			return s
	return null
	
	
func get_setting_value_by_name(setting_name:String)-> Variant:
	#if not values.keys().any(func(s): return s.name == setting_name):
	if not values.keys().any(func(s): return s.name == setting_name):
		push_warning("No value defined for setting '%s'. Establish at least a default value")
		return null
		
	var target_setting:SettingInfo = get_setting_by_name(setting_name)
	
	if target_setting in values:
		return values[target_setting]
	else:
		push_warning("No value defined for setting '%s'. Establish at least a default value")
		return null


func set_setting(setting:SettingInfo, new_value:Variant)-> void:		
	assert(setting != null)
	values[setting] = new_value
	
	
func set_setting_by_name(setting_name:String, new_value:Variant)-> void:	
	var target_setting:SettingInfo = get_setting_by_name(setting_name)
	
	assert(target_setting != null)
	values[target_setting] = new_value
	
	
