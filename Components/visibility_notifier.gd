extends Node

signal shown
signal hidden
signal visibility_changed

var visible_last_frame:bool = false


func _process(_delta: float) -> void:
	var visible = get_parent().visible
	
	if visible != visible_last_frame:
		if visible: 
			shown.emit()
		if not visible: 
			hidden.emit()
		visibility_changed.emit()
		
	visible_last_frame = visible
