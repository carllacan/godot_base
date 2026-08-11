extends Node
class_name GraphFocus
## A utility node that builds navigation graphs from element lists
## and provides neighbor queries for d-pad navigation.

## Usage examples:

## To build the graph whenever something changes
##	func rebuild_navigation_graph() -> void:
##		if graph_focus == null:
##			return
##		graph_focus.build_graph(upgrade_controls, func(b): return b.must_be_shown())
##	# If current focus is no longer visible, find nearest or clear
##	if focused_button != null and not focused_button.must_be_shown():
##		var nearest = graph_focus.get_nearest_to(focused_button.global_position, func(b): return b.must_be_shown())
##		if nearest:
##			set_focus(nearest)
##		else:
##			clear_focus()
			
## And then, in input:
##	if direction != Vector2.ZERO:
##		get_viewport().set_input_as_handled()
##		if focused_button == null:
##			# Initial focus: nearest to center (global_position of the tree)
##			set_focus(graph_focus.get_nearest_to(global_position, func(b): return b.must_be_shown()))
##		else:
##			var next = graph_focus.get_neighbor(focused_button, direction)
##			if next:
##				set_focus(next)
			
			

## The only directions a neighbor is ever stored under. Arbitrary directions are
## snapped onto them by [method get_neighbor].
const DIRECTIONS: Array[Vector2] = [Vector2.UP, Vector2.DOWN, Vector2.LEFT, Vector2.RIGHT]

# Internal graph: maps Node -> {Vector2 direction: Node neighbor}
# Its keys are the whole set of navigable elements: nothing outside them can be
# reached by any query.
var _graph: Dictionary = {}

## Minimum dot product to consider a neighbor in a direction (0.3 = ~72 degree cone)
@export var direction_threshold: float = 0.3


## Empties the graph, leaving nothing navigable until the next
## [method build_graph]. For a screen being closed, which has no element list
## left to rebuild from.
func clear() -> void:
	_graph.clear()


## Rebuilds the graph from [param elements]. Anything that fails
## [param visibility_check], has no 2D position, or has been freed is left out
## entirely, and so is unreachable through [method get_neighbor] and
## [method get_nearest_to] alike.
func build_graph(elements: Array, visibility_check: Callable = Callable()) -> void:
	clear()

	var navigable: Array = []
	for i in elements.size():
		var el = elements[i]
		# A freed element has to be caught before anything else touches it: `is`
		# against a previously freed instance raises rather than returning false.
		if not is_instance_valid(el):
			push_warning("GraphFocus: element %d was freed, leaving it out of the graph." % i)
			continue
		if not _has_2d_position(el):
			push_warning(
				"GraphFocus: '%s' is neither a Node2D nor a Control, so it has no position. Leaving it out of the graph." \
				% el
			)
			continue
		if visibility_check.is_valid() and not visibility_check.call(el):
			continue
		navigable.append(el)

	# Positions are read once per element here rather than once per direction per
	# pair. Reading a global transform is the expensive part of a rebuild, and the
	# case this component is for — an upgrade tree — rebuilds on every purchase.
	var positions: Array[Vector2] = []
	for el in navigable:
		positions.append(_get_element_position(el))

	# Each element is scored against every other one once, with all four
	# directions settled in that single visit rather than in a pass each.
	for i in navigable.size():
		var neighbors: Dictionary = {}
		var best_scores: Dictionary = {}

		for j in navigable.size():
			if i == j:
				continue

			var diff: Vector2 = positions[j] - positions[i]
			var distance := diff.length()
			# Two elements on the same spot have no direction between them.
			if is_zero_approx(distance):
				continue
			var heading := diff / distance

			for dir in DIRECTIONS:
				var dot := heading.dot(dir)
				if dot < direction_threshold:
					continue  # Not in direction cone

				# Score: closer + more aligned = better
				var score := distance / maxf(dot, 0.01)
				if score < best_scores.get(dir, INF):
					best_scores[dir] = score
					neighbors[dir] = navigable[j]

		# Elements with no neighbours are keys too: the keys are the set
		# get_nearest_to searches.
		_graph[navigable[i]] = neighbors


## The element reached by moving in [param direction] from [param from].
## [param direction] is snapped to the nearest cardinal, so a raw stick vector
## can be passed straight in; a perfect diagonal resolves horizontally.
func get_neighbor(from: Node, direction: Vector2) -> Node:
	if not is_instance_valid(from) or not _graph.has(from):
		return null

	var cardinal := _snap_to_cardinal(direction)
	if cardinal == Vector2.ZERO:
		return null

	var neighbors = _graph[from]
	if not neighbors.has(cardinal):
		return null

	# An element can be freed between the rebuild and this query, so a stale
	# neighbour is dropped quietly rather than handed back to be focused.
	var neighbor = neighbors[cardinal]
	if not is_instance_valid(neighbor):
		return null
	return neighbor


## The navigable element closest to [param pos]. [param visibility_check] is an
## extra filter on top of the graph, not a replacement for the one used to build
## it: an element left out of the graph is never returned.
func get_nearest_to(pos: Vector2, visibility_check: Callable = Callable()) -> Node:
	var best: Node = null
	var best_dist := INF

	for el in _graph:
		if not is_instance_valid(el):
			continue
		if visibility_check.is_valid() and not visibility_check.call(el):
			continue

		var el_pos: Vector2 = _get_element_position(el)
		var dist = el_pos.distance_to(pos)
		if dist < best_dist:
			best_dist = dist
			best = el

	return best


## The point an element is navigated by. For a [Control] this is the centre of
## its rect rather than [member Control.global_position], which is the top-left
## corner: in a row of controls of differing sizes, corners skew the alignment
## term of the score by half the size difference, so the graph would reason about
## a geometry the player cannot see. A [Node2D] has no equivalent — its origin is
## wherever the scene put it — so it is used as-is.
func _get_element_position(el: Node) -> Vector2:
	if el is Node2D:
		return (el as Node2D).global_position
	elif el is Control:
		return (el as Control).get_global_rect().get_center()
	return Vector2.ZERO


## Whether an element has a position the graph can reason about. Anything else
## would sit at the origin and pull real elements towards a phantom neighbour.
func _has_2d_position(el) -> bool:
	return el is Node2D or el is Control


## Snaps an arbitrary direction to the nearest cardinal. A perfect diagonal has
## no nearest cardinal, so the horizontal axis wins by convention.
func _snap_to_cardinal(direction: Vector2) -> Vector2:
	if direction == Vector2.ZERO:
		return Vector2.ZERO
	if absf(direction.x) >= absf(direction.y):
		return Vector2.RIGHT if direction.x > 0.0 else Vector2.LEFT
	return Vector2.DOWN if direction.y > 0.0 else Vector2.UP
