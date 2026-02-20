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
			
			

# Internal graph: maps Node -> {Vector2 direction: Node neighbor}
var _graph: Dictionary = {}

# Elements used to build the graph
var _elements: Array = []

## Minimum dot product to consider a neighbor in a direction (0.3 = ~72 degree cone)
@export var direction_threshold: float = 0.3


func build_graph(elements: Array, visibility_check: Callable = Callable()) -> void:
	_elements = elements
	_graph.clear()

	var visible_elements: Array = []
	for el in elements:
		if visibility_check.is_valid():
			if visibility_check.call(el):
				visible_elements.append(el)
		else:
			visible_elements.append(el)

	var directions := [Vector2.UP, Vector2.DOWN, Vector2.LEFT, Vector2.RIGHT]

	for el in visible_elements:
		var neighbors: Dictionary = {}
		for dir in directions:
			var neighbor = _find_nearest_in_direction(el, dir, visible_elements, visibility_check)
			if neighbor != null:
				neighbors[dir] = neighbor
		_graph[el] = neighbors


func get_neighbor(from: Node, direction: Vector2) -> Node:
	if from == null or not _graph.has(from):
		return null
	var neighbors = _graph[from]
	if neighbors.has(direction):
		return neighbors[direction]
	return null


func get_nearest_to(pos: Vector2, visibility_check: Callable = Callable()) -> Node:
	var best: Node = null
	var best_dist := INF

	for el in _elements:
		if not el is Node2D and not el is Control:
			continue
		if visibility_check.is_valid() and not visibility_check.call(el):
			continue

		var el_pos: Vector2 = _get_element_position(el)
		var dist = el_pos.distance_to(pos)
		if dist < best_dist:
			best_dist = dist
			best = el

	return best


func _find_nearest_in_direction(from: Node, direction: Vector2, elements: Array, visibility_check: Callable) -> Node:
	var best: Node = null
	var best_score := INF

	var from_pos: Vector2 = _get_element_position(from)

	for other in elements:
		if other == from:
			continue
		if visibility_check.is_valid() and not visibility_check.call(other):
			continue

		var other_pos: Vector2 = _get_element_position(other)
		var diff = other_pos - from_pos
		var dot = diff.normalized().dot(direction)

		if dot < direction_threshold:
			continue  # Not in direction cone

		# Score: closer + more aligned = better
		var score = diff.length() / max(dot, 0.01)
		if score < best_score:
			best_score = score
			best = other

	return best


func _get_element_position(el: Node) -> Vector2:
	if el is Node2D:
		return (el as Node2D).global_position
	elif el is Control:
		return (el as Control).global_position
	return Vector2.ZERO
