extends Resource
class_name BaseAutoplayer


var time_played:float = 0


func act(delta: float) -> void:
	time_played += delta
