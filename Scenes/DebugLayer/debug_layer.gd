extends CanvasLayer
class_name DebugLayer

static var CURRENT:DebugLayer

var lines:Dictionary[Object, Line2D] = {}


func _ready()-> void:
	if not Flags.DEBUG: return
	CURRENT = self
	

func trace_line(from:Vector2, to:Vector2, 
			reference:Object,
			width:float = 1,)-> void:
	if not Flags.DEBUG: return
	
	var line:Line2D
	var is_new:bool = not reference in lines.keys()
	if is_new:
		line = Line2D.new()
	else:
		line = lines[reference]
		
	line.width = width
	line.clear_points()
	line.add_point(from)
	line.add_point(to)
	if is_new:
		add_child(line)
		lines[reference] = line
		
		
func _physics_process(_delta: float) -> void:
	if not Flags.DEBUG: return
	
	# Accessing values keyes by freed objects raises an error, waiting for bug fix
	#for line_owner in lines.keys():
		#if not is_instance_valid(line_owner) or line_owner == null:
			##lines.erase(line_owner)
			##if line_owner != null:
				##lines[line_owner].queue_free()
			#lines[line_owner].queue_free()
