@tool
extends GradientTexture2D
class_name CircularTexture


@export var fill_color:Color = Color.WHITE : set = set_fill_color
@export var radius:float = 32 : set = set_radius
@export_tool_button("Update") var mk = update


func _draw(to_canvas_item: RID, pos: Vector2, modulate: Color, transpose: bool) -> void:
	(self as Texture2D)._draw(to_canvas_item, pos, modulate, transpose)
	update()
	
	
func set_fill_color(new_value:Color)-> void:
	fill_color = new_value
	update()


func set_radius(new_value:float)-> void:
	radius = new_value
	update()
	
	
func update()-> void:
	gradient = Gradient.new()
	gradient.colors = [fill_color, Color.TRANSPARENT]
	gradient.offsets = [sqrt(2)/2, sqrt(2)/2]
	
	fill = GradientTexture2D.FILL_RADIAL
	fill_from = Vector2.ONE*0.5
	fill_to = Vector2.ONE
	
	width = int(radius)
	height = int(radius)
	
	emit_changed()
