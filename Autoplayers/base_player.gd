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

## Whether this player records what it does in the gameplay log, under the
## Autoplayer tag. Separate from verbose: that one is narration for whoever is
## watching stdout, this one is for whatever reads the log afterwards.
##
## Turn it off for a run whose log should hold gameplay and nothing else.
@export var log_decisions:bool = true

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

## Where log_event() writes. Built on first use rather than in _init, because a
## Resource can be loaded before the Log autoload exists.
var _log:TaggedLogger


## Called once, as soon as a game scene exists and Current.Game and Current.Save
## are usable. Connect to signals here: this is a Resource, so it never receives
## _ready, and it outlives the game scene, so connecting on every game start
## would stack duplicate connections.
func initialize()-> void:
	time_played = 0
	total_time_played = 0
	is_finished = false

	log_event("Autoplayer started", {
		"autoplayer": resource_path,
		"strategy": _strategy_name(),
	})


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

	log_event("Autoplayer finished", {"reason": reason})

	on_finished()
	finished.emit(reason)


## Called once, as the player stops. Let go of anything being held down here: a
## finished player stops being ticked, so a crank left turning or a widget left
## hovered stays that way.
func on_finished()-> void:
	pass


## Prints a line tagged with how long this player had been going when it
## happened, if it is verbose.
##
## Tagged with total_time_played rather than time_played so the log stays in
## order: a prestige reset restarts the run, and with it time_played, which would
## otherwise send the timestamps back to zero halfway down the log.
func p(msg:String)-> void:
	if not verbose: return

	print("[AUTOPLAYER][%0.2f] %s" % [total_time_played, msg])


## Records something this player did in the gameplay log, under the Autoplayer
## tag, if it is set to. Strategies call this for the decisions worth keeping:
## what the gameplay log holds is what the game did, and a run's log should be
## able to say who was at the controls and why.
##
## time_played rides along on every entry, because the log's own timestamps are
## wall-clock and say nothing about how far into the run this happened.
func log_event(message:String, metadata:Dictionary = {})-> void:
	if not log_decisions: return

	if _log == null:
		_log = Log.get_tagged("Autoplayer")

	metadata["time_played"] = total_time_played
	_log.info(message, metadata)


## What to call this player's strategy in the log: its script's class_name, or
## the script's path when it has none.
func _strategy_name()-> String:
	var script:Script = get_script()
	if script == null: return ""

	var global_name:String = script.get_global_name()
	return global_name if not global_name.is_empty() else script.resource_path
