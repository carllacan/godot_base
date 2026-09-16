@tool
extends Resource
class_name Flags

const EDITOR_FLAGS_PATH:String = "res://Data/Dev/editor_flags.tres"

static var Override:Flags = null

enum ForceActions
{
	None,
	ForceTrue,
	ForceFalse,
}

static var _cached_flags:Flags = null
static func get_flags()-> Flags:
	if Override != null:
		return Override
		
	if _cached_flags == null:
		if OS.has_feature("editor"):
			_cached_flags = load(EDITOR_FLAGS_PATH)
		else:
			_cached_flags = Flags.new()			
			

		# Return an empty one if none is made
		if _cached_flags == null:
			_cached_flags = Flags.new()
			
	return _cached_flags


static var DEMO:bool: 
	get:
		#if Engine.is_editor_hint(): return false
		return force_flag("demo", get_flags().force_demo)
static var PLAYTEST:bool: 
	get:
		#if Engine.is_editor_hint(): return false
		return force_flag("playtest", get_flags().force_playtest)
static var DEBUG:bool: 
	get:
		#if Engine.is_editor_hint(): return true
		return force_flag("debug", get_flags().force_debug)
static var WEB:bool: 
	get:
		#if Engine.is_editor_hint(): return false
		return force_flag("web", get_flags().force_web)
static var STEAM:bool: 
	get:
		#if Engine.is_editor_hint(): return false
		return force_flag("steam", get_flags().force_steam)
static var ITCHIO:bool:
	get:
		#if Engine.is_editor_hint(): return false
		return force_flag("itchio", get_flags().force_itchio)


# Returns the OS feature's own value, or the value the force action asks for.
# Ex: Flags.force_flag("demo", ForceActions.ForceTrue)
static func force_flag(flag_feature:String, force_value:ForceActions)-> bool:
	match force_value:
		ForceActions.None:
			return OS.has_feature(flag_feature)
		ForceActions.ForceTrue:
			return true
		ForceActions.ForceFalse:
			return false
			
	push_error("Unexpected enum value")
	return false


@export var force_debug:ForceActions = ForceActions.None
@export var force_demo:ForceActions = ForceActions.None
@export var force_playtest:ForceActions = ForceActions.None
@export var force_web:ForceActions = ForceActions.None
@export var force_steam:ForceActions = ForceActions.None
@export var force_itchio:ForceActions = ForceActions.None
