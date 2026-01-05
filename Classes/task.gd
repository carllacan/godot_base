extends Object
class_name Task

signal done

var result

func set_result(new_value)-> void:
	result = new_value
	done.emit(result)
