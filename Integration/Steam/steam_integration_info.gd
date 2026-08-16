extends Resource
class_name SteamIntegrationInfo

const DEFAULT_PATH = "res://Integration/Steam/steam_integration_info.tres"

@export var full_game_id:int = -1
@export var demo_id:int = -1
@export var playtest_id:int = -1
@export var achievement_names:Array[String]
@export var stat_names:Array[String]
