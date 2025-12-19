@tool
extends BaseComponent
class_name SpritesheetRunner


var anim_player:AnimationPlayer
	
@export var time:float = 1.0
	
	
func _ready()-> void:
	super._ready()
	assert(get_parent() is Sprite2D)
	anim_player = AnimationPlayer.new()
	add_child(anim_player)
	create_animation()
	
	
func _on_parent_ready()-> void:
	super._on_parent_ready()
	
	play_entire_sheet()
	
	
func create_animation()-> void:
	# creates a "normalied" animation, which lasts 1 second
	var p = get_parent()
	
	var sprite_num = p.hframes
	var keys_number = sprite_num
	var time_per_key = 1.0/(keys_number)
	
	var anim_lib = AnimationLibrary.new()
	anim_player.add_animation_library("", anim_lib)
		
	var anim:Animation = Animation.new()
	anim_lib.add_animation(
		"run", anim)
		
	#anim.remove_track(anim.find_track("ExplosionSprite:frame", Animation.TYPE_VALUE))
	var track_index = anim.add_track(Animation.TYPE_VALUE)
	anim.track_set_path(track_index, "%s:frame" % p.get_path())
	anim.track_insert_key(track_index, 0.0, 0)
	anim.track_insert_key(track_index, 1.0 - time_per_key, sprite_num-1)
	anim.length = 1.0
	
	
func play_entire_sheet(offset_s:float = 0)-> void:
	if offset_s > 0:
		await get_tree().create_timer(offset_s).timeout
	anim_player.speed_scale = 1.0/time
	anim_player.play("run")
