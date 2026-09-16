@tool
extends Resource
class_name BaseGameState

const DEFAULT_FILENAME = "save.tres"
const INITIAL_STATE_FILEPATH = "res://Data/GameStates/initial_game_state.tres"
const DEMO_INITIAL_STATE_FILEPATH = "res://Data/GameStates/demo_initial_game_state.tres"

## Command line switch that picks the directory saves are read from and written
## to, overriding saving_default_dir. Takes a path relative to user:// or an
## absolute filesystem path, written either way round, after the `--` that
## separates user arguments:
##
##   godot -- --save-dir=runs/a
##   godot -- --save-dir /tmp/bingo-run-a
##
## Give each one its own directory to run several copies of the game at once:
## otherwise they all write the same file and trample both it and each other.
const SAVE_DIR_ARG:String = "--save-dir"

## Command line switch that picks the filename, overriding
## saving_default_filename the same way SAVE_DIR_ARG overrides the directory:
##
##   godot -- --save-file=experiment.tres
##
## An absolute value names one file outright and the save directory is left out
## of it, so a run can be pointed straight at a state that lives somewhere else:
##
##   godot -- --save-file=/tmp/clip3.tres
##   godot -- --save-file=res://AssetCreation/TrailerMakers/Trailer1/state.tres
##
## Note the run saves back to wherever it was told to load from. Point one at a
## file worth keeping and set disable_saving on the build config, or it will be
## overwritten with whatever the run left behind.
const SAVE_FILE_ARG:String = "--save-file"


@export var id:String = ""
@export_group("Saving")
## Filename to save under when none is passed to save(). Empty means
## DEFAULT_FILENAME. SAVE_FILE_ARG overrides it.
@export var saving_default_filename:String = ""
## Default directory to save to. If empty saves go to user://, as they always
## have. Takes a path relative to user:// or an absolute filesystem path.
@export var saving_default_dir:String = ""
@export_group("Resources")
## Keeps track of GameResource reserves
@export var resources:BaseGameResourcesState: set = set_resources_state

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

## A subclass that declares its own _init() must call super(): GDScript does not
## chain constructors, and without a wallet here the legacy resource fields on an
## older save fail to assign while it is being deserialised, which drops their
## contents with no error the loader can report.
func _init()-> void:
	resources = BaseGameResourcesState.new()


func p(text:String)-> void:
	if not verbose: return
	print("GameState: %s" % text)

#region Saving

# Saves this run to a resource file. Uses a default filename if none specified
func save(filename:String = "")-> void:
	if Engine.is_editor_hint(): return
	if not saving_enabled: return
	
	SaveManager.queue_save(prepare_save.bind(filename))


## Runs on the main thread when a queued save starts and hands back the Callable
## that writes the file — see BaseSaveManager.queue_save().
##
## The snapshot is the point of this step. ResourceSaver.save() walks the state
## twice, once to collect every sub-resource and once to write them out, and the
## write runs on SaveManager's thread. Handed the live run, the main thread gets
## to insert a BallState, a CardState or a flying-coin id between the two passes;
## anything arriving in that window is written before it was ever registered,
## which is what "Resource was not pre cached for the resource section, bug?"
## reports, and an Array resized mid-serialisation can corrupt the file outright.
##
## DEEP_DUPLICATE_INTERNAL copies exactly the sub-resources a run mutates (balls,
## cards, stamps and the flying-coin ids, all of them built-in) and leaves the
## ones with a path — BallModel, CardModel, UpgradeModel, the stamp scenes —
## shared, so they still serialise as ext_resource references and still compare
## equal as Dictionary keys when the save is read back.
func prepare_save(filename:String = "")-> Callable:
	# Checked before duplicating rather than inside actually_save(): the snapshot
	# is the expensive half of a save, and there would be nothing to write.
	if BuildConfig.Default.disable_saving:
		return _refuse_save

	# Stamped here so the live run and the snapshot agree on when it was saved.
	timestamp_unix = Time.get_unix_time_from_system()
	version = Dist.get_version()

	return actually_save.bind(
		duplicate_deep(Resource.DEEP_DUPLICATE_INTERNAL), filename)


func _refuse_save()-> Error:
	print("Saving aborted because 'disable_saving' is enabled")
	return ERR_UNAUTHORIZED


## Writes [param state] out. This runs on SaveManager's save thread, so
## [param state] has to be the snapshot prepare_save() took rather than the live
## run: nothing here may touch state the main thread can still be changing.
func actually_save(state:BaseGameState, filename:String = "")-> Error:
	var result:Error

	# A name passed to save() beats the one this state was built with; both lose
	# to the command line, which get_state_filepath settles.
	var fname:String = filename if not filename.is_empty() else state.saving_default_filename
	var filepath:String = get_state_filepath(fname, state.saving_default_dir)

	# The directory can sit outside user://, so it has to be created as the
	# absolute path it is rather than relative to an opened user://.
	var save_dir:String = filepath.get_base_dir()
	if not DirAccess.dir_exists_absolute(save_dir):
		result = DirAccess.make_dir_recursive_absolute(save_dir)
		if result != OK:
			p("Creating save directory failed. Error code: %s" % result)

	result = ResourceSaver.save(state, filepath)

	if result == OK:
		p("Game saved to '%s'" % filepath)
	else:
		p("Error %s saving game to %s" % [result, filepath])
		
	# Upload save, if configured to do so.
	Integration.sync_file(filepath)
		
	return result


static func get_default_state()-> BaseGameState:
	return load(get_state_filepath())


## Where a save lives: the directory and the filename, each resolved the same
## way. Both parts are optional, because half the callers here are static and
## have no state to ask — they get the command line's answer, or the default.
static func get_state_filepath(filename:String = "", dir:String = "")-> String:
	return _resolve_save_path(get_save_dir(dir), get_save_filename(filename))


## Puts a save directory and filename together, unless the filename is already
## absolute, in which case it stands on its own and the directory has nothing to
## add. Without this, path_join would glue an absolute filename onto the save
## directory and produce a path that exists nowhere.
static func _resolve_save_path(save_dir:String, filename:String)-> String:
	if filename.is_absolute_path():
		return filename

	return save_dir.path_join(filename)


## The directory saves live in. The command line wins over [param dir] (a state's
## own saving_default_dir), since it is aimed at one launch in particular; with
## neither, saves go to user:// as they always have. A relative directory is
## taken as relative to user://, so both `runs/a` and `/tmp/runs/a` work.
##
## The switch is read here rather than stored: this runs both with a state in
## hand and without one, so anything remembered would have to be set by someone
## else before the first read, and a save written before that would go to the
## wrong place without saying so.
##
## [param is_demo] is only worth passing from the editor, where Flags.DEMO
## shortcuts to false and would give the wrong directory.
static func get_save_dir(dir:String = "", is_demo:bool = Flags.DEMO)-> String:
	var base:String = "user://"

	var override:String = CommandLineManager.get_value(SAVE_DIR_ARG)
	if not override.is_empty():
		base = override
	elif not dir.is_empty():
		base = dir

	if not base.is_absolute_path():
		base = "user://".path_join(base)

	if is_demo:
		base = base.path_join("demo")

	return base


## The filename saves are written under, in the same order of precedence as
## get_save_dir: the command line, then [param filename] (a state's own
## saving_default_filename, or a name passed to save()), then DEFAULT_FILENAME.
##
## Having this makes the static readers below honour a configured filename
## instead of only ever looking for DEFAULT_FILENAME, which is what let a run
## save to one name and then go looking for another.
static func get_save_filename(filename:String = "")-> String:
	var override:String = CommandLineManager.get_value(SAVE_FILE_ARG)
	if not override.is_empty():
		return override

	if not filename.is_empty():
		return filename

	return DEFAULT_FILENAME
	
	
# Loads a GameState saved as a resource
static func load_from_file(filepath:String)-> BaseGameState:
	# Sync save, if configured to do so. This might download a new save.
	Integration.sync_file(filepath)
	
	# IGNORE (not IGNORE_DEEP): the save file itself must always be re-read
	# fresh, but its ext_resource dependencies (UpgradeModel, CardModel, etc.)
	# must be reused from cache. Those are used as Dictionary keys elsewhere
	# (e.g. UpgradeModel.requirements) and Dictionary equality for Resources is
	# identity-based, so forcing them to reload as new instances orphans the
	# values stored under the old key.
	var r:BaseGameState = ResourceLoader.load(filepath,
		"", ResourceLoader.CACHE_MODE_IGNORE)
	
	if r != null:
		print("Game loaded from '%s'" % filepath)
	else:
		print("Game loaded failed.")
		
		
	return r
	
	
## To be called just before the game starts
func on_load()-> void:
	# Late enough that the loader has finished setting properties, so verbose is
	# whatever the file said rather than the default it held while binding.
	resources.verbose = verbose
	resources.on_load()


func initialize()-> void:
	resources = BaseGameResourcesState.new()
	resources.initialize()


#region State Loading/Creation (for BaseMainScene)

## Loads the last saved state, checking testing save first (if in DEBUG mode), then user save.
## Returns null if no saved game exists.
static func load_last_state()-> BaseGameState:
	var game_state: BaseGameState
	if BuildConfig.Default.use_testing_savefile and Flags.DEBUG:
		assert(BuildConfig.Default.testing_savefile, "No testing save!")
		game_state = BuildConfig.Default.testing_savefile
		if game_state != null:
			print("Loaded testing state")
		else:
			push_error("Failed to load testing state")
	else:
		var last_saved_state_filepath: String = get_state_filepath()
		if FileAccess.file_exists(last_saved_state_filepath):
			game_state = load_from_file(last_saved_state_filepath)
			if game_state != null:
				print("Last game state successfully loaded")
			else:
				push_error("FAILED to load saved file, even though it exists")
		else:
			print("No last-save file found at '%s'" % last_saved_state_filepath)

	return game_state


## Creates a new state by loading from initial save (respecting DEMO flag) or creating fresh.
## Implements fallback chain: initial save → create new.
static func create_new_state()-> GameState:
	var game_state: GameState

	var initial_game_state_path:String = ""
	if Flags.DEMO:
		print("Loading DEMO initial save file")
		initial_game_state_path = DEMO_INITIAL_STATE_FILEPATH
	else:
		print("Loading initial save file")
		initial_game_state_path = INITIAL_STATE_FILEPATH


	if FileAccess.file_exists(initial_game_state_path):
		game_state = load(initial_game_state_path)
	else:
		game_state = GameState.new()
		game_state.id = str(game_state.get_rid().get_id())
		game_state.initialize()

	assert(game_state != null)

	return game_state


## Brings the save at the configured path in line with the platform's cloud copy,
## downloading it if this machine has none.
##
## This has to run before anything asks has_saved_game(), which only ever looks at
## the local disk: a fresh install with a save in the cloud would otherwise be told
## it has no save, start a new game, and then upload that new game over the old one
## on its first save.
static func sync_save_with_cloud()-> void:
	Integration.sync_file(get_state_filepath())


## Checks if a saved game exists (returns true if load_last_state would succeed).
static func has_saved_game()-> bool:
	if BuildConfig.Default.use_testing_savefile and Flags.DEBUG:
		return true
	var last_saved_state_filepath: String = get_state_filepath()
	if FileAccess.file_exists(last_saved_state_filepath):
		return true
		
	return false

#endregion Saving

#region Resource management

func set_resources_state(new_value:BaseGameResourcesState)-> void:
	var old_value = resources
	resources = new_value
	var has_changed:bool = old_value != new_value

	if has_changed:
		_on_resources_state_changed(old_value, new_value)


## Called when [member resources] is replaced. Subclasses that relay the wallet's
## signals rebind them here, and must call super() to keep [signal
## Resource.changed] propagating: Godot does not forward that from a sub-resource
## to the resource holding it.
func _on_resources_state_changed(
	old_value:BaseGameResourcesState, new_value:BaseGameResourcesState
	)-> void:

	if old_value != null:
		old_value.changed.disconnect(emit_changed)
	if new_value != null:
		new_value.changed.connect(emit_changed)


#endregion


#region Tools

func set_as_testing_savefile()-> void:
	if not Engine.is_editor_hint():
		return

	var config := BuildConfig.Default
	config.testing_savefile = self
	config.use_testing_savefile = true

	if config.resource_path.is_empty():
		push_error("Build config has no resource_path — can't save it.")
		return

	var err := ResourceSaver.save(config, config.resource_path)
	if err != OK:
		push_error("Failed to save build config: %d" % err)
	else:
		print("Set %s as testing savefile and saved %s" % [
			resource_path, config.resource_path])


func overwrite_user_save() -> void:
	if resource_path.is_empty():
		push_error("This resource has no file path — save it as a .tres first.")
		return

	var is_demo := Flags.DEMO
	var dest_virtual:String = _resolve_save_path(
			get_save_dir(saving_default_dir, is_demo),
			get_save_filename(saving_default_filename))

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
