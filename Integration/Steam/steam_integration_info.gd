extends Resource
class_name SteamIntegrationInfo

const DEFAULT_PATH = "res://Integration/Steam/steam_integration_info.tres"

@export_group("Full game", "full_game_")
@export var full_game_id:int = -1
@export var full_game_achievement_names:Array[String]
@export var full_game_stat_names:Array[String]
@export_group("Demo", "demo_")
@export var demo_id:int = -1
@export var demo_achievement_names:Array[String]
@export var demo_stat_names:Array[String]
@export_group("Playtest", "playtest_")
@export var playtest_id:int = -1
@export var playtest_achievement_names:Array[String]
@export var playtest_stat_names:Array[String]


## The achievements configured for the build that is running. Demo, playtest and
## full game are separate Steam apps, each with its own set.
func get_achievement_names()-> Array[String]:
	if Flags.DEMO:
		return demo_achievement_names
	elif Flags.PLAYTEST:
		return playtest_achievement_names
	else:
		return full_game_achievement_names


func has_achievement_name(ach_name:String)-> bool:
	return ach_name in get_achievement_names()


## The stats configured for the build that is running. See get_achievement_names.
func get_stat_names()-> Array[String]:
	if Flags.DEMO:
		return demo_stat_names
	elif Flags.PLAYTEST:
		return playtest_stat_names
	else:
		return full_game_stat_names


func has_stat_name(stat_name:String)-> bool:
	return stat_name in get_stat_names()
