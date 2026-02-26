extends Resource
class_name BaseGameState

const DEFAULT_FILENAME = "save.tres"
const INITIAL_RUN_FILEPATH = "res://Data/GameRuns/initial_game_run.tres"
const DEMO_INITIAL_RUN_FILEPATH = "res://Data/GameRuns/demo_initial_game_run.tres"


signal resources_changed
signal resource_changed(resource:GameResource, new_value:float)
signal resource_revealed(resource:GameResource)

@export_group("Resources")
@export var current_resources:Dictionary[GameResource, float] = {}
@export var total_collected_resources:Dictionary[GameResource, float] = {}
@export var revealed_resources:Array[GameResource] = []
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

#region Resource managaement

#region Resources
	
func get_current_resource(res:GameResource)-> float:
	return current_resources.get(res, 0)
	
	
func is_resource_revealed(res:GameResource)-> bool:
	if res in revealed_resources:
		return true
	else:
		return false
		
		
func reveal_resource(resource:GameResource)-> void:
	if not resource in current_resources.keys():
		set_resource(resource, 0)
	revealed_resources.append(resource)
	resource_revealed.emit(resource)
	
	
func set_resource(resource:GameResource, value:float)-> void:
	var old_value:float = current_resources.get(resource, 0.0)
	current_resources[resource] = value

	if value > 0 and resource not in revealed_resources:
		reveal_resource(resource)

	if old_value != value:
		resource_changed.emit(resource, value)
		SignalManager.emit_this_frame(changed)
		SignalManager.emit_this_frame(resources_changed)


func increase_resources(amount:Dictionary[GameResource, float])-> void:
	for c in amount.keys():
		current_resources[c] += amount[c]

		if current_resources[c] > 0 and c not in revealed_resources:
			revealed_resources.append(c)
			resource_revealed.emit(c)

		if c not in total_collected_resources.keys():
			total_collected_resources[c] = 0
		total_collected_resources[c] += amount[c]

		resource_changed.emit(c, current_resources[c])

	SignalManager.emit_this_frame(changed)
	SignalManager.emit_this_frame(resources_changed)


func decrease_resources(amount:Dictionary[GameResource, float])-> void:
	if BuildConfig.Default.blank_check:
		push_warning("Omitting decrease_resources because blank_check is active")
		return

	for c in amount.keys():
		if is_nan(amount[c]): continue
		assert(current_resources[c] >= amount[c],
		"Can't take %s %s from %s" % [amount[c], c.dname, current_resources[c]])
		current_resources[c] -= amount[c]
		resource_changed.emit(c, current_resources[c])

	SignalManager.emit_this_frame(changed)
	SignalManager.emit_this_frame(resources_changed)
	
	
# this needs to be typed with GameResource, otherwise it conflicts when you
# use prices typed with GameResource
func can_afford(price:Dictionary[GameResource, float])-> bool:
	if BuildConfig.Default.blank_check:
		push_warning("Omitting can_afford checks because blank_check is active")
		return true

	for c in price.keys():
		if current_resources[c] < price[c]:
			return false

	return true
	
#endregion
