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

## Scene that will be used to create windows in BaseWindow factory methods.
@export var base_window_scene:PackedScene = preload(
	"res://GUI/Windows/BaseWindow/base_window.tscn")
	
## These can be used if the developer doesn't want to use the default settings
## that come with GodotBase
@export_group("SettingInfo overrides")

## Points to the settings that controls music
@export var music_enabled_setting:SettingInfo = preload(
	"res://GodotBase/SettingsSystem/BaseSettings/music_enabled.tres")
@export var music_volume_setting:SettingInfo = preload(
	"res://GodotBase/SettingsSystem/BaseSettings/music_volume.tres")

@export var sfx_enabled_setting:SettingInfo = preload(
	"res://GodotBase/SettingsSystem/BaseSettings/sfx_enabled.tres")
@export var sfx_volume_setting:SettingInfo = preload(
	"res://GodotBase/SettingsSystem/BaseSettings/sfx_volume.tres")

@export var master_enabled_setting:SettingInfo = preload(
	"res://GodotBase/SettingsSystem/BaseSettings/sound_enabled.tres")
@export var master_volume_setting:SettingInfo = preload(
	"res://GodotBase/SettingsSystem/BaseSettings/sound_volume.tres")
## Points to the settings that controls music.
@export var window_mode_setting:SettingInfo = preload(
	"res://GodotBase/SettingsSystem/BaseSettings/window_mode.tres")
## Points to the settings that controls music.
@export var language_setting:SettingInfo = preload(
	"res://GodotBase/SettingsSystem/BaseSettings/language.tres")
	
@export_group("Debug", "debug")
## Whether debug elements start visible instead of waiting for the
## debug_toggle_info action. In practice this is what makes the DebugInfo
## readout show from the moment the game launches; it applies to everything in
## the BaseGroups.DEBUG_ELEMENTS group, and the action still toggles it off and
## on afterwards. Only has any effect when Flags.DEBUG is set.
@export var debug_show_elements_on_launch:bool = false

@export_group("Performance", "perf")
## Whether the PerfStats autoload should add a DebugInfo readout to the tree
## when the project has not instantiated one itself. Turn this off if the
## project places its own DebugInfo somewhere specific.
@export var perf_auto_add_debug_info:bool = true

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

static var _settings:GodotBase # cached version
static func get_settings()-> GodotBase:
	if _settings== null:
		# ResourceLoader.exists, not FileAccess.file_exists: exported builds convert
		# .tres to binary and leave only a .remap, which file_exists doesn't follow.
		if ResourceLoader.exists(CUSTOM_SETTINGS_PATH):
			print(Time.get_ticks_msec()) 
			_settings = load(CUSTOM_SETTINGS_PATH) as GodotBase
		else:
			push_warning("Custom GodotBase settings file not found, using default values")
			_settings = GodotBase.new()
	return _settings
