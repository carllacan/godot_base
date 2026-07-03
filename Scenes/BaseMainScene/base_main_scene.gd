extends Control
class_name BaseMainScene

## Base scene for managing game initialization, scene loading, and flow transitions.


@export var skip_main_menu_in_web:bool = false
@export_group("Scenes")
@export_file(".tscn") var game_scene_path:String = "res://Game/game_main.tscn"

@export var splash_screen_scene:PackedScene
@export var main_menu_scene:PackedScene
@export var load_screen_scene:PackedScene

@export_group("Debug")
@export var verbose:bool = false


var splash_screen:Node
var main_menu:Node
var load_screen:Node

var load_game_thread:Thread
var _current_game: Node


func _ready() -> void:
	assert(main_menu_scene != null)
	Events.new_game_requested.connect(_on_reset_requested)
	Events.load_save_requested.connect(continue_game)
	Events.main_menu_requested.connect(_on_main_menu_requested)
	Events.quit_game_requested.connect(_on_quit_requested)
	
	main_menu = main_menu_scene.instantiate()
	add_child(main_menu)
	
	_apply_cmdline_overrides()
	_preload_game_scene()

	if not BuildConfig.Default.skip_splash_screen:
		if splash_screen_scene != null:
			splash_screen = splash_screen_scene.instantiate()
			splash_screen.start()
			_hide_main_menu()
			await splash_screen.done


	_show_main_menu()

	if must_skip_main_menu():
		if BuildConfig.Default.force_new_game or not GameState.has_saved_game():
			begin_new_game()
		else:
			continue_game()


func must_skip_main_menu()-> bool:
	if BuildConfig.Default.skip_main_menu:
		return true
	
	if skip_main_menu_in_web and Flags.WEB:
		return true
		
	return false

## Override this to customize main menu appearance
func _show_main_menu() -> void:
	main_menu.show()
	
	
## Override this to customize main menu disappearance
func _hide_main_menu() -> void:
	main_menu.hide()


#region Menu Signal Connections

func _on_quit_requested()-> void:
	get_tree().quit()

#endregion


#region Game Flow

func begin_new_game() -> void:
	var game_run: GameState = GameState.create_new_run()
	assert(game_run != null)
	start_game(game_run)


func continue_game(game_run:GameState = null) -> void:
	if game_run == null:
		game_run = GameState.load_last_run()
	assert(game_run != null)
	start_game(game_run)


func start_game(game_run: GameState) -> void:
	_hide_main_menu()
	
	if load_screen_scene != null:
		load_screen = load_screen_scene.instantiate()
		add_child(load_screen)
		load_screen.show()

	if _current_game != null:
		remove_child(_current_game)
		_current_game.queue_free()
		_current_game = null

	Current.Save = game_run
	Events.save_loaded.emit(Current.Save)

	_preload_game_scene()
	await get_tree().create_timer(0.1).timeout
	await _wait_for_scene_load()

	var t0 := Time.get_ticks_msec()
	var packed := ResourceLoader.load_threaded_get(game_scene_path)
	var t1 := Time.get_ticks_msec()
	_current_game = packed.instantiate()
	var t2 := Time.get_ticks_msec()
	add_child(_current_game)
	var t3 := Time.get_ticks_msec()
	
	if load_screen != null:	
		load_screen.hide()
		load_screen.queue_free()

	_setup_game(_current_game)
	var t4 := Time.get_ticks_msec()

	print("load_threaded_get: %d ms" % [t1 - t0])
	print("instantiate: %d ms" % [t2 - t1])
	print("add_child: %d ms" % [t3 - t2])
	print("setup: %d ms" % [t4 - t3])

	Events.game_started.emit(_current_game)


## Override to customize game setup (connect signals, etc)
func _setup_game(_game: Node) -> void:
	pass


func _on_reset_requested() -> void:
	begin_new_game()


func _on_main_menu_requested() -> void:
	if _current_game != null:
		remove_child(_current_game)
		_current_game.queue_free()
		_current_game = null

	_preload_game_scene()
	_show_main_menu()

#endregion


#region Scene Loading

func _preload_game_scene() -> void:
	game_scene_path = game_scene_path

	var status := ResourceLoader.load_threaded_get_status(game_scene_path)
	if status == ResourceLoader.ThreadLoadStatus.THREAD_LOAD_INVALID_RESOURCE:
		ResourceLoader.load_threaded_request(game_scene_path, "", false)


func _wait_for_scene_load() -> void:
	while true:
		var s := ResourceLoader.load_threaded_get_status(game_scene_path)
		if s != ResourceLoader.ThreadLoadStatus.THREAD_LOAD_IN_PROGRESS:
			break
		await get_tree().process_frame

#endregion


#region Command Line Overrides

func _apply_cmdline_overrides() -> void:
	var args := OS.get_cmdline_user_args()
	# Usage example
	if "--straight-to-playing" in args:
		BuildConfig.Default.skip_splash_screen = true
		BuildConfig.Default.skip_main_menu = true
		BuildConfig.Default.force_new_game = true

#endregion
