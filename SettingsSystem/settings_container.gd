extends Resource
class_name SettingsContainer

# A resource that contains a bunch of settings, so a whole configuration
# can be easily saved to a file.

## Version of the build that last wrote this container out.
@export var game_version:String
## Every setting the game knows about. Only the defaults resource fills this in:
## it is the catalog that turns the ids in `values` back into SettingInfos.
## Containers written to disk carry their values alone.
@export var known_settings:Array[SettingInfo] = []
## The value of each setting, keyed by the setting's id.
@export var values:Dictionary[String, Variant] = {}


func get_setting_value(setting:SettingInfo)-> Variant:
	if setting.id in values:
		return values[setting.id]
	else:
		return null


func get_setting_by_id(setting_id:String)-> SettingInfo:
	for s in known_settings:
		if s.id == setting_id:
			return s
	return null


func get_setting_value_by_id(setting_id:String)-> Variant:
	if setting_id in values:
		return values[setting_id]

	var m = "No value defined for setting '%s'. Establish at least a default value" % [
	setting_id
	]
	push_warning(m)
	return null


func set_setting(setting:SettingInfo, new_value:Variant)-> void:
	assert(setting != null)
	values[setting.id] = new_value


func set_setting_by_id(setting_id:String, new_value:Variant)-> void:
	assert(not setting_id.is_empty())
	values[setting_id] = new_value


