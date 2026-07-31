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


# Queue a save. This class stays decoupled from the actual saving system, which
# it only ever sees as Callables.
#
# Saving happens in two steps because the write may run on a background thread.
# [param prepare_method] is called on the main thread once the save actually
# starts and must return the Callable that does the writing; taking whatever
# snapshot that writer needs is its job. The writer itself then runs off-thread,
# so it may only touch state nobody else can be changing meanwhile — see
# BaseGameState.prepare_save() for what goes wrong otherwise.
func queue_save(prepare_method:Callable)-> void:
	next_saving_method = prepare_method
	save_queued = true


func actually_save()-> void:
	if is_saving:
		push_error("SaveManager: actually_save() called while a save is already in progress. The save callback must not trigger another save.")
		return

	# Store the current callback so it can be overwritten safely
	var prepare_method:Callable = next_saving_method

	save_queued = false

	# Still on the main thread: this is the queued save's chance to snapshot.
	var to_be_called:Variant = prepare_method.call()
	if not (to_be_called is Callable and (to_be_called as Callable).is_valid()):
		push_error("SaveManager: the queued save returned no writer, nothing was saved.")
		return

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


func flush_saves()-> void:
	save_if_possible()
	

func _physics_process(delta: float) -> void:
	current_save_deadtime -= delta
	if current_save_deadtime < 0: current_save_deadtime = 0 # clamp
	save_if_possible()
