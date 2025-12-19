extends TextureButton
class_name ArrowButton


#@export var width:float = 50
#@export var height:float = 50


func _ready()-> void:
	var pressed_img = texture_normal.get_image()
	pressed_img.adjust_bcs(0.9, 0.9, 0.9)	
	texture_pressed = ImageTexture.create_from_image(pressed_img)
	
	var hover_img = texture_normal.get_image()
	hover_img.adjust_bcs(0.5, 0.5, 0.5)		
	texture_hover = ImageTexture.create_from_image(hover_img)
	
	var focused_img = texture_normal.get_image()
	focused_img.adjust_bcs(0.9, 0.9, 0.9)		
	texture_focused = null#ImageTexture.create_from_image(focused_img)
	
	var disabled_img = texture_normal.get_image()
	disabled_img.adjust_bcs(0.5, 0.5, 0.5)		
	texture_disabled = ImageTexture.create_from_image(disabled_img)
