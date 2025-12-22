#extends BaseGameWorld
#class_name BaseGridGameWorld
#
#
#@export var cell_size:Vector2 : set = set_cell_size
#@export var min_x:int
#@export var max_x:int
#@export var min_y:int
#@export var max_y:int
#
#
#var max_coords:Vector2 : get = get_max_coords
#var min_coords:Vector2 : get = get_min_coords
#
#
#func _ready()-> void:
	#super._ready()
	#
	#
#func set_cell_size(value:Vector2)-> void:
	#cell_size = value
	#
	#
#func clamp_position(pos:Vector2)-> Vector2:
	#pos = pos.snapped(cell_size)
	#var coords = Vector2i(pos/cell_size)
	#pos.x = clamp(coords.x, min_coords.x, max_coords.x)*cell_size.x
	#pos.y = clamp(coords.y, min_coords.y, max_coords.y)*cell_size.y
		#
	#return pos
	#
	#
##region Coords utils
#
#func get_max_coords()-> Vector2:
	#var max_x_coord = 0
	#var max_y_coord = 0
	#
	#max_x_coord = int(max_x/cell_size.x)-1
	#max_y_coord = int(max_y/cell_size.y)-1
	#
	#return Vector2(max_x_coord, max_y_coord)
	#
	#
#func get_min_coords()-> Vector2:
	#var min_x_coord = 0
	#var min_y_coord = 0
	#
	#min_x_coord = int(min_x/cell_size.x)+1
	#min_y_coord = int(min_y/cell_size.y)+1
	#
	#return Vector2(min_x_coord, min_y_coord)
	#
	#
#func coords_to_pos(coords:Vector2i)-> Vector2:
	#return Vector2(coords.x*cell_size.x, coords.y*cell_size.y)
	#
	#
#func add_element_at_coords(new_element:BaseWorldElement, coords:Vector2i)-> void:
	#add_element_at_pos(new_element, coords_to_pos(coords))
	#
##endregion
#
	#
