extends Node
class_name GameResourceSyncer

@export var resource:GameResource
@export var target_property:String = "amount" : set = set_target_property
@export var change_request_signal:String = "amount_change_requested" : set = set_change_request_signal
@export var icon_property:String = "icon" : set = set_icon_property


func _ready()-> void:
	_check_target_property()
	_apply_icon()
	_connect_state_signals()
	_connect_change_request_signal()
	update_info()
	
	
func set_target_property(new_value:String)-> void:
	target_property = new_value
	if not is_node_ready(): return
	_check_target_property()


func set_icon_property(new_value:String)-> void:
	icon_property = new_value
	if not is_node_ready(): return
	_apply_icon()


func set_change_request_signal(new_value:String)-> void:
	if is_node_ready():
		_disconnect_change_request_signal()
	change_request_signal = new_value
	if not is_node_ready(): return
	_connect_change_request_signal()


func _apply_icon()-> void:
	if icon_property == "": return
	if resource == null: return
	var parent:Node = get_parent()
	var has_property:bool = parent.get_property_list().any(func(p:Dictionary)-> bool:
		return p["name"] == icon_property)
	if not has_property:
		push_error("GameResourceSyncer: parent '%s' has no property '%s'" % [parent.name, icon_property])
		return
	parent.set(icon_property, resource.icon)


func _check_target_property()-> void:
	var parent:Node = get_parent()
	if parent == null: return
	var has_property:bool = parent.get_property_list().any(func(p:Dictionary)-> bool:
		return p["name"] == target_property)
	if not has_property:
		push_error("GameResourceSyncer: parent '%s' has no property '%s'" % [parent.name, target_property])


func _connect_state_signals()-> void:
	if Engine.is_editor_hint(): return
	if Current.Save == null:
		push_error("GameResourceSyncer: Current.State is null")
		return
	Current.Save.resource_changed.connect(_on_resource_changed)


func _connect_change_request_signal()-> void:
	if change_request_signal == "": return
	var parent:Node = get_parent()
	if parent == null: return
	if not parent.has_signal(change_request_signal):
		push_error("GameResourceSyncer: parent '%s' has no signal '%s'" % [parent.name, change_request_signal])
		return
	if not parent.is_connected(change_request_signal, _on_change_requested):
		parent.connect(change_request_signal, _on_change_requested)


func _disconnect_change_request_signal()-> void:
	if change_request_signal == "": return
	var parent:Node = get_parent()
	if parent == null: return
	if parent.has_signal(change_request_signal) and parent.is_connected(change_request_signal, _on_change_requested):
		parent.disconnect(change_request_signal, _on_change_requested)


func _on_resource_changed(changed_resource:GameResource, _new_value:float)-> void:
	if changed_resource != resource: return
	update_info()
	
	
func update_info()-> void:
	var a = Current.Save.get_current_resource(resource)
	get_parent().set(target_property, a)


func _on_change_requested(delta:float)-> void:
	if Current.Save == null: return
	if resource == null: return
	var current:float = Current.Save.get_current_resource(resource)
	Current.Save.set_resource(resource, current + delta)
