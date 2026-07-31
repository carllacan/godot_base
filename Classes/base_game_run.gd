@tool
extends Resource
class_name BaseGameState

const DEFAULT_FILENAME = "save.tres"
const INITIAL_RUN_FILEPATH = "res://Data/GameStates/initial_game_run.tres"
const DEMO_INITIAL_RUN_FILEPATH = "res://Data/GameRuns/demo_initial_game_run.tres"


signal resources_changed
signal resource_changed(resource:GameResource, new_value:float)
signal resource_revealed(resource:GameResource)

@export var id:String = ""
@export_group("Saving")
## Default filename if none is specified when calling save(). If empty it will use
## the global default saving path
@export var saving_default_filename:String = "" # TODO use in get_default_run(), load_last_run(), and has_saved_game()
## Default directory to save to. If empty saves go to user://, as they always
## have. Takes a path relative to user:// or an absolute filesystem path.
@export var saving_default_dir:String = ""
@export_group("Resources")
## Current amount of resources available to the player
@export var current_resources:Dictionary[GameResource, float] = {}
## Resources of each kind collected through the entire run.
@export var total_collected_resources:Dictionary[GameResource, float] = {}
## Which resources have been revealed to the player so far
@export var revealed_resources:Array[GameResource] = []
@export_group("Debug")
@export var verbose:bool = false
@export_group("Others")
@export var timestamp_unix:float = 0
@export var version:String
@export_group("Tools")
@export_tool_button("Set as testing") var sat = set_as_testing_savefile
@export_tool_button("Overwrite user save") var ous = overwrite_user_save
@export_tool_button("Initialize this save") var its = initialize_this_save


var saving_enabled:bool = true

## Save directory picked from the command line, overriding saving_default_dir on
## every state (see BaseMainScene.SAVE_DIR_ARG). This is static because the
## filepath helpers below are: they run without a state in hand, so an export
## alone would be invisible to them. Set before any save is written or read.
static var cmdline_save_dir:String = ""


func p(text:String)-> void:
	if not verbose: return
	print("GameState: %s" % text)

#region Saving

# Saves this run to a resource file. Uses a default filename if none specified
func save(filename:String = "")-> void:
	if Engine.is_editor_hint(): return
	if not saving_enabled: return
	
	SaveManager.queue_save(actually_save.bind(filename))
	
	
func actually_save(filename:String = "")-> Error:
	var result:Error
	
	var fname:String
	if filename == "":
		if saving_default_filename != "":
			fname = saving_default_filename
		else:
			fname = DEFAULT_FILENAME
	else:
		fname = filename

	var filepath:String = get_run_filepath(fname, saving_default_dir)

	if BuildConfig.Default.disable_saving:
		print("Saving aborted because 'disable_saves' is enabled")
		return ERR_UNAUTHORIZED

	# The directory can sit outside user://, so it has to be created as the
	# absolute path it is rather than relative to an opened user://.
	var save_dir:String = filepath.get_base_dir()
	if not DirAccess.dir_exists_absolute(save_dir):
		result = DirAccess.make_dir_recursive_absolute(save_dir)
		if result != OK:
			p("Creating save directory failed. Error code: %s" % result)

	timestamp_unix = Time.get_unix_time_from_system()
	version = Dist.get_version()
		
	result = ResourceSaver.save(self, filepath)
	
	if result == OK:
		p("Game saved to '%s'" % filepath)
	else:
		p("Error %s saving game to %s" % [result, filepath])
		
	# Upload save, if configured to do so.
	Integration.sync_file(filepath)
		
	return result


static func get_default_run()-> BaseGameState:
	var filepath = get_run_filepath(DEFAULT_FILENAME)
	return load(filepath)
		
		
# Joins the save files directory with a filename
static func get_run_filepath(filename:String, dir:String = "")-> String:
	return get_save_dir(dir).path_join(filename)


## The directory saves live in. The command line wins over [param dir] (a state's
## own saving_default_dir), since it is aimed at one launch in particular; with
## neither, saves go to user:// as they always have. A relative directory is
## taken as relative to user://, so both `runs/a` and `/tmp/runs/a` work.
##
## [param is_demo] is only worth passing from the editor, where Flags.DEMO
## shortcuts to false and would give the wrong directory.
static func get_save_dir(dir:String = "", is_demo:bool = Flags.DEMO)-> String:
	var base:String = "user://"
	if not cmdline_save_dir.is_empty():
		base = cmdline_save_dir
	elif not dir.is_empty():
		base = dir

	if not base.is_absolute_path():
		base = "user://".path_join(base)

	if is_demo:
		base = base.path_join("demo")

	return base
	
	
# Loads a GameRun saved as a resource
static func load_from_file(filepath:String)-> BaseGameState:
	# Sync save, if configured to do so. This might download a new save.
	Integration.sync_file(filepath)
	
	# IGNORE (not IGNORE_DEEP): the save file itself must always be re-read
	# fresh, but its ext_resource dependencies (GameResource singletons,
	# UpgradeInfo, CardModel, etc.) must be reused from cache. Those are used
	# as Dictionary keys elsewhere (e.g. current_resources[GameResource.COINS])
	# and Dictionary equality for Resources is identity-based, so forcing them
	# to reload as new instances orphans the values stored under the old key.
	var r:BaseGameState = ResourceLoader.load(filepath,
		"", ResourceLoader.CACHE_MODE_IGNORE)
	
	if r != null:
		print("Game loaded from '%s'" % filepath)
	else:
		print("Game loaded failed.")
		
		
	return r
	
	
## To be called just before the game starts
func on_load()-> void:
	# Ensure the total_collected resources is at least coherent.
	# Manually created saves might leave it empty, while having positive 
	# values in current_resources
	for r in current_resources.keys():
		var t = total_collected_resources.get(r, 0)
		if t < current_resources[r]:
			total_collected_resources[r] = current_resources[r]
	

func initialize()-> void:
	current_resources = {}
	revealed_resources = []
	total_collected_resources = {}


#region Run Loading/Creation (for BaseMainScene)

## Loads the last saved run, checking testing save first (if in DEBUG mode), then user save.
## Returns null if no saved game exists.
static func load_last_run()-> BaseGameState:
	var game_run: BaseGameState
	if BuildConfig.Default.use_testing_savefile and Flags.DEBUG:
		assert(BuildConfig.Default.testing_savefile, "No testing save!")
		game_run = BuildConfig.Default.testing_savefile
		if game_run != null:
			print("Loaded testing run")
		else:
			push_error("Failed to load testing run")
	else:
		var last_saved_run_filepath: String = get_run_filepath(DEFAULT_FILENAME)
		if FileAccess.file_exists(last_saved_run_filepath):
			game_run = load_from_file(last_saved_run_filepath)
			if game_run != null:
				print("Last game run successfully loaded")
			else:
				push_error("FAILED to load saved file, even though it exists")
		else:
			print("No last-save file found at '%s'" % last_saved_run_filepath)

	return game_run


## Creates a new run by loading from initial save (respecting DEMO flag) or creating fresh.
## Implements fallback chain: initial save → create new.
static func create_new_run()-> GameState:
	var game_run: GameState

	var initial_game_run_path:String = ""
	if Flags.DEMO:
		print("Loading DEMO initial save file")
		initial_game_run_path = DEMO_INITIAL_RUN_FILEPATH
	else:
		print("Loading initial save file")
		initial_game_run_path = INITIAL_RUN_FILEPATH
		

	if FileAccess.file_exists(initial_game_run_path):
		game_run = load(initial_game_run_path)
	else:
		push_warning("Initial save not found, creating empty run")
		game_run = GameState.new()
		game_run.id = str(game_run.get_rid().get_id())
		game_run.initialize()

	assert(game_run != null)

	return game_run


## Checks if a saved game exists (returns true if load_last_run would succeed).
static func has_saved_game()-> bool:
	if BuildConfig.Default.use_testing_savefile and Flags.DEBUG:
		return true
	var last_saved_run_filepath: String = get_run_filepath(DEFAULT_FILENAME)
	if FileAccess.file_exists(last_saved_run_filepath):
		return true
		
	return false

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
			
		if c not in current_resources.keys(): current_resources[c] = 0 # JIC
		current_resources[c] += amount[c]

		if c not in total_collected_resources.keys():
			total_collected_resources[c] = 0
		total_collected_resources[c] += amount[c]

		resource_changed.emit(c, current_resources[c])

	save()
	SignalManager.emit_this_frame(changed)
	SignalManager.emit_this_frame(resources_changed)


func decrease_resource(resource:GameResource, amount: float)-> void:
	return decrease_resources({resource: amount})
	
	
func decrease_resources(amount:Dictionary[GameResource, float])-> void:
	if BuildConfig.Default.blank_check:
		push_warning("Omitting decrease_resources because blank_check is active")
		return

	for c in amount.keys():
		if is_nan(amount[c]): continue
		if amount[c] == 0: continue
		
		assert(
			get_current_resource(c) >= amount[c],
			"Can't take %s %s from %s" % [amount[c], c.dname, get_current_resource(c)]
		)
		
		current_resources[c] -= amount[c]
		
		resource_changed.emit(c, get_current_resource(c))

	save()
	SignalManager.emit_this_frame(changed)
	SignalManager.emit_this_frame(resources_changed)
	
	
# this needs to be typed with GameResource, otherwise it conflicts when you
# use prices typed with GameResource
func can_afford(price:Dictionary[GameResource, float])-> bool:
	if BuildConfig.Default.blank_check:
		#push_warning("Omitting can_afford checks because blank_check is active")
		return true

	for c in price.keys():
		if get_current_resource(c) < price[c]:
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
	var dest_virtual:String = get_save_dir(saving_default_dir, is_demo) \
			.path_join(DEFAULT_FILENAME)

	# The destination can sit outside user://, so create it as an absolute path.
	DirAccess.make_dir_recursive_absolute(dest_virtual.get_base_dir())

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


func initialize_this_save()-> void:
	if not Engine.is_editor_hint():
		return

	var _dialog: ConfirmationDialog
	_dialog = ConfirmationDialog.new()
	_dialog.title = "Confirm"
	_dialog.dialog_text = "This will reset this save to the default state. Continue?"
	_dialog.confirmed.connect(initialize)
	# Editor classes don't exist in export templates and naming them fails at
	# parse time (godotengine/godot#91713), so resolve the singleton by name.
	Engine.get_singleton(&"EditorInterface").get_base_control().add_child(_dialog)

	_dialog.popup_centered()
	

#endregion
