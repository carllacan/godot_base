@tool
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
@export_group("Debug")
@export var verbose:bool = false
@export_group("Others")
@export var timestamp_unix:float = 0
@export var version:String
@export_group("Tools")
@export_tool_button("Set as testing") var sat = set_as_testing_savefile
@export_tool_button("Overwrite user save") var ous = overwrite_user_save


func p(text:String)-> void:
	if not verbose: return
	print("GameState: %s" % text)

#region Saving

# Saves this run to a resource file. Uses a default filename if none specified
func save(filepath:String = "")-> void:
	if Engine.is_editor_hint(): return
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
		p("Creating save directory failed. Error code: %s" % result)
		
	timestamp_unix = Time.get_unix_time_from_system()
	version = Dist.get_version()
		
	result = ResourceSaver.save(self, filepath)
	
	if result == OK:
		p("Game saved to '%s'" % filepath)
	else:
		p("Game saving failed. Error code: %s" % result)
		
	# Upload save, if configured to do so.
	Integration.sync_file(filepath)
		
	return result


static func get_default_run()-> BaseGameState:
	var filepath = get_run_filepath(DEFAULT_FILENAME)
	return load(filepath)
		
		
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
		
	r.on_load()
		
	return r
	
	
func on_load()-> void:
	return
	
#endregion Saving

#region Resource management

	
func get_current_resource(res:GameResource)-> float:
	return current_resources.get(res, 0)
	
	
func is_resource_revealed(res:GameResource)-> bool:
	if res in revealed_resources:
		p("%s IS revealed" % res.dname)
		return true
	else:
		return false
		
		
func reveal_resource(resource:GameResource)-> void:
	if not resource in current_resources.keys():
		set_resource(resource, 0)
	revealed_resources.append(resource)
	resource_revealed.emit(resource)
	p("%s revealed" % resource.dname)
	
	
func set_resource(resource:GameResource, value:float)-> void:
	var old_value:float = current_resources.get(resource, 0.0)
	current_resources[resource] = value

	if value > 0 and resource not in revealed_resources:
		reveal_resource(resource)

	if old_value != value:
		resource_changed.emit(resource, value)
		SignalManager.emit_this_frame(changed)
		SignalManager.emit_this_frame(resources_changed)


func increase_resource(resource:GameResource, amount: float)-> void:
	return increase_resources({resource: amount})
	
	
func increase_resources(amount:Dictionary[GameResource, float])-> void:
	for c in amount.keys():
		if amount[c] == 0:
			continue
			
		if c not in revealed_resources:
			reveal_resource(c)
			
		current_resources[c] += amount[c]

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


#region Tools

func set_as_testing_savefile()-> void:
	BuildConfig.Default.testing_savefile = self


func overwrite_user_save() -> void:
	if resource_path.is_empty():
		push_error("This resource has no file path — save it as a .tres first.")
		return

	# Replicate Flags.DEMO logic directly — Flags.DEMO shortcuts to false in
	# editor, which would ignore force_demo and give the wrong destination path.
	var is_demo := BuildConfig.Default.force_flag(
			OS.has_feature("demo"), BuildConfig.Default.force_demo)
	var dest_virtual: String
	if is_demo:
		dest_virtual = "user://".path_join("demo").path_join(DEFAULT_FILENAME)
	else:
		dest_virtual = "user://".path_join(DEFAULT_FILENAME)

	DirAccess.open("user://").make_dir_recursive(dest_virtual.get_base_dir())

	var source_path := ProjectSettings.globalize_path(resource_path)
	var dest_path := ProjectSettings.globalize_path(dest_virtual)

	var source_file := FileAccess.open(source_path, FileAccess.READ)
	if not source_file:
		push_error("Could not open source file: %s" % source_path)
		return
	var content := source_file.get_buffer(source_file.get_length())
	source_file.close()

	var dest_file := FileAccess.open(dest_path, FileAccess.WRITE)
	if not dest_file:
		push_error("Could not open destination file: %s" % dest_path)
		return
	dest_file.store_buffer(content)
	dest_file.close()

	print("Overwrote user save: %s -> %s" % [resource_path, dest_virtual])


#endregion
