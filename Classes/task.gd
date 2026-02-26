extends Object
class_name Task

signal done

var result

func set_result(new_value=null)-> void:
	result = new_value
	done.emit(result)

	
static func check_on_signal(target_signal:Signal, check:Callable)-> Task:	
	var t = Task.new()
	target_signal.connect(func(): 
		if check.call():
			t.set_result()
		)
	return t
