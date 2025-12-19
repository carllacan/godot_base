extends Node
class_name BaseDebugActions
# TODO: rename to just Debug

const CHECKING_PERIOD_S = 1

# Implements debug features that will only work when the debug flag is set
# It should be added as an atuloaded singleton

var show_debug_elements:bool = false : set = set_show_debug_elements

var update_pending:bool = false
# Check periodically whether elements must be updated, since checking when 
# nodes are added is too expensive.
var timer:Timer


func _ready()-> void:
	get_tree().node_added.connect(_on_node_added_to_tree)
	#timer = Timer.new()
	#timer.wait_time = CHECKING_PERIOD_S
	#timer.timeout.connect(_on_timer_elapsed)
	#timer.autostart = true
	#add_child(timer)
	await get_tree().process_frame
	update_debug_visibility()
	

func set_show_debug_elements(value:bool)-> void:
	show_debug_elements = value
	update_debug_visibility()
	
	
func _on_node_added_to_tree(_node: Node)-> void:
	update_pending = true
	

func update_debug_visibility()-> void:
	var debug_elements = get_tree().get_nodes_in_group(BaseGroups.DEBUG_ELEMENTS)
	for de in debug_elements:
		de.visible = show_debug_elements and Flags.DEBUG
		
	
func _unhandled_input(event: InputEvent) -> void:
	if not Flags.DEBUG: return
	
	if event.is_action_pressed("debug_toggle_info", true):
		show_debug_elements = not show_debug_elements
		get_viewport().set_input_as_handled()
		
		
func _on_timer_elapsed()-> void:
	if update_pending:
		update_pending = false
		update_debug_visibility()
