@tool
extends Resource
class_name BaseBuildConfig

const EDITOR_CONFIG_PATH:String = "res://Data/Dev/editor_build_config.tres"

## Command line switch that picks the build configuration outright, overriding
## the editor/release choice below. Takes a res:// path or an absolute one,
## written either way round, after the `--` that separates user arguments:
##
##   godot -- --build-config=res://AssetCreation/TrailerMakers/clip.tres
##   godot -- --build-config /home/me/configs/clip.tres
##
## This is what lets one launch be configured from outside without editing a
## resource the editor also uses: a recording, a repro, a batch run.
const BUILD_CONFIG_ARG:String = "--build-config"

enum ForceActions
{
	None,
	ForceTrue,
	ForceFalse,
}

@export var disable_saving:bool = false
@export_group("Gameplay")
@export var blank_check:bool = false
@export var autoplayer:BaseAutoplayer = null
@export_group("Launch settings")
@export var use_testing_savefile:bool = false
@export var testing_savefile:BaseGameState
@export var skip_main_menu:bool = false
@export var skip_splash_screen:bool = false
@export var force_new_game:bool = false

@export_group("Integration")
@export var clear_achievements_at_start:bool = false

@export_group("Log")
@export var log_sinks:Array[BaseLogSinkConfig] = []

@export_group("Flag management")
@export var force_debug:ForceActions = ForceActions.None
@export var force_demo:ForceActions = ForceActions.None
@export var force_web:ForceActions = ForceActions.None
@export var force_steam:ForceActions = ForceActions.None
@export var force_itchio:ForceActions = ForceActions.None


# Forces a bool to a value depending on a force value, and returns either the 
# original or the forced value. To be use mainly in the global Flags, so they
# can be overridden.
# Ex: BuildConfig.Default.force_flag(OS.has_feature("demo"), ForceActions.ForceTrue)
func force_flag(original_value:bool, force_value:ForceActions)-> bool:
	match force_value:
		ForceActions.None:
			return original_value
		ForceActions.ForceTrue:
			return true
		ForceActions.ForceFalse:
			return false
			
	push_error("Unexpected enum value")
	return false


static var _cached_default_build:BaseBuildConfig = null
static func get_default_build()-> BaseBuildConfig:
	if _cached_default_build == null:
		_cached_default_build = _load_config_from_cmdline()

	if _cached_default_build == null:
		if OS.has_feature("editor"):
			var editor_build = get_editor_config()
			
			if editor_build.force_debug != ForceActions.ForceFalse:
				print("Using EDITOR build")
				_cached_default_build = editor_build
			else:
				print("Using RELEASE build")
				_cached_default_build = load(
				"res://Data/BuildConfigs/release_build_config.tres")
			
		else:
			print("Using RELEASE build")
			_cached_default_build = load(
				"res://Data/BuildConfigs/release_build_config.tres")
				
		if _cached_default_build == null:
			push_error("No build configuration found")
	return _cached_default_build


## The configuration named on the command line, or null when none was asked for.
##
## A path that cannot be loaded is reported rather than ignored, and null is
## returned so the usual editor/release choice still gives the run something to
## boot with: a launch that was meant to be configured and quietly was not is
## worse to debug than one that says so and carries on.
static func _load_config_from_cmdline()-> BaseBuildConfig:
	var path:String = CommandLineManager.get_value(BUILD_CONFIG_ARG)
	if path.is_empty(): return null

	if not ResourceLoader.exists(path) and not FileAccess.file_exists(path):
		push_error("No build configuration found at %s" % path)
		return null

	var resource:Resource = ResourceLoader.load(path)
	if resource is not BaseBuildConfig:
		push_error("%s does not hold a build configuration" % path)
		return null

	print("Using the build configuration at %s" % path)
	return resource as BaseBuildConfig
	
	
static func get_editor_config()-> BuildConfig:
	if FileAccess.file_exists(EDITOR_CONFIG_PATH):
		return load(EDITOR_CONFIG_PATH)
	else:
		return BuildConfig.new()
