extends Resource
class_name BaseBuildConfig

enum ForceActions
{
	None,
	ForceTrue,
	ForceFalse,
}


@export var force_debug:ForceActions = ForceActions.None
@export var force_demo:ForceActions = ForceActions.None
@export var force_web:ForceActions = ForceActions.None
@export var force_steam:ForceActions = ForceActions.None
@export var force_itchio:ForceActions = ForceActions.None


# Forces a bool to a value depending on a force value, and returns it
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
