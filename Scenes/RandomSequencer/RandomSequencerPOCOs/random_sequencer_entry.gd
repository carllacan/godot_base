extends Resource
class_name RandomSequencerEntry 


@export var element:Resource
@export var weight:float = 0
@export var max_in_a_row:int = -1
@export var max_simultaneous:int = -1


func has_a_repetition_max()-> bool:
	return max_in_a_row > 0
	
	
func has_a_simultaneous_max()-> bool:
	return max_simultaneous > 0
