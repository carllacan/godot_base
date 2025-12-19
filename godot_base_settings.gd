extends Resource
class_name GodotBase

# Contains information about the GodotBase, mainly settings.
# A GodotBase resource should be created in the root of the projects. This
# allows the user to configure the behaviour of several GodotBase features
# without touching the actual code.

# Version of the GodotBase system
const VERSION:String = "1.0.0"

const CUSTOM_SETTINGS_PATH:String = "res://Parameters/godot_base_settings.tres"

static var settings:GodotBase : get = get_settings

@export_group("SettingInfo overrides")

@export var music_enabled_setting:SettingInfo = preload(
	"res://GodotBase/SettingsSystem/BaseSettings/music_enabled.tres")
@export var sfx_enabled_setting:SettingInfo = preload(
	"res://GodotBase/SettingsSystem/BaseSettings/sfx_enabled.tres")
@export var sound_enabled_setting:SettingInfo = preload(
	"res://GodotBase/SettingsSystem/BaseSettings/sound_enabled.tres")
@export var window_mode_setting:SettingInfo = preload(
	"res://GodotBase/SettingsSystem/BaseSettings/window_mode.tres")
@export var language_setting:SettingInfo = preload(
	"res://GodotBase/SettingsSystem/BaseSettings/language.tres")
	
@export_group("MovieMaker", "movie_maker")
# Final width of the result
@export var movie_maker_width:int = 616
# Final height of the result
@export var movie_maker_height:int = 320
# How much the captured rectangle will be zoomed. Values below 1.0 will zoom out
# the captured image, values above will zoom in.
@export var movie_maker_zoom:float = 1.0
# Write 1 out of X frames
@export var movie_maker_frame_skip_factor:int = 2
@export var movie_maker_make_gif:bool = true
@export var movie_maker_optimize_gif:bool = true
@export var movie_maker_gif_fuzz:int = 3
@export var movie_maker_make_webp:bool = false


static func get_settings()-> GodotBase:
	if FileAccess.file_exists(CUSTOM_SETTINGS_PATH):
		return load(CUSTOM_SETTINGS_PATH) as GodotBase
	else:
		push_warning("Custom GodotBase settings file not found, using default values")
		return GodotBase.new()
