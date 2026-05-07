@tool
extends Node
class_name Flags


static var DEMO:bool: 
	get:
		if Engine.is_editor_hint(): return false
		return BuildConfig.Default.force_flag(
			OS.has_feature("demo"), BuildConfig.Default.force_demo)
static var DEBUG:bool: 
	get:
		if Engine.is_editor_hint(): return true
		return BuildConfig.Default.force_flag(
			OS.has_feature("debug"), BuildConfig.Default.force_debug)
static var WEB:bool: 
	get:
		if Engine.is_editor_hint(): return false
		return BuildConfig.Default.force_flag(
			OS.has_feature("web"), BuildConfig.Default.force_web)
static var STEAM:bool: 
	get:
		if Engine.is_editor_hint(): return false
		return BuildConfig.Default.force_flag(
			OS.has_feature("steam"), BuildConfig.Default.force_steam)
static var ITCHIO:bool:
	get:
		if Engine.is_editor_hint(): return false
		return BuildConfig.Default.force_flag(
			OS.has_feature("itchio"), BuildConfig.Default.force_itchio)
