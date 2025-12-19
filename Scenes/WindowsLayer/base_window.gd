class_name BaseWindow
extends Control
const BASE_SCENE = preload("res://GodotBase/Scenes/WindowsLayer/base_window.tscn")

signal started_opening
signal started_closing
signal opened
signal closed
signal destroyed

enum Results
{
	_UNDEF,
	No,
	Yes,
}

enum State
{
	_undef,
	CLOSED,
	OPENING,
	OPEN,
	CLOSING,
}

var result:Results = Results._UNDEF
var state:State = State._undef : set = set_state

@export_subgroup("Contents")
@export var title:String = "" : set = set_title
@export var text:String = "" : set = set_text
@export_subgroup("Actions")
@export var can_accept:bool = true
@export var accept_action:String = "ui_accept"
@export var can_cancel:bool = true
@export var cancel_action:String = "ui_cancel"
# Whether actions ui_cancel and ui_accept will be listened to
@export var ui_actions_enabled:bool = true
@export var close_on_outside_click:bool = true
@export var destroy_on_close:bool = false
@export_subgroup("Sounds")
@export var click_sound_on_opening:bool = true
@export var click_sound_on_closing:bool = true
@export_subgroup("Animations")
## Time in seconds it will take the window to fade in or out. Zero disables it.
@export var fading_time:float = 0.08
## Time in seconds it will take the window to grow in or grow out. Zero disables it.
@export var grow_in_time:float = 0.0
@export_subgroup("Debug")
@export var verbose:bool = false

var anim_scale:float = NAN : set = set_anim_scale


func _ready()-> void:
	if can_cancel: 
		%CancelButton.pressed.connect(_on_no_pressed)
	else:
		%CancelButton.hide()
	if can_accept: 
		%ConfirmButton.pressed.connect(_on_yes_pressed)	
	else:
		%ConfirmButton.hide()
		
		
	update_default_info()
	if has_growing_animation():
		pivot_offset = get_rect().size*0.5
		
	state = State.CLOSED
	
	await tree_entered
	set_anchors_preset(Control.PRESET_CENTER)
	
	
func p(msg:Variant)-> void:
	if not verbose: return
	print(str(msg))
	
	
func set_anim_scale(new_value:float)-> void:
	var old_value = state
	anim_scale = new_value
	var changed:bool = old_value != new_value
	
	if changed:
		anim_scale = clamp(anim_scale, 0.0, 1.0)
		scale = Vector2.ONE*max(0.001, anim_scale)
		p(scale)
		
	
	
func set_state(new_value:State)-> void:
	var old_value = state
	state = new_value
	var changed:bool = old_value != new_value
	
	if changed:
		match state:
			State.CLOSED:
				if has_fading_animation():
					modulate.a = 0.0
				if has_growing_animation():
					anim_scale = 0
				hide()
					
				_on_finished_closing()
				closed.emit()
				p("Window '%s' was closed" % self.name)
			State.OPENING:
				
				if has_fading_animation(): 	
					modulate.a = 0.0
				if has_growing_animation():
					anim_scale = 0.0
				show()
					
				started_opening.emit()
				if click_sound_on_opening:
					%ButtonClickPlayer.play()
				p("Window '%s' has started opening" % self.name)
			State.OPEN:
				show()
				
				if has_fading_animation():
					modulate.a = 1.0
				if has_growing_animation():
					anim_scale = 1.0
					
				opened.emit()
				p("Window '%s' was opened" % self.name)
			State.CLOSING:
				started_closing.emit()
				if click_sound_on_closing:
					%ButtonClickPlayer.play()
				p("Window '%s' has started closing" % self.name)
				
		update_state(0)
				
	
func set_title(value:String)-> void:
	title = value
	update_default_info()
	
	
func set_text(value:String)-> void:
	text = value
	update_default_info()
	
	
func update_default_info()-> void:
	if not is_node_ready(): return
	if title != "":
		%DefaultTitle.text = tr(title)
	if text != "":
		%DefaultText.text = tr(text)
	
	
func _on_no_pressed()-> void:
	cancel()
	
	
func _on_yes_pressed()-> void:
	accept()
	
	
func accept()-> void:
	result = Results.Yes
	close()
	
	
func cancel()-> void:
	result = Results.No 
	close()
	
	
func open()-> void: 	
	if not is_node_ready():
		WindowsLayer.CurrentLayer.add_window(self)
	
	if visible: return
	
	state = State.OPENING		
	
	#started_opening.emit()
	#show()	
	#opened.emit()
	
	
func is_open()-> bool:
	return state == State.OPEN
	
	
func is_opening()-> bool:
	return state == State.OPENING
	
	
func is_closed()-> bool:
	return state == State.CLOSED
	
	
func is_closing()-> bool:
	return state == State.CLOSING
	
	
func start_opening()-> void:
	if fading_time == 0:
		show()
		state = State.OPEN
	else:
		state = State.OPENING		
	
	
func close()-> void:
	state = State.CLOSING
	#hide()
	#closed.emit()
	
	
func _on_finished_closing()-> void:
	hide()
	if destroy_on_close:
		queue_free()
		destroyed.emit()
		
		
func has_fading_animation()-> bool:
	return fading_time != 0
	

func has_growing_animation()-> bool:
	return grow_in_time != 0
	
		
func _input(event: InputEvent) -> void:
	if not visible: return
	
	if ui_actions_enabled:
		if can_accept:
			if event.is_action_pressed(accept_action) :
				get_viewport().set_input_as_handled()
				accept()
				
		if can_cancel:
			if event.is_action_pressed(cancel_action):
				get_viewport().set_input_as_handled()
				cancel()
		else:
			if event.is_action_pressed(cancel_action):
				get_viewport().set_input_as_handled()
				close()
				
				
func _physics_process(delta: float)-> void:
	update_state(delta)
	
	
func update_state(delta:float)-> void:
	var ready_to_change:bool = true
	
	match state:
		State.CLOSING:
			p("Window '%s' closing" % self.name)
			
			if has_fading_animation():
				modulate.a -= delta/fading_time
				if modulate.a > 0:
					ready_to_change = false
					
			if has_growing_animation():			
				anim_scale -= delta/grow_in_time				
				if anim_scale > 0.0:
					ready_to_change = false
					
					
			if ready_to_change:
				state = State.CLOSED
			
		State.OPENING:
			p("Window '%s' opening" % self.name)
						
			if has_fading_animation():
				modulate.a += delta/fading_time
				if modulate.a < 1.0:
					ready_to_change = false
					
			if has_growing_animation():	
				anim_scale += delta/grow_in_time
				if anim_scale < 1.0:
					ready_to_change = false
					
			if ready_to_change:
				state = State.OPEN
