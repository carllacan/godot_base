@tool
extends Resource
class_name BaseGameResourcesState

## A wallet: how much of each GameResource is held, how much has been collected
## over the wallet's lifetime, and which kinds the player has been shown.
##
## A game can hold several — a roguelike keeps one for the run and one for the
## save, with the same resource at a different amount in each. Reached through
## the state that holds it, as Current.Save.resources.
##
## The methods take a GameResource but the dictionaries are keyed by its id, so
## that moving or renaming a resource's .tres does not orphan what the player is
## holding, and so a save can be read back — by a test, a tool or an analysis
## pipeline — without loading the resources it names.
##
## Nothing here saves. The wallet announces what changed and leaves persisting it
## to whoever holds it.


signal resources_changed
signal resource_changed(resource:GameResource, new_value:float)
## Emitted for each resource an increase_resources() call actually moved, with
## the amount it went up by rather than the total it reached. This is the one
## place the size of a gain is known, so a game that pays out on income — a
## reveal, a threshold, an animation — hangs off here rather than off
## [signal resource_changed], which only ever carries the new total.
##
## Emitted once the whole call has been applied, so a listener that spends or
## earns in response finds the wallet already settled.
signal resource_increased(resource:GameResource, amount:float)
signal resource_revealed(resource:GameResource)

## Current amount of each resource available to the player, keyed by
## GameResource.id.
@export var current_amounts:Dictionary[String, float] = {}
## How much of each resource has been collected over this wallet's lifetime,
## keyed by GameResource.id. Never goes down: spending reduces current_amounts
## and leaves this alone.
@export var total_collected_amounts:Dictionary[String, float] = {}
## The ids of the resources that have been revealed to the player so far
@export var revealed_ids:Array[String] = []
var verbose:bool = false


func _init()-> void:
	current_amounts = {}
	revealed_ids = []
	total_collected_amounts = {}


func p(text:String)-> void:
	if not verbose: return
	print("BaseGameResourcesState: %s" % text)


func initialize()-> void:
	current_amounts.clear()
	revealed_ids.clear()
	total_collected_amounts.clear()


## To be called just before the game starts.
func on_load()-> void:
	# Ensure total_collected_amounts is at least coherent. Manually created
	# saves might leave it empty while having positive values in
	# current_amounts.
	for id in current_amounts.keys():
		var t = total_collected_amounts.get(id, 0)
		if t < current_amounts[id]:
			total_collected_amounts[id] = current_amounts[id]


#region Reading

func get_current_resource(res:GameResource)-> float:
	return current_amounts.get(res.id, 0)


func get_total_collected_resource(res:GameResource)-> float:
	return total_collected_amounts.get(res.id, 0)


func is_resource_revealed(res:GameResource)-> bool:
	if res.id in revealed_ids:
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
	if resource.id in revealed_ids:
		return
	if not resource.id in current_amounts.keys():
		set_resource(resource, 0)
	revealed_ids.append(resource.id)
	resource_revealed.emit(resource)
	p("%s revealed" % resource.dname)


func set_resource(resource:GameResource, value:float)-> void:
	var old_value:float = current_amounts.get(resource.id, 0.0)
	current_amounts[resource.id] = value

	if value > 0:
		reveal_resource(resource)

	if old_value != value:
		resource_changed.emit(resource, value)
		_notify_changed()


func increase_resource(resource:GameResource, amount:float)-> void:
	return increase_resources({resource: amount})


func increase_resources(amount:Dictionary[GameResource, float])-> void:
	var any_changed:bool = false
	var increased:Array[GameResource] = []

	for c in amount.keys():
		if amount[c] == 0:
			continue

		var key:String = c.id

		reveal_resource(c)

		if key not in current_amounts.keys(): current_amounts[key] = 0 # JIC
		current_amounts[key] += amount[c]

		if key not in total_collected_amounts.keys():
			total_collected_amounts[key] = 0
		total_collected_amounts[key] += amount[c]

		resource_changed.emit(c, current_amounts[key])
		increased.append(c)
		any_changed = true

	# After the loop, not inside it: a listener that earns or spends in response
	# would otherwise re-enter this while the rest of `amount` is still unapplied.
	for c in increased:
		resource_increased.emit(c, amount[c])

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

		current_amounts[c.id] -= amount[c]

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
