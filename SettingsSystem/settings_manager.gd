extends Node
class_name SettingsManager

# A class that manages settings, ensures persistence, and notifies of changes.
# Contains by defaults many settings common to most games, and offers ways
# to remove those or add new ones. Also implements common reactions to changes
# of some settings, like changing volumes or resolution.

signal setting_changed(name:String, new_value:Variant) # TODO: use SettingInfo type


const DEFAULT_SETTINGS:SettingsContainer = preload("res://Settings/default_settings.tres")
const SETTINGS_SAVE_PATH:String = "user://settings.tres"


var settings:SettingsContainer


func _ready()-> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	
	# Start with default settings and load any changes over it
	settings = DEFAULT_SETTINGS.duplicate()
	setting_changed.connect(_on_setting_changed)
	
	print("Initializing settings...")
	if FileAccess.file_exists(SETTINGS_SAVE_PATH):
		var last_settings = load(SETTINGS_SAVE_PATH)
		if last_settings != null:
			apply_configuration(last_settings)
		else:
			print("Couldn't load last settings file, using default")
		
		
# Applies all settings one by one, so all reactions are triggered
func apply_configuration(new_configuration:SettingsContainer)-> void:
	for setting in new_configuration.values.keys():
		var v = new_configuration.values[setting]
		set_setting_value_by_name(setting.name, v)
		
		
func get_setting_value(setting:SettingInfo)-> Variant:
	var setting_value = settings.get_setting_value(setting)
	
	assert(setting_value != null)
	
	return setting_value
	
		
func get_setting_value_by_name(setting_name:String)-> Variant:
	var setting_value = settings.get_setting_value_by_name(setting_name)
	
	assert(setting_value != null, 
	"No default or user value for setting '%s'" % setting_name)
	
	return setting_value
		
		
func set_setting_value_by_name(setting_name:String, new_value:Variant)-> void:
	settings.set_setting_by_name(setting_name, new_value)
	setting_changed.emit(setting_name, new_value)
	save_settings()
	
	
func set_setting(setting:SettingInfo, new_value:Variant)-> void:
	settings.set_setting(setting, new_value)
	setting_changed.emit(setting.name, new_value)
	save_settings()
	

func cycle_setting(setting_name:String, steps:int = 1)-> void:
	var s = settings.get_setting_by_name(setting_name)
	match s.type:
		Variant.Type.TYPE_BOOL:
			#if steps % 2 != 0:
				var current:bool = get_setting_value_by_name(s.name)
				set_setting_value_by_name(setting_name, not current)
		Variant.Type.TYPE_INT:
			var current:int = get_setting_value_by_name(s.name)
			var new:int = current + steps
			var corrected:int = wrapi(new, s.min_value, s.max_value+1)
			set_setting_value_by_name(setting_name, corrected)
		Variant.Type.TYPE_ARRAY:
			var current_key:String = get_setting_value_by_name(s.name)
			var current_idx:int = s.options.keys().find(current_key)
			var next_idx:int = wrapi(current_idx+steps, 0, len(s.options))
			var next_key:String = s.options.keys()[next_idx]
			set_setting_value_by_name(setting_name, next_key)
	
	
func save_settings()-> void:
	ResourceSaver.save(settings, SETTINGS_SAVE_PATH)
	
	
# TODO use settinginfo type here?
func _on_setting_changed(setting_name:String, new_value:Variant)-> void:	
	match setting_name:
		GodotBase.settings.music_enabled_setting.name: # TODO: move to an AudioManager?
			var i = AudioServer.get_bus_index("Music")
			AudioServer.set_bus_mute(i, not new_value)
		GodotBase.settings.sfx_enabled_setting.name: # TODO: move to an AudioManager?		
			var i = AudioServer.get_bus_index("Sfx")
			AudioServer.set_bus_mute(i, not new_value)
		GodotBase.settings.sound_enabled_setting.name: # TODO: move to an AudioManager?		
			var i = AudioServer.get_bus_index("Master")
			AudioServer.set_bus_mute(i, not new_value)
		GodotBase.settings.window_mode_setting.name:
			match new_value:
				"fullscreen":
					DisplayServer.window_set_mode(
						DisplayServer.WINDOW_MODE_FULLSCREEN)
				"windowed":
					DisplayServer.window_set_mode(
						DisplayServer.WINDOW_MODE_MAXIMIZED)
		GodotBase.settings.language_setting.name:
			match new_value:
				"default":
					var preferred_language = Integration.get_current_language()
					if preferred_language == "":
						preferred_language = OS.get_locale_language()
					TranslationServer.set_locale(preferred_language)
				_:
					TranslationServer.set_locale(new_value)
