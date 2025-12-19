extends RigidBody2D
class_name BaseActor


@warning_ignore("unused_signal")
signal effect_dropped(effect:BaseEffect)
@warning_ignore("unused_signal")
signal effect_emitted(effect:BaseEffect, global_pos:Vector2)
signal dropped(what)
signal destruction_started
signal destroyed


var being_destroyed:bool = false

func play_destruction_animation(_mode:String = "")-> void:
	return 
	

func destroy(mode:String = "")-> void:
	being_destroyed = true
	destruction_started.emit()
	@warning_ignore("redundant_await")
	await play_destruction_animation(mode)
	being_destroyed = false
	destroyed.emit()
	
	
func drop(what)-> void:
	dropped.emit(what)
