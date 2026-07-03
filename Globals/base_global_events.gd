extends Node
class_name BaseGlobalEvents

## Events that are present in most games
## Other GodotBase features expect an autoload named Events that inherits this.

@warning_ignore_start("unused_signal")
signal save_loaded(save:GameState)
signal game_started(game:Node)
signal main_menu_requested
signal new_game_requested
signal load_save_requested(save:GameState)
signal quit_game_requested
