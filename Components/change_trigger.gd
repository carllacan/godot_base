extends Node
class_name ChangeTrigger

signal integer_part_changed

## Emits a signals when a quantity crosses certain thresholds. For instance,
## every time it changes by at least 1 unit.

## Minimum value to trigger the signal
@export var min_value:float = NAN
## Maximum value to trigger the signal
@export var max_value:float = NAN

var old_value:float = NAN



func update_amount(new_value:float)-> void:
	
	if not is_nan(old_value) and not is_nan(new_value):
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
		integer_part_changed.emit()
