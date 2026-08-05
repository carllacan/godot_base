extends GutTest

## GraphFocus is a plain utility node: it hooks into nothing and reacts to
## nothing, so every test builds a graph by hand and asks it questions.
##
## The elements are bare Controls placed at known positions and put in the tree,
## because the graph is built from global_position and a Control outside the
## tree has no global transform. They are laid out on a coarse grid so the
## expected neighbour is obvious from the coordinates alone.


var _focus:GraphFocus
var _elements:Node


func before_each()-> void:
	_elements = add_child_autofree(Node.new())
	_focus = add_child_autofree(GraphFocus.new())


## An element of the graph: a Control at a known position, in the tree
func _at(x:float, y:float)-> Control:
	var control := Control.new()
	control.position = Vector2(x, y)
	_elements.add_child(control)
	return control


## A visibility check that accepts everything except the given elements
func _hiding(hidden:Array)-> Callable:
	return func(el): return not hidden.has(el)


#region build_graph

func test_an_element_finds_a_neighbour_in_every_direction():
	var center := _at(100, 100)
	var above := _at(100, 0)
	var below := _at(100, 200)
	var left := _at(0, 100)
	var right := _at(200, 100)

	_focus.build_graph([center, above, below, left, right])

	assert_eq(_focus.get_neighbor(center, Vector2.UP), above)
	assert_eq(_focus.get_neighbor(center, Vector2.DOWN), below)
	assert_eq(_focus.get_neighbor(center, Vector2.LEFT), left)
	assert_eq(_focus.get_neighbor(center, Vector2.RIGHT), right)


func test_every_element_gets_its_own_neighbours():
	var a := _at(0, 0)
	var b := _at(100, 0)
	var c := _at(200, 0)

	_focus.build_graph([a, b, c])

	assert_eq(_focus.get_neighbor(b, Vector2.LEFT), a)
	assert_eq(_focus.get_neighbor(b, Vector2.RIGHT), c)


func test_an_element_on_its_own_has_no_neighbours():
	var only := _at(0, 0)

	_focus.build_graph([only])

	assert_null(_focus.get_neighbor(only, Vector2.RIGHT))
	assert_null(_focus.get_neighbor(only, Vector2.LEFT))
	assert_null(_focus.get_neighbor(only, Vector2.UP))
	assert_null(_focus.get_neighbor(only, Vector2.DOWN))


func test_an_empty_element_list_is_harmless():
	_focus.build_graph([])

	assert_null(_focus.get_nearest_to(Vector2.ZERO))


func test_every_element_is_included_without_a_visibility_check():
	var a := _at(0, 0)
	var b := _at(100, 0)

	_focus.build_graph([a, b])

	assert_eq(_focus.get_neighbor(a, Vector2.RIGHT), b)


func test_an_element_that_fails_the_visibility_check_is_skipped_over():
	var a := _at(0, 0)
	var b := _at(100, 0)
	var c := _at(200, 0)

	_focus.build_graph([a, b, c], _hiding([b]))

	assert_eq(_focus.get_neighbor(a, Vector2.RIGHT), c)


func test_an_element_that_fails_the_visibility_check_has_no_neighbours():
	var a := _at(0, 0)
	var b := _at(100, 0)

	_focus.build_graph([a, b], _hiding([b]))

	assert_null(_focus.get_neighbor(b, Vector2.LEFT))


# The graph is a snapshot, so rebuilding it after something is hidden has to
# forget the old links rather than add to them.
func test_rebuilding_replaces_the_old_graph():
	var a := _at(0, 0)
	var b := _at(100, 0)
	_focus.build_graph([a, b])

	_focus.build_graph([a, b], _hiding([b]))

	assert_null(_focus.get_neighbor(a, Vector2.RIGHT))

#endregion


#region get_neighbor

func test_no_neighbour_before_the_graph_is_built():
	var a := _at(0, 0)

	assert_null(_focus.get_neighbor(a, Vector2.RIGHT))


func test_a_null_element_has_no_neighbour():
	_focus.build_graph([_at(0, 0)])

	assert_null(_focus.get_neighbor(null, Vector2.RIGHT))


func test_an_element_outside_the_graph_has_no_neighbour():
	var a := _at(0, 0)
	var stranger := _at(100, 0)

	_focus.build_graph([a])

	assert_null(_focus.get_neighbor(stranger, Vector2.LEFT))


func test_nothing_is_returned_for_a_direction_with_no_neighbour():
	var a := _at(0, 0)
	var b := _at(100, 0)

	_focus.build_graph([a, b])

	assert_null(_focus.get_neighbor(a, Vector2.LEFT))


# Only the four cardinal directions are stored, so a caller feeding a raw stick
# vector straight in gets nothing. Directions have to be snapped first.
func test_a_diagonal_direction_finds_nothing():
	var a := _at(0, 0)
	var b := _at(100, 100)

	_focus.build_graph([a, b])

	assert_null(_focus.get_neighbor(a, Vector2(1, 1).normalized()))

#endregion


#region choosing between candidates

func test_the_closest_of_two_aligned_elements_wins():
	var a := _at(0, 0)
	var near := _at(50, 0)
	var far := _at(100, 0)

	_focus.build_graph([a, far, near])

	assert_eq(_focus.get_neighbor(a, Vector2.RIGHT), near)


# Candidates are scored on distance *and* alignment, so the element the player
# would call "the one to the right" wins over a closer one sitting off-axis.
func test_an_aligned_element_beats_a_closer_one_off_to_the_side():
	var a := _at(0, 0)
	var aligned := _at(100, 0)
	var off_axis := _at(30, 60)  # 67px away, against the aligned one's 100px

	_focus.build_graph([a, aligned, off_axis])

	assert_eq(_focus.get_neighbor(a, Vector2.RIGHT), aligned)


func test_an_element_straight_to_the_side_is_not_in_the_way():
	var a := _at(0, 0)
	var below := _at(0, 100)

	_focus.build_graph([a, below])

	assert_null(_focus.get_neighbor(a, Vector2.RIGHT))


# The default cone is wide enough that a corner element is reachable both
# sideways and downwards, which is what keeps sparse layouts navigable.
func test_a_diagonal_element_is_a_neighbour_in_both_directions():
	var a := _at(0, 0)
	var corner := _at(100, 100)

	_focus.build_graph([a, corner])

	assert_eq(_focus.get_neighbor(a, Vector2.RIGHT), corner)
	assert_eq(_focus.get_neighbor(a, Vector2.DOWN), corner)


func test_raising_the_direction_threshold_narrows_the_cone():
	var a := _at(0, 0)
	var corner := _at(100, 100)
	_focus.direction_threshold = 0.9  # a corner element is only 0.707 aligned

	_focus.build_graph([a, corner])

	assert_null(_focus.get_neighbor(a, Vector2.RIGHT))


# Two elements on the same spot have no direction between them, so one stacked
# on top of another can never be reached by moving.
func test_an_element_on_the_same_spot_is_never_a_neighbour():
	var a := _at(0, 0)
	var stacked := _at(0, 0)

	_focus.build_graph([a, stacked])

	assert_null(_focus.get_neighbor(a, Vector2.RIGHT))
	assert_null(_focus.get_neighbor(a, Vector2.DOWN))

#endregion


#region get_nearest_to

func test_the_nearest_element_to_a_point_is_returned():
	var near := _at(10, 0)
	var far := _at(500, 0)

	_focus.build_graph([far, near])

	assert_eq(_focus.get_nearest_to(Vector2.ZERO), near)


func test_nothing_is_nearest_before_the_graph_is_built():
	_at(10, 0)

	assert_null(_focus.get_nearest_to(Vector2.ZERO))


func test_the_nearest_element_respects_the_visibility_check():
	var near := _at(10, 0)
	var far := _at(500, 0)

	_focus.build_graph([near, far])

	assert_eq(_focus.get_nearest_to(Vector2.ZERO, _hiding([near])), far)


func test_nothing_is_nearest_when_every_element_is_filtered_out():
	var a := _at(10, 0)

	_focus.build_graph([a])

	assert_null(_focus.get_nearest_to(Vector2.ZERO, _hiding([a])))


# The search runs over the whole element list, not over the graph, so an element
# left out of the graph is still a candidate here. Callers have to pass the same
# visibility check to both calls or they can land the focus on a hidden element.
func test_the_search_covers_elements_that_were_left_out_of_the_graph():
	var hidden := _at(10, 0)
	var shown := _at(500, 0)

	_focus.build_graph([hidden, shown], _hiding([hidden]))

	assert_eq(_focus.get_nearest_to(Vector2.ZERO), hidden)


func test_elements_without_a_position_are_ignored():
	var placeless:Node = autofree(Node.new())
	var control := _at(500, 0)

	_focus.build_graph([placeless, control])

	assert_eq(_focus.get_nearest_to(Vector2.ZERO), control)


func test_node2d_elements_are_placed_by_their_global_position():
	var sprite := Node2D.new()
	sprite.position = Vector2(10, 0)
	_elements.add_child(sprite)
	var control := _at(500, 0)

	_focus.build_graph([sprite, control])

	assert_eq(_focus.get_nearest_to(Vector2.ZERO), sprite)

#endregion
