extends Resource
class_name RandomSequenceOverride 

@export var element:Resource
@export var overriden_weight:float = INF
@export_range(0, 100, 1, "or_greater") var time_start:float = 0
@export_range(0, 100, 1, "or_greater") var time_end:float = INF
@export var max_uses:int = -1
@export_group("Debug")
@export var force:BaseBuildConfig.ForceActions = BaseBuildConfig.ForceActions.None


func is_active_at(time_s:float)-> bool:		
	if force == BaseBuildConfig.ForceActions.ForceTrue:
		return true
	if force == BaseBuildConfig.ForceActions.ForceFalse:
		return false

	if time_s < time_start:
		return false
		
	if time_s >= time_end:
		return false
		
	return true


func has_limited_uses()-> bool:
	return max_uses > 0
