extends Node
class_name BaseSaveManager

signal saving_started
signal saving_finished

const SAVE_DEADTIME:float = 0.5

var current_save_deadtime:float = 0
var next_saving_method:Callable

var save_queued:bool = false
var is_saving:bool = false
var _save_thread: Thread = null


# Queue a Callable that will save the current game state. This allows decoupling
# this class from the actual saving system.
func queue_save(saving_method:Callable)-> void:
	next_saving_method = saving_method
	save_queued = true


func actually_save()-> void:
	if is_saving:
		push_error("SaveManager: actually_save() called while a save is already in progress. The save callback must not trigger another save.")
		return

	# Store the current saving callback so it can be overwritten safely
	var to_be_called = next_saving_method

	save_queued = false
	is_saving = true
	saving_started.emit()

	start_saving(to_be_called)


func start_saving(to_be_called: Callable)-> void:
	# Wait for any previous save thread to finish before starting a new one
	if _save_thread != null and _save_thread.is_alive():
		_save_thread.wait_to_finish()
		
	var save_and_cleanup = func():
		to_be_called.call()
		_on_save_thread_finished.call_deferred()

	if Flags.WEB:
		save_and_cleanup.call()
	else:
		_save_thread = Thread.new()
		_save_thread.start(save_and_cleanup)
		

func _on_save_thread_finished()-> void:
	if _save_thread != null:
		_save_thread.wait_to_finish()
		_save_thread = null
	is_saving = false
	saving_finished.emit()
	save_if_possible() # in case another one was queued while saving


func needs_to_save()-> bool:
	return save_queued


func save_if_possible()-> void:
	if current_save_deadtime > 0:
		return
	if is_saving:
		return
	if not needs_to_save():
		return

	actually_save()
	current_save_deadtime = SAVE_DEADTIME


func _physics_process(delta: float) -> void:
	current_save_deadtime -= delta
	if current_save_deadtime < 0: current_save_deadtime = 0 # clamp
	save_if_possible()
