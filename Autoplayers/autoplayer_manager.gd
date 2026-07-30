extends Node
## Owns the lifecycle of the autoplayer configured in the build config, if any,
## and ticks it while a game is running.
##
## Being an autoload, this exists long before any game does, and it survives the
## teardown and rebuild of the game scene that a prestige reset triggers. So the
## player is only initialized once, and only ticked between game_started and the
## next teardown, which spares every strategy from null-checking Current.Game.

## Command line switch that picks the autoplayer, overriding whatever the build
## config holds. Takes a res:// path or an absolute filesystem path, written
## either way round, after the `--` that separates user arguments:
##
##   godot -- --autoplayer=res://Data/Dev/Autoplayers/cheapfirst.tres
##   godot -- --autoplayer /home/me/players/impatient.tres
##
## Pass NO_AUTOPLAYER instead of a path to play by hand for once without having
## to unassign the one in the build config.
const AUTOPLAYER_ARG:String = "--autoplayer"

## Value of AUTOPLAYER_ARG that turns autoplaying off outright:
##
##   godot -- --autoplayer=none
const NO_AUTOPLAYER:String = "none"

## Turn off to suspend the player without unassigning it from the build config.
var enabled:bool = true

var player:BaseAutoplayer

## Whether a game scene is currently up and Current.Game is safe to touch.
var is_playing:bool = false

## Fake pointer showing what the player is acting on. Only exists when a player
## is configured.
var cursor:AutoplayerCursor

var _is_initialized:bool = false


func _ready()-> void:
	var path:String = _get_cmdline_autoplayer_path()

	if path.to_lower() == NO_AUTOPLAYER:
		print("Autoplaying turned off from the command line")
		return

	if path.is_empty():
		player = BuildConfig.Default.autoplayer
	else:
		player = _load_player_at(path)

	if player == null: return

	# A player may drive windows, and an open window pauses the tree, so this has
	# to keep ticking through it. Strategies are responsible for standing still
	# during a pause they did not cause.
	process_mode = Node.PROCESS_MODE_ALWAYS

	cursor = AutoplayerCursor.new()
	add_child(cursor)

	Events.game_started.connect(_on_game_started)
	Events.save_loaded.connect(_on_save_loaded)
	Events.main_menu_requested.connect(_on_main_menu_requested)


## Loads the autoplayer sitting at a res:// or absolute path, or null when there
## is none to load. A path that cannot be used is reported rather than ignored: a
## run launched to autoplay itself and then quietly sitting idle is worse than a
## loud failure.
func _load_player_at(path:String)-> BaseAutoplayer:
	# res:// paths go through ResourceLoader; a path from outside the project only
	# shows up to FileAccess.
	if not ResourceLoader.exists(path) and not FileAccess.file_exists(path):
		push_error("No autoplayer found at %s" % path)
		return null

	var resource:Resource = ResourceLoader.load(path)
	if resource == null:
		push_error("Could not load an autoplayer from %s" % path)
		return null

	if resource is not BaseAutoplayer:
		# get_class() says "Resource" for anything script-backed, so name the
		# script instead: that is what tells you what you actually pointed at.
		var script:Script = resource.get_script()
		var kind:String = script.resource_path if script != null else resource.get_class()
		push_error("%s holds a %s, which is not an autoplayer" % [path, kind])
		return null

	print("Using the autoplayer at %s" % path)
	return resource


## The value given to AUTOPLAYER_ARG, written either as `--autoplayer=<value>` or
## as `--autoplayer <value>`. Empty when the switch is absent.
func _get_cmdline_autoplayer_path()-> String:
	var args:PackedStringArray = OS.get_cmdline_user_args()
	for i in args.size():
		var arg:String = args[i]

		if arg.begins_with(AUTOPLAYER_ARG + "="):
			return arg.trim_prefix(AUTOPLAYER_ARG + "=").strip_edges()

		if arg == AUTOPLAYER_ARG and i + 1 < args.size():
			return args[i + 1].strip_edges()

	return ""


func _on_game_started(_game:Node)-> void:
	# initialize() connects to signals, and this player outlives the game scene,
	# so running it on every game start would stack duplicate connections.
	if not _is_initialized:
		player.initialize()
		_is_initialized = true

	is_playing = true


func _on_save_loaded(_save)-> void:
	# Fired before the game scene is rebuilt, so the old one is on its way out.
	is_playing = false

	player.on_save_loaded()


func _on_main_menu_requested()-> void:
	is_playing = false


func _process(delta:float)-> void:
	if player == null: return
	if not enabled: return
	if not is_playing: return

	player.act(delta)
