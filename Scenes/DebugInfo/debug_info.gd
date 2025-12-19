extends CanvasLayer


func _ready()-> void:
	add_to_group(BaseGroups.DEBUG_ELEMENTS)
	visible = DebugActions.show_debug_elements
	initialize_values()
		
		
func initialize_values()-> void:
	%VersionValue.text = Dist.info.version
	
		
func update_values()-> void:
	%FpsValue.text = "%2.2f" % Engine.get_frames_per_second()
	
	
func _physics_process(_delta: float) -> void:
	if not visible: return
	update_values()
	
