extends Node
class_name Sequencer

enum EndMode {
	STOP,
	CYCLE_BACK,
	MAINTAIN_LAST,
}

var sequence:Sequence
var end_mode:EndMode = EndMode.MAINTAIN_LAST

var elements:Array[Variant] = []
var last_yield_idx:int = 0


func start_sequence(new_sequence:Sequence)-> void:
	sequence = new_sequence
	restart()
	
	
func restart()-> void:
	if sequence == null:
		push_error("No Sequence defined")
		return
		
	elements = []
	for entry in sequence.entries:
		if entry is RandomSequenceEntry:			
			for i in range(entry.repeats):
				var random_entry = Utils.rand_weighted(entry.entries)
				elements.append(random_entry.content)
		else:
			for i in range(entry.repeats):
				elements.append(entry.content)
		
	last_yield_idx = 0
	
			
func get_next()-> Variant:
	if last_yield_idx >= len(elements):
		match end_mode:
			EndMode.STOP:
				return null
			EndMode.CYCLE_BACK:
				last_yield_idx -= len(elements)
			EndMode.MAINTAIN_LAST:
				return elements[-1]
							
	var next = elements[last_yield_idx]
	
	last_yield_idx += 1	
		
	return next
