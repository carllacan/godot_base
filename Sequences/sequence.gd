@tool
extends Resource
class_name Sequence


@export var entries:Array[SequenceEntry] = []


func get_contents(skip_null:bool = true, skip_duplicates:bool = true)-> Array[Variant]:	
	var _contents:Array[Variant] = []
	for entry in entries:
		if entry is RandomSequenceEntry:
			for random_entry in entry.entries:
				_contents.append(random_entry.content)
		else:
			_contents.append(entry.content)
	
	# Filter out nulls and duplicates
	var contents:Array[Variant] = []
	for c in _contents:
		if c == null and skip_null: continue
		if c in contents and skip_duplicates: continue
		contents.append(c)
								
	return contents
