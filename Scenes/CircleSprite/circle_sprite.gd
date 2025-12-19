@tool
extends Sprite2D
class_name CircleSprite

const MAX_CIRCLES:int = 10

@export var background_color = Color.TRANSPARENT : set = set_background_color;
@export var mix_color:Color = Color.WHITE : set = set_mix_color
@export_range(0, 1.0) var mix_color_factor:float = 0.0 : set = set_mix_color_factor
@export var size:Vector2 = Vector2.ONE*250 : set = set_size
@export var circles:Array[CircleInfo]
@export var update_frame_interval:int = 1
@export var auto_update:bool = false
@export var update_only_angles:bool = false
# Will disable antialising, independent of graphics quality settings
@export var force_no_antialising:bool = false : set = set_force_no_antialising
@export_tool_button("Update circles") var uc = update_circles_info.bind(true)

var must_update_this_frame:bool = false

var frames_since_last_update:int = 0

@onready var s = material as ShaderMaterial	


func _ready()-> void:
	for circle in circles:
		_on_circle_added(circle)
	update_antialising()
			
	
#region Setgetters

func set_force_no_antialising(value:bool)-> void:
	force_no_antialising = value
	update_antialising()
	
	
func set_background_color(value:Color)-> void:
	background_color = value
	
	s = material as ShaderMaterial
	if s == null: return
	s.set_shader_parameter("background_color", background_color)
	
		
func set_mix_color(value:Color)-> void:
	mix_color = value
	
	s = material as ShaderMaterial
	if s == null: return
	s.set_shader_parameter("mix_color", mix_color)
	
	
func set_mix_color_factor(value:float)-> void:
	mix_color_factor = value
	
	s = material as ShaderMaterial
	if s == null: return
	s.set_shader_parameter("mix_color_factor", mix_color_factor)
		

# TODO: auto set size whenere a new circle is added
func set_size(value:Vector2)-> void:
	size = value
	if texture == null:
		texture = GradientTexture2D.new()
	texture.width = size.x
	texture.height = size.y
	
	
#endregion Setgetters
	
func _on_setting_changed(setting_name:String, _new_value:Variant)-> void:
	if setting_name == "graphics_quality":
		update_antialising()
	
	
#region Circles management
func add_circle(circle:CircleInfo)-> void:
	circles.append(circle)
	_on_circle_added(circle)
	
	
func remove_circle(circle:CircleInfo)-> void:
	circles.erase(circle)
	_on_circle_removed(circle)
	
	
func clear()-> void:
	for circle in circles.duplicate():
		remove_circle(circle)
		
		
func get_circle_by_name(circle_name:String)-> CircleInfo:
	for circle in circles:
		if circle.name == circle_name:
			return circle
			
	# if none matched
	push_warning("Circle '%s' not found in CircleSprite '%s'" % [
		circle_name, self.name
	])
	return null
		
	
func _on_circle_added(circle:CircleInfo)-> void:
	circle.changed.connect(_on_circle_info_changed.bind(circle))	
	update_circles_info()
	
	
func _on_circle_removed(circle:CircleInfo)-> void:
	circle.changed.disconnect(_on_circle_info_changed.bind(circle))	
	
	
func _on_circle_info_changed(_circle:CircleInfo)-> void:
	update_circles_info()
	
	
#endregion Circles management


#region Updates management
func update_circles_info(force:bool = false)-> void:
	#if Engine.is_editor_hint(): print("%s updated" % name)
	
	if force:
		really_update_circles_info()
	else:
		must_update_this_frame = true
	
	
func update_antialising()-> void:
	s = material as ShaderMaterial
	if force_no_antialising:
		s.set_shader_parameter("enable_antialising", false)
	#elif not Engine.is_editor_hint():
		#var aa_setting = Settings.get_setting_value_by_name("graphics_quality") > 1
		#s.set_shader_parameter("enable_antialising", aa_setting)
	else:
		s.set_shader_parameter("enable_antialising", true)
	
	
func really_update_circles_info()-> void:
	if not Engine.is_editor_hint() and circles == null: 
		push_warning("circles was null")
		return
		
	if circles.is_empty():
		push_warning("circles was empty")
		return
		
	if update_only_angles:
		really_update_angles()
		return
		
	if s == null:
		return
	
		
	var enableds = s.get_shader_parameter("enabled")
	
	var angular_widths = s.get_shader_parameter("angular_widths")
	var colors = s.get_shader_parameter("colors")
	var outer_radii = s.get_shader_parameter("outer_radii")
	var widths = s.get_shader_parameter("widths")
	var start_angles = s.get_shader_parameter("start_angles")
	
	var fade_into_colors = s.get_shader_parameter("fade_into_colors")
	var fade_into_factors = s.get_shader_parameter("fade_into_factors")
		
	var fade_from_colors = s.get_shader_parameter("fade_from_colors")
	var fade_from_factors = s.get_shader_parameter("fade_from_factors")
		
	var angular_fade_colors = s.get_shader_parameter("angular_fade_colors")
	var angular_fade_factors = s.get_shader_parameter("angular_fade_factors")
	
	var waves_enabled = s.get_shader_parameter("waves_enabled")
	var waves_colors = s.get_shader_parameter("waves_colors")
	var waves_periods = s.get_shader_parameter("waves_periods")
	var waves_lengths = s.get_shader_parameter("waves_lengths")
	var waves_factor_exponents = s.get_shader_parameter("waves_factor_exponents")
	
	var mix_colors = s.get_shader_parameter("mix_colors")
	var mix_color_factors = s.get_shader_parameter("mix_color_factors")
			
	# Disable all circles by default
	for i in range(MAX_CIRCLES):
		enableds[i] = 0
		
	var max_radius = 0
	for i in range(0, len(circles)):
		var circle = circles[i]
		
		if circle == null:
			push_warning("a circle was empty")
			continue
		
		enableds[i] = 1 if circle.enabled else 0
				
		if circle.enabled:
			max_radius = max(max_radius, circle.outer_radius*circle.radius_factor)
		
		colors[i] = circle.color
		outer_radii[i] = circle.outer_radius*circle.radius_factor
		widths[i] = circle.width
		angular_widths[i] = circle.angular_width
		start_angles[i] = circle.start_angle
		
		
		fade_into_colors[i] = circle.fade_into_color
		fade_into_factors[i] = circle.fade_into_factor
		
		fade_from_colors[i] = circle.fade_from_color
		fade_from_factors[i] = circle.fade_from_factor
		
		angular_fade_colors[i] = circle.angular_fade_color
		angular_fade_factors[i] = circle.angular_fade_factor
		
		waves_enabled[i] = 1 if circle.waves_enabled else 0
		waves_colors[i] = circle.waves_color
		waves_periods[i] = circle.waves_period
		waves_lengths[i] = circle.waves_length
		waves_factor_exponents[i] = circle.waves_factor_exponent
		
		mix_colors[i] = circle.mix_color
		mix_color_factors[i] = circle.mix_color_factor
		
	if 2*max_radius > size.x or 2*max_radius > size.y:
		size = Vector2.ONE*max_radius*2
		
	s.set_shader_parameter("enabled", enableds)
	s.set_shader_parameter("angular_widths", angular_widths)
	s.set_shader_parameter("colors", colors)
	s.set_shader_parameter("outer_radii", outer_radii)
	s.set_shader_parameter("widths", widths)
	s.set_shader_parameter("start_angles", start_angles)
	
	s.set_shader_parameter("fade_into_colors", fade_into_colors)
	s.set_shader_parameter("fade_into_factors", fade_into_factors)
	
	s.set_shader_parameter("fade_from_colors", fade_from_colors)
	s.set_shader_parameter("fade_from_factors", fade_from_factors)
	
	s.set_shader_parameter("angular_fade_colors", angular_fade_colors)
	s.set_shader_parameter("angular_fade_factors", angular_fade_factors)
	
	s.set_shader_parameter("waves_enabled", waves_enabled)
	s.set_shader_parameter("waves_colors", waves_colors)
	s.set_shader_parameter("waves_periods", waves_periods)
	s.set_shader_parameter("waves_lengths", waves_lengths)
	s.set_shader_parameter("waves_factor_exponents", waves_factor_exponents)
	
	s.set_shader_parameter("mix_colors", mix_colors)
	s.set_shader_parameter("mix_color_factors", mix_color_factors)
	
	s.set_shader_parameter("max_amount_of_circles", len(circles))


func really_update_angles()-> void:
	if not Engine.is_editor_hint() and circles == null: 
		push_warning("circles was null")
		return
		
	if circles.is_empty():
		push_warning("circles was empty")
		return
			
	var start_angles = s.get_shader_parameter("start_angles")
						
	for i in range(0, len(circles)):
		var circle = circles[i]
		
		if circle == null:
			push_warning("a circle was empty")
			continue
		
		start_angles[i] = circle.start_angle
		
	s.set_shader_parameter("start_angles", start_angles)
	

#endregion Updates management
	
func _physics_process(_delta: float) -> void:
	frames_since_last_update += 1
	
	if not must_update_this_frame and not auto_update:
		return
		
	if frames_since_last_update < update_frame_interval:
		return
		
	must_update_this_frame = false
	really_update_circles_info()
	frames_since_last_update = 0
