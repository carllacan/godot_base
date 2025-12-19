extends CanvasLayer
class_name WindowsLayer

#signal window_open
#signal window_closed
signal window_changed

@export var windows:Array[BaseWindow] = []

static var CurrentLayer:WindowsLayer


func _ready()-> void:	
	# TODO: maybe append windows automatically?
	for w in windows:
		add_window(w)
	update_visibility()
	
	if CurrentLayer == null:
		CurrentLayer = self
		

func add_window(w)-> void:
	if not w.is_node_ready(): # temporary hack
		%CurrentWindowContainer.add_child(w)
	if not w in windows:
		windows.append(w)
	w.hide()
	w.started_opening.connect(_on_window_started_opening.bind(w))
	w.visibility_changed.connect(_on_window_visibility_changed.bind(w))
	w.destroyed.connect(windows.erase.bind(w))
	
				
func _on_window_started_opening(w:BaseWindow)-> void:
	close_all_but(w)
	
	
func _on_window_visibility_changed(_w:BaseWindow)-> void:
	update_visibility()
	window_changed.emit()
	
	if any_window_open():
		Pause.can_pause = false
		Pause.add_pause_source(self)
	else:
		Pause.can_pause = true
		Pause.remove_pause_source(self)
	
	# TODO: emit open/close windows
	# TODO: close all other windows if this has been opened
	
	
func any_window_open()-> bool:
	if get_open_window() == null:
		return false
	else:
		return true
	
	
func get_open_window()-> BaseWindow:
	for w in windows:
		if w.is_open() or w.is_opening():# w.visible:
			return w
	return null
	
	
	
func update_visibility()-> void:			
	visible = any_window_open()


func close_all()-> void:
	close_all_but(null)
	
	
func close_all_but(exception:BaseWindow)-> void:
	for w in windows:
		if w == exception: continue
		if not w.is_closed() and not w.is_closing():# w.visible:
			w.close()
			
			
func _input(event: InputEvent) -> void:	
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT:					
			if any_window_open():				
				var w = get_open_window()
				if w.close_on_outside_click:
					#var mpos = get_viewport().get_mouse_position()
					#if not w.get_rect().has_point(mpos):
						#close_all()
					var hov = get_viewport().gui_get_hovered_control()
					if not w.is_ancestor_of(hov):
						close_all()
	
