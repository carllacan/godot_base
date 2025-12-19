extends Node
class_name HoverGroup


static var DEFAULT = HoverGroup.new()

var elements_prio:Dictionary[InteractiveNode, int] = {}
var hovered_element:InteractiveNode


func register_element(new_element:InteractiveNode)-> void:
	elements_prio[new_element] = len(elements_prio)
	new_element.mouse_entered.connect(_on_mouse_entered_element)
	new_element.mouse_exited.connect(_on_mouse_exited_element)
	
	
func _on_mouse_entered_element(element:InteractiveNode)-> void:
	element.mouse_inside = true
	
	
func _on_mouse_exited_element(element:InteractiveNode)-> void:
	element.mouse_inside = false
	
	
func has_prio_over_hovered(element:InteractiveNode)-> bool:
	if has_prio(element, hovered_element):
		return true
	else:
		return false
	
	
#func change_hovered_element(new_hovered:InteractiveNode)-> void:
	#if hovered_element != null:
		#hovered_element.mouse_inside
	
	
func get_prio(element:InteractiveNode)-> int:
	return elements_prio[element]
	
	
func has_prio(this:InteractiveNode, over_this:InteractiveNode)-> bool:
	if get_prio(this) > get_prio(over_this):
		return true
	else:
		return false
