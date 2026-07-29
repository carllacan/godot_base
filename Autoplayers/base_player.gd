extends Resource
class_name BaseAutoplayer
## Base class for the scripted players that play the game on their own, so a run
## can be watched or left running without a human at the controls.
##
## Strategies subclass this and override the hooks. AutoplayerManager owns the
## lifecycle and calls them; nothing here runs on its own.

## Whether this player narrates what it does. Its lines go through p().
@export var verbose:bool = true

## Seconds spent acting on the current run. Reset on every save load, so it reads
## as time into this run rather than time into the session.
var time_played:float = 0


## Called once, as soon as a game scene exists and Current.Game and Current.Save
## are usable. Connect to signals here: this is a Resource, so it never receives
## _ready, and it outlives the game scene, so connecting on every game start
## would stack duplicate connections.
func initialize()-> void:
	time_played = 0


## Called every time a save is loaded, including the reload that follows a
## prestige reset. Restart per-run bookkeeping here.
func on_save_loaded()-> void:
	time_played = 0


## Called every frame while a game is running.
func act(delta: float) -> void:
	time_played += delta


## Prints a line tagged with how far into the run it happened, when this player
## is verbose.
func p(msg:String)-> void:
	if not verbose: return

	print("[AUTOPLAYER][%0.2f] %s" % [time_played, msg])
