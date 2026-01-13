extends Node
class_name Sequencer


var sequence:Sequence
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
			entry = Utils.rand_weighted(entry.entries)
		for i in range(entry.repeats):
			elements.append(entry.content)
		
	last_yield_idx = 0


func get_next()-> Variant:
	var next = elements[last_yield_idx]
	last_yield_idx += 1
	if last_yield_idx == len(elements):
		last_yield_idx -= len(elements)
		
	return next
