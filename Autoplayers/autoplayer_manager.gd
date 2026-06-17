extends Node


var player:BaseAutoplayer


func _ready()-> void:
	if BuildConfig.Default.autoplayer != null:
		player = BuildConfig.Default.autoplayer
	
	
# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	if not is_node_ready(): return
	if player == null: return
	
	player.act(delta)
