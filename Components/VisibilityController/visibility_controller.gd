@tool
extends BaseComponent
class_name VisibilityController

### This node will make its parent control become a setting controller

# TODO: make it into a Component-derived class that listens to Condition nodes

@export var hide_in_web:bool = false
@export var hide_in_non_web:bool = false
@export var hide_in_full:bool = false
@export var hide_in_kbm:bool = false
@export var hide_in_joypad:bool = false


@export var hide_if_settings:Dictionary[SettingInfo, Variant] = {}

@export var show_when_focused:Array[Control] = []
@export var show_when_hovered:Array[Control] = []

@export var force_hide:bool = false

# Whether the control in "show_when_hovered" is hovered right now
var target_hovered:bool = false
# For how much time the parent should be force-shown
var force_show_time_ms:float = NAN


func _ready()-> void:
	# Settings and InputManager are autoloads, so they do not exist at edit time.
	if Engine.is_editor_hint(): return

	process_mode = Node.PROCESS_MODE_ALWAYS
	
	if not hide_if_settings.is_empty():
		Settings.setting_changed.connect(func(_a, _b): update_parent())
	if hide_in_kbm or hide_in_joypad:
		InputManager.type_changed.connect(func(_a): update_parent())
		
	for c in show_when_hovered:
		c.mouse_entered.connect(_on_mouse_entered_target_control)
		c.mouse_exited.connect(_on_mouse_exited_target_control)
	
	
	
func _on_parent_ready()-> void:
	update_parent()
	
		
func _on_mouse_entered_target_control()-> void:
	target_hovered = true
	update_parent()
	
	
func _on_mouse_exited_target_control()-> void:
	target_hovered = false
	update_parent()
		
		
func update_parent()-> void:
	# This writes to the parent's 'visible', which the editor would serialize into
	# the scene. Hiding nodes at edit time must never be a side effect of opening
	# a scene, so this stays inert until the game runs.
	if Engine.is_editor_hint(): return

	var parent = get_target()
	
	var must_show_parent := true
	
	if Flags.WEB and hide_in_web:
		must_show_parent = false
		p("Hiding %s because of WEB flag", [get_target().name])
	
	if not Flags.WEB and hide_in_non_web:
		must_show_parent = false
		p("Hiding %s because no WEB flag", [get_target().name])
		
	if not Flags.DEMO and hide_in_full:
		must_show_parent = false
		p("Hiding %s because of DEMO flag", [get_target().name])
		
	for setting in hide_if_settings:
		var current_val = Settings.get_setting_value(setting)
		var target_val = hide_if_settings[setting]
		
		if target_val == current_val:
			must_show_parent = false
			p("Setting '%s' meets condition, hiding the target of '%s'",
				[setting.name, self.name])
				
	if hide_in_joypad and InputManager.is_joypad():
		must_show_parent = false
		p("Hiding %s because of JOYPAD", [get_target().name])
		
	if hide_in_kbm and InputManager.is_kbm():
		must_show_parent = false
		p("Hiding %s because of KBM", [get_target().name])
				
	if not target_hovered and not show_when_hovered.is_empty():
		must_show_parent = false
		p("Hiding %s because no target is hovered", [get_target().name])
				
	if not is_target_focused() and not show_when_focused.is_empty():
		must_show_parent = false
		p("Hiding %s because no target is focused", [get_target().name])
		
			
	if force_hide:
		must_show_parent = false
		p("Hiding %s just becase", [get_target().name])
				
	if not is_nan(force_show_time_ms) and force_show_time_ms > 0:
		must_show_parent = true
		p("Showing %s because forced show time", [get_target().name])
				
	parent.visible = must_show_parent
			
			
func _is_parent_valid()-> bool:
	return get_target() is CanvasItem


func force_show_during(time_ms:float)-> void:
	force_show_time_ms = time_ms
	update_parent()
	
	
func is_target_focused()-> bool:
	return show_when_focused.any(func(c): return c.has_focus())
		
			
func _physics_process(delta: float) -> void:	
	if force_show_time_ms > 0:
		force_show_time_ms -= delta
	elif not is_nan(force_show_time_ms):
		force_show_time_ms = NAN
		update_parent()
