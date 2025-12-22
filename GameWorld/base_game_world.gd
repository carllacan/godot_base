extends Node
class_name BaseGameWorld

var actors:Array[BaseActor] = []



#var round_info:RoundInfo : set = set_round_info


#func set_round_info(new_value:RoundInfo)-> void:
	#round_info = new_value
	
	
var run:GameState : set = set_run
func set_run(new_value:GameState)-> void:
	var old_value = run
	run = new_value
	var changed:bool = new_value != old_value
	
	if changed:
		_on_run_changed(new_value, old_value)
	
	
func _ready()-> void:
	pass
		
		
@warning_ignore("unused_parameter")
func _on_run_changed(new_value:GameState, old_value:GameState)-> void:
	return
	
	
#region Actors

func clear_actors()-> void:
	for actor in actors.duplicate():
		remove_actor(actor)
	actors.clear()
	
	
func add_actor(new_actor:BaseActor)-> void:
	actors.append(new_actor)
	
	new_actor.run = run
	new_actor.effect_dropped.connect(_on_actor_effect_dropped.bind(new_actor))
	new_actor.effect_emitted.connect(_on_actor_effect_emitted.bind(new_actor))
	new_actor.dropped.connect(_on_actor_dropped.bind(new_actor))
	new_actor.destroyed.connect(_on_actor_destroyed.bind(new_actor))
	%Actors.add_child(new_actor)
	
	
func remove_actor(target:Actor)-> void:	
	%Actors.remove_child(target)
	actors.erase(target)
	target.queue_free()
	#print("Actor %s queued for freeing" % target)
	
	
func _on_actor_effect_dropped(effect:BaseEffect, actor:BaseActor)-> void:
	_on_actor_effect_emitted(effect, actor.global_position, actor)
	
		
func _on_actor_effect_emitted(
	effect:BaseEffect, global_position:Vector2, _actor:BaseActor
	)-> void:	
	effect.global_position = global_position
	add_child(effect)
	await effect.finished
	effect.queue_free()
	
	
func _on_actor_dropped(what:BaseActor, _actor:BaseActor)-> void:
	add_actor(what)
	
	
func _on_actor_destroyed(target:BaseActor)-> void:
	remove_actor(target)
	
#endregion Actors
