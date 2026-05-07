@tool
extends Polygon2D


@export var sides:int = 5 : set = set_sides
@export var radius:float = 32 : set = set_radius
@export_range(-360, 360, 0.1, "radians_as_degrees") var angle_offset:float = 0 : set = set_angle_offset
#@export_tool_button("Update") var upd = update


func _ready()-> void:
	update()
	

func set_sides(new_value:int)-> void:
	var old_value = sides
	sides = new_value
	var has_changed:bool = old_value != new_value
	if has_changed:
		update()
	

func set_radius(new_value:float)-> void:
	var old_value = radius
	radius = new_value
	var has_changed:bool = old_value != new_value
	if has_changed:
		update()
	

func set_angle_offset(new_value:float)-> void:
	var old_value = angle_offset
	angle_offset = new_value
	var has_changed:bool = old_value != new_value
	if has_changed:
		update()
	
	
func update()-> void:
	if not is_node_ready(): return
	
	var points = []
	var uv_coords: Array[Vector2] = []
	for i in range(sides):
		var angle = i*2*PI/float(sides) + angle_offset
		var p = Vector2.from_angle(angle)*radius
		points.append(p)
		
		# Convert p to UV (mapped from center to middle of image)
		var uv_point = (p / (radius * 2.0)) + Vector2(0.5, 0.5)
		uv_coords.append(uv_point)
		
	polygon = points
	uv = uv_coords
	
	
