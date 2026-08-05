@tool
extends BaseComponent
class_name SpritesheetRunner


var anim_player:AnimationPlayer
	
@export var time:float = 1.0
	
	
func _ready()-> void:
	# No super() call: BaseComponent does its setup from _notification, so it runs
	# whether or not a subclass overrides _ready.
	anim_player = AnimationPlayer.new()
	add_child(anim_player)
	create_animation()


func _on_parent_ready()-> void:
	play_entire_sheet()


func _is_parent_valid()-> bool:
	return get_target() is Sprite2D


func _get_parent_requirement()-> String:
	return "a Sprite2D"


func create_animation()-> void:
	# creates a "normalied" animation, which lasts 1 second
	var t := get_target()

	var sprite_num = t.hframes
	var keys_number = sprite_num
	var time_per_key = 1.0/(keys_number)
	
	var anim_lib = AnimationLibrary.new()
	anim_player.add_animation_library("", anim_lib)
		
	var anim:Animation = Animation.new()
	anim_lib.add_animation(
		"run", anim)
		
	#anim.remove_track(anim.find_track("ExplosionSprite:frame", Animation.TYPE_VALUE))
	var track_index = anim.add_track(Animation.TYPE_VALUE)
	# TODO: this is the target's absolute path at _ready time, so reparenting the
	# sprite afterwards silently stops the animation. Set the AnimationPlayer's
	# root_node to the target and use a relative path instead.
	anim.track_set_path(track_index, "%s:frame" % t.get_path())
	anim.track_insert_key(track_index, 0.0, 0)
	anim.track_insert_key(track_index, 1.0 - time_per_key, sprite_num-1)
	anim.length = 1.0
	
	
func play_entire_sheet(offset_s:float = 0)-> void:
	if offset_s > 0:
		await get_tree().create_timer(offset_s).timeout
	# TODO: a time of 0 makes this INF. Decide what a zero time should mean and
	# either assert against it or handle it here.
	anim_player.speed_scale = 1.0/time
	anim_player.play("run")
