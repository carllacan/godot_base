extends Node
## Owns the lifecycle of the autoplayer configured in the build config, if any,
## and ticks it while a game is running.
##
## Being an autoload, this exists long before any game does, and it survives the
## teardown and rebuild of the game scene that a prestige reset triggers. So the
## player is only initialized once, and only ticked between game_started and the
## next teardown, which spares every strategy from null-checking Current.Game.

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
	player = BuildConfig.Default.autoplayer
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
