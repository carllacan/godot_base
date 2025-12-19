extends Button

signal link_opened

# TODO: make into components that can attach to buttons.

# Link the button will open, if nothing else is configured
@export var link:String
# Link the button will open, if this feature is present on the build. If more
# than one of the features used as keys is present, the behaviour is undetermined.
@export var link_if_feature:Dictionary[String, String] = {}
# If one of this features is present, the button will open the APPs store page.
# Ignores everything else
@export var store_id_if_feature:Array[String] = []


func _ready()-> void:
	pressed.connect(_on_pressed)
	
	
func get_link()-> String:
	for feature in link_if_feature.keys():
		if OS.has_feature(feature):
			return link_if_feature[feature]
			
	return link
	
	
func _on_pressed()-> void:
	for feature in store_id_if_feature:
		if OS.has_feature(feature):
			Integration.open_store_page()
			link_opened.emit()
			return
			
	OS.shell_open(get_link()) 
	link_opened.emit()
