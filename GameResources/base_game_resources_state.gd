@tool
extends Resource
class_name BaseGameResourcesState

## A wallet: how much of each GameResource is held, how much has been collected
## over the wallet's lifetime, and which kinds the player has been shown.
##
## A game can hold several — a roguelike keeps one for the run and one for the
## save, with the same resource at a different amount in each. Games needing only
## one use BaseGameState's forwarding methods and never touch this class.
##
## Nothing here saves. The wallet announces what changed and leaves persisting it
## to whoever holds it.


signal resources_changed
signal resource_changed(resource:GameResource, new_value:float)
signal resource_revealed(resource:GameResource)

## Current amount of resources available to the player
@export var current_resources:Dictionary[GameResource, float] = {}
## Resources of each kind collected over this wallet's lifetime. Never goes down:
## spending reduces current_resources and leaves this alone.
@export var total_collected_resources:Dictionary[GameResource, float] = {}
## Which resources have been revealed to the player so far
@export var revealed_resources:Array[GameResource] = []
var verbose:bool = false


func _init()-> void:
	current_resources = {}
	revealed_resources = []
	total_collected_resources = {}


func p(text:String)-> void:
	if not verbose: return
	print("BaseGameResourcesState: %s" % text)


func initialize()-> void:
	current_resources.clear()
	revealed_resources.clear()
	total_collected_resources.clear()


## To be called just before the game starts.
func on_load()-> void:
	# Ensure total_collected_resources is at least coherent. Manually created
	# saves might leave it empty while having positive values in
	# current_resources.
	for r in current_resources.keys():
		var t = total_collected_resources.get(r, 0)
		if t < current_resources[r]:
			total_collected_resources[r] = current_resources[r]


#region Reading

func get_current_resource(res:GameResource)-> float:
	return current_resources.get(res, 0)


func get_total_collected_resource(res:GameResource)-> float:
	return total_collected_resources.get(res, 0)


func is_resource_revealed(res:GameResource)-> bool:
	if res in revealed_resources:
		p("%s IS revealed" % res.dname)
		return true
	else:
		return false


# this needs to be typed with GameResource, otherwise it conflicts when you
# use prices typed with GameResource
func can_afford(price:Dictionary[GameResource, float])-> bool:
	if BuildConfig.Default.blank_check:
		#push_warning("Omitting can_afford checks because blank_check is active")
		return true

	for c in price.keys():
		if get_current_resource(c) < price[c]:
			return false

	return true

#endregion Reading


#region Writing

func reveal_resource(resource:GameResource)-> void:
	if not resource in current_resources.keys():
		set_resource(resource, 0)
	revealed_resources.append(resource)
	resource_revealed.emit(resource)
	p("%s revealed" % resource.dname)


func set_resource(resource:GameResource, value:float)-> void:
	var old_value:float = current_resources.get(resource, 0.0)
	current_resources[resource] = value

	if value > 0 and resource not in revealed_resources:
		reveal_resource(resource)

	if old_value != value:
		resource_changed.emit(resource, value)
		_notify_changed()


func increase_resource(resource:GameResource, amount:float)-> void:
	return increase_resources({resource: amount})


func increase_resources(amount:Dictionary[GameResource, float])-> void:
	var any_changed:bool = false

	for c in amount.keys():
		if amount[c] == 0:
			continue

		if c not in revealed_resources:
			reveal_resource(c)

		if c not in current_resources.keys(): current_resources[c] = 0 # JIC
		current_resources[c] += amount[c]

		if c not in total_collected_resources.keys():
			total_collected_resources[c] = 0
		total_collected_resources[c] += amount[c]

		resource_changed.emit(c, current_resources[c])
		any_changed = true

	if any_changed:
		_notify_changed()


func decrease_resource(resource:GameResource, amount:float)-> void:
	return decrease_resources({resource: amount})


func decrease_resources(amount:Dictionary[GameResource, float])-> void:
	if BuildConfig.Default.blank_check:
		push_warning("Omitting decrease_resources because blank_check is active")
		return

	var any_changed:bool = false

	for c in amount.keys():
		if is_nan(amount[c]): continue
		if amount[c] == 0: continue

		assert(
			get_current_resource(c) >= amount[c],
			"Can't take %s %s from %s" % [amount[c], c.dname, get_current_resource(c)]
		)

		current_resources[c] -= amount[c]

		resource_changed.emit(c, get_current_resource(c))
		any_changed = true

	if any_changed:
		_notify_changed()


## Announces that the wallet moved. Both signals are coalesced to one emission
## per frame, so a burst of writes in a single frame wakes listeners once.
func _notify_changed()-> void:
	SignalManager.emit_this_frame(changed)
	SignalManager.emit_this_frame(resources_changed)

#endregion Writing
