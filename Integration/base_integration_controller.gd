extends Node
class_name BaseIntegrationController
 
# Manages the interaction between the game and the platform it runs on, be it
# Steam or anything else.

func _ready()-> void:
	initialize()
	
	
func _process(_delta: float) -> void:
	pass
	
	
func initialize()-> void:	
	pass
		

func mark_achievement_as_completed(_ach_name:String)-> void:
	pass
	
	
# Tries to open the store page for a given ID, or this app's page if none is given.
func open_store_page(_store_id:Variant = null)-> void:
	pass
	
	
# Gets the language set in the external platform, or an empty string if none.
func get_current_language()-> String:
	return ""
