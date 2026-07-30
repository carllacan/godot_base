extends Resource
class_name BaseAutoplayer
## Base class for the scripted players that play the game on their own, so a run
## can be watched or left running without a human at the controls.
##
## Strategies subclass this and override the hooks. AutoplayerManager owns the
## lifecycle and calls them; nothing here runs on its own.

## Emitted once, when an ending condition is met. AutoplayerManager listens and
## stops ticking this player, and closes the game if it is set to.
signal finished(reason:String)

## Whether this player narrates what it does. Its lines go through p().
@export var verbose:bool = true

@export_group("Ending conditions")
## Seconds of play after which the player stops. Zero, or less, plays forever.
##
## Measured against total_time_played, so it is time spent playing rather than
## wall-clock time: a run left sitting in the main menu does not age.
@export var max_time_played:float = 0

## Seconds spent acting on the current run. Reset on every save load, so it reads
## as time into this run rather than time into the session.
var time_played:float = 0

## Seconds spent acting since this player started, across save loads and the
## prestige resets that cause them. Ending conditions measure this rather than
## time_played: a player that prestiges would otherwise keep resetting its own
## clock and never reach the end.
var total_time_played:float = 0

## Whether an ending condition has been met. A finished player is never ticked
## again, so nothing has to keep checking this.
var is_finished:bool = false


## Called once, as soon as a game scene exists and Current.Game and Current.Save
## are usable. Connect to signals here: this is a Resource, so it never receives
## _ready, and it outlives the game scene, so connecting on every game start
## would stack duplicate connections.
func initialize()-> void:
	time_played = 0
	total_time_played = 0
	is_finished = false


## Called every time a save is loaded, including the reload that follows a
## prestige reset. Restart per-run bookkeeping here.
func on_save_loaded()-> void:
	time_played = 0


## Called every frame while a game is running.
func act(delta: float) -> void:
	time_played += delta
	total_time_played += delta


## Whether an ending condition has been met: a reason to report when the player
## should stop, or an empty string to carry on. Checked after every act().
##
## Override to add conditions of your own, and report the first reason the base
## class gives before checking them, so a time limit still ends a player that its
## own conditions would keep going.
func get_ending_reason()-> String:
	if max_time_played > 0 and total_time_played >= max_time_played:
		return "played for %0.0fs (max_time_played is %0.0f)" % [
			total_time_played, max_time_played]

	return ""


## Stops this player for good. Called by AutoplayerManager when an ending
## condition is met, and callable by a strategy that decides it is done for
## reasons of its own.
func finish(reason:String)-> void:
	if is_finished: return

	is_finished = true
	p("Done playing: %s" % reason)

	on_finished()
	finished.emit(reason)


## Called once, as the player stops. Let go of anything being held down here: a
## finished player stops being ticked, so a crank left turning or a widget left
## hovered stays that way.
func on_finished()-> void:
	pass


## Prints a line tagged with how far into the run it happened, when this player
## is verbose.
func p(msg:String)-> void:
	if not verbose: return

	print("[AUTOPLAYER][%0.2f] %s" % [time_played, msg])
