extends BaseEffect
class_name FloatingLabel
static var SCENE = load(
	"res://GodotBase/Scenes/FloatingLabel/floating_label.tscn")

# USE:

#	var fl = FloatingLabel.from_text(str(int(arrival_gold)))
#	fl.color = Color.GOLD
#	fl.outline_color = Color.WHITE
#	fl.outline_size = 2
#	## add wherever
	
	
@export var text:String : set = set_text
@export var color:Color = Color.WHITE : set = set_color
@export var outline_color:Color = Color.WHITE : set = set_outline_color
@export var outline_size:float = 0 : set = set_outline_size


static func from_text(shown_text:String)-> FloatingLabel:
	var new_fl = SCENE.instantiate()
	new_fl.text = shown_text
	return new_fl
	
	
func _ready()-> void:
	update_representation()
	
	
func get_label()-> Label:
	assert(is_node_ready())
	return %Label
	
	
func set_text(new_value:String)-> void:
	text = new_value
	update_representation()
	
	
func set_color(new_value:Color)-> void:
	color = new_value
	update_representation()
	
	
func set_outline_color(new_value:Color)-> void:
	outline_color = new_value
	update_representation()
	
	
func set_outline_size(new_value:float)-> void:
	outline_size = new_value
	update_representation()
	
	
func update_representation()-> void:
	if not is_node_ready(): return
	%Label.text = text
	%Label.add_theme_color_override("font_color", color)
	%Label.add_theme_color_override("font_outline_color", outline_color)
	%Label.add_theme_constant_override("outline_size", outline_size)
	
