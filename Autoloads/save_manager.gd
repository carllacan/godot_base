extends Node
class_name BaseSaveManager

signal saving_started
signal saving_finished

const SAVE_DEADTIME:float = 0.5

var current_save_deadtime:float = 0
var next_saving_method:Callable

var save_queued:bool = false
var is_saving:bool = false


# Queue a Callable that will save the current game state. This allows decoupling
# this class from the actual saving system.
func queue_save(saving_method:Callable)-> void:
	next_saving_method = saving_method
	save_queued = true
	
	
func actually_save()-> void:
	# Store the current saving callback so it can be overwritten safely
	var to_be_called = next_saving_method 	
	
	# Start saving method
	save_queued = false
	is_saving = true
	saving_started.emit()
	
	to_be_called.call()
	
	save_if_possible()
	is_saving = false
	saving_finished.emit()
	
	
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
