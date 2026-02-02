extends Resource
class_name BaseGameState


const DEFAULT_FILENAME = "save.tres"
const INITIAL_RUN_FILEPATH = "res://Data/GameRuns/initial_game_run.tres"
const DEMO_INITIAL_RUN_FILEPATH = "res://Data/GameRuns/demo_initial_game_run.tres"

@export_group("Others")
@export var timestamp_unix:float = 0
@export var version:String

#region Saving

# Saves this run to a resource file. Uses a default filename if none specified
func save(filepath:String = "")-> void:
	SaveManager.queue_save(actually_save.bind(filepath))
	
	
func actually_save(filepath:String = "")-> Error:
	var result:Error
	if filepath == "":
		filepath = get_run_filepath(DEFAULT_FILENAME)
		
	if BuildConfig.Default.disable_saving:
		print("Saving aborted because 'disable_saves' is enabled")
		return ERR_UNAUTHORIZED
		
		
	result = DirAccess.open("user://").make_dir_recursive(filepath.get_base_dir())
	if result != OK:
		print("Creating save directory failed. Error code: %s" % result)
		
	timestamp_unix = Time.get_unix_time_from_system()
	version = Dist.get_version()
		
	result = ResourceSaver.save(self, filepath)
	
	if result == OK:
		print("Game saved to '%s'" % filepath)
	else:
		print("Game saving failed. Error code: %s" % result)
		
	# Upload save, if configured to do so.
	Integration.sync_file(filepath)
		
	return result


# Joins the save files directory with a filename
static func get_run_filepath(filename:String)-> String:
	if Flags.DEMO:
		return "user://".path_join("demo").path_join(filename)
	else:
		return "user://".path_join(filename)
	
	
# Loads a GameRun saved as a resource
static func load(filepath:String)-> BaseGameState:
	# Sync save, if configured to do so. This might download a new save.
	Integration.sync_file(filepath)
	
	var r:BaseGameState = ResourceLoader.load(filepath)
	
	if r != null:
		print("Game loaded from '%s'" % filepath)
	else:
		print("Game loaded failed.")
		
	return r
	
	
#endregion Saving
