extends Node
class_name ChangeTrigger

## Todo: move out of Components folder

signal change_detected

## Emits a signals when a quantity crosses certain thresholds. For instance,
## if min_value = 1 and max_value = INF then the signal will trigger every
## time the amount changes by 1

## Minimum value to trigger the signal
@export var min_value:float = -INF
## Maximum value to trigger the signal
@export var max_value:float = INF
## Value against which the quantity will be compared the first time. 
@export var initial_value:float = 0
## Useful to make it skip triggers caused by loading the game
@export var skip_triggers:int = 0


var old_value:float = NAN
var skipped:int = 0


func update_amount(new_value:float)-> void:
	if is_nan(old_value):
		old_value = initial_value
			
	if not is_nan(new_value):
		react_to_changes(old_value, new_value)
			
	# Update stored amount
	old_value = new_value


## Detect and trigger change effects		
func react_to_changes(prev_value:float, new_value:float)-> void:
			
	if not is_nan(min_value) and new_value < min_value:
		return
	if not is_nan(max_value) and new_value > max_value:
		return
		
	# Detect changes in the integer part
	if int(prev_value) != int(new_value):
		if skipped >= skip_triggers:
			change_detected.emit()
		else:
			skipped += 1
