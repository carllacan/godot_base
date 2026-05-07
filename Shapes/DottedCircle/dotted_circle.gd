extends Node2D

@export var dash_color: Color = Color.WHITE
@export var radius: float = 64.0 : set = set_radius
@export var width: float = 6.0 : set = set_width
@export var dash_length: float = 12.0
@export var gap_length: float = 8.0

# Seconds for a full cycle rotation of the dash pattern
@export var period_s: float = 2.0

@onready var sprite: Sprite2D = %Sprite

var _mat: ShaderMaterial
var _time := 0.0

func _ready():
	_mat = sprite.material as ShaderMaterial
	update_representation()
	

func set_radius(new_value:float)-> void:
	radius = new_value
	update_representation()
	
	
func set_width(new_value:float)-> void:
	width = new_value
	update_representation()
	

func update_representation():
	if not is_node_ready(): return
	
	var grad = sprite.texture as GradientTexture2D
	grad.width = radius*2 + width
	grad.height = radius*2 + width

	_mat.set_shader_parameter("dash_color", dash_color)
	_mat.set_shader_parameter("radius", radius)
	_mat.set_shader_parameter("width", width)
	_mat.set_shader_parameter("dash_length", dash_length)
	_mat.set_shader_parameter("gap_length", gap_length)

	
func _physics_process(delta):
	if period_s > 0.0:
		_time += delta
		var off := fmod(_time / period_s, 1.0)
		_mat.set_shader_parameter("offset", off)
