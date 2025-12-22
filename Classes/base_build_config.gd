extends Resource
class_name BaseBuildConfig

enum ForceActions
{
	None,
	ForceTrue,
	ForceFalse,
}

@export_category("Launch settings")
@export var use_testing_savefile:bool = false
@export var testing_savefile:BaseGameState
@export var skip_main_menu:bool = false
@export var force_new_game:bool = false

@export_category("Integration testing")
@export var clear_achievements_at_start:bool = false

@export_category("Flag management")
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



static func get_default_build()-> BaseBuildConfig:
	var b:BaseBuildConfig
	if OS.has_feature("editor"):
		b = load("res://Parameters/editor_build_config.tres")
	else:
		b = load("res://Parameters/release_build_config.tres")
	if b == null:
		push_error("No build configuration found")
	return b
