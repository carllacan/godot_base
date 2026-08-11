extends GutTest

## GraphFocus is a plain utility node: it hooks into nothing and reacts to
## nothing, so every test builds a graph by hand and asks it questions.
##
## The elements are bare Controls placed at known positions and put in the tree,
## because the graph is built from their global transform, which a Control
## outside the tree does not have. They are laid out on a coarse grid so the
## expected neighbour is obvious from the coordinates alone.
##
## Most of them are left at zero size, where the centre of a Control's rect and
## its top-left corner coincide and the grid coordinate is the position either
## way. The tests that care about the difference build their elements with
## [method _rect].


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


## An element with a size, for the cases where the centre of its rect and its
## top-left corner are far enough apart to change the answer. x and y are still
## the corner, the same as _at.
func _rect(x:float, y:float, w:float, h:float)-> Control:
	var control := _at(x, y)
	control.size = Vector2(w, h)
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


# A node that is neither a Node2D nor a Control has no position to navigate by.
# Letting it in would park it at the origin, where it would sit between real
# elements as a neighbour nobody can see.
func test_an_element_without_a_2d_position_is_left_out():
	var placeless:Node = autofree(Node.new())
	var a := _at(0, 0)
	var b := _at(500, 0)

	_focus.build_graph([placeless, a, b])

	assert_eq(_focus.get_neighbor(a, Vector2.RIGHT), b)
	assert_eq(_focus.get_nearest_to(Vector2.ZERO), a)


func test_an_element_without_a_2d_position_is_reported():
	var placeless:Node = autofree(Node.new())

	_focus.build_graph([placeless])

	assert_push_warning("is neither a Node2D nor a Control")


func test_an_element_freed_before_the_build_is_left_out():
	var a := _at(0, 0)
	var gone := _at(100, 0)

	gone.free()
	_focus.build_graph([a, gone])

	assert_null(_focus.get_neighbor(a, Vector2.RIGHT))


func test_clearing_leaves_nothing_navigable():
	var a := _at(0, 0)
	var b := _at(100, 0)
	_focus.build_graph([a, b])

	_focus.clear()

	assert_null(_focus.get_neighbor(a, Vector2.RIGHT))
	assert_null(_focus.get_nearest_to(Vector2.ZERO))


func test_clearing_an_unbuilt_graph_is_harmless():
	_focus.clear()

	assert_null(_focus.get_nearest_to(Vector2.ZERO))


func test_a_cleared_graph_can_be_built_again():
	var a := _at(0, 0)
	var b := _at(100, 0)
	_focus.build_graph([a, b])
	_focus.clear()

	_focus.build_graph([a, b])

	assert_eq(_focus.get_neighbor(a, Vector2.RIGHT), b)


func test_an_element_freed_before_the_build_is_reported():
	var gone := _at(100, 0)

	gone.free()
	_focus.build_graph([gone])

	assert_push_warning("was freed")

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


# Only the four cardinal directions are stored, but the lookup snaps to them, so
# a caller can feed a raw stick vector straight in.
func test_an_off_axis_direction_snaps_to_its_dominant_axis():
	var a := _at(0, 0)
	var right := _at(100, 0)
	var below := _at(0, 100)

	_focus.build_graph([a, right, below])

	assert_eq(_focus.get_neighbor(a, Vector2(0.9, 0.4)), right)
	assert_eq(_focus.get_neighbor(a, Vector2(0.4, 0.9)), below)


# A perfect diagonal has no dominant axis. Something has to win, and it is the
# horizontal one.
func test_a_perfect_diagonal_resolves_horizontally():
	var a := _at(0, 0)
	var right := _at(100, 0)
	var below := _at(0, 100)

	_focus.build_graph([a, right, below])

	assert_eq(_focus.get_neighbor(a, Vector2(1, 1).normalized()), right)


func test_a_short_direction_still_navigates():
	var a := _at(0, 0)
	var right := _at(100, 0)

	_focus.build_graph([a, right])

	assert_eq(_focus.get_neighbor(a, Vector2(0.01, 0)), right)


func test_an_empty_direction_finds_nothing():
	var a := _at(0, 0)
	var right := _at(100, 0)

	_focus.build_graph([a, right])

	assert_null(_focus.get_neighbor(a, Vector2.ZERO))


# An element can be freed between a rebuild and the next input event, and the
# graph still holds the reference. Handing it back would be handing the caller
# something to crash on.
func test_a_freed_neighbour_is_not_returned():
	var a := _at(0, 0)
	var right := _at(100, 0)
	_focus.build_graph([a, right])

	right.free()

	assert_null(_focus.get_neighbor(a, Vector2.RIGHT))


# There is deliberately no test for passing a *freed* element as `from`: the
# `Node` type on the parameter makes the engine reject the call before the body
# runs, with a "previously freed" error no guard here can pre-empt.

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


# Controls are navigated by the centre of their rect, not by their top-left
# corner, so a tall neighbour is reachable sideways: the part of it the player is
# looking at is straight ahead even though its corner is far off the axis.
func test_a_control_is_a_neighbour_by_its_centre_not_its_corner():
	var origin := _rect(0, 0, 20, 20)       # centre (10, 10)
	var tall := _rect(100, -480, 20, 1000)  # centre (110, 20), corner 78° off-axis

	_focus.build_graph([origin, tall])

	assert_eq(_focus.get_neighbor(origin, Vector2.RIGHT), tall)


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


# The search runs over the graph, so an element left out of it is not a
# candidate: focus can never land somewhere the next d-pad press would fall off.
func test_the_search_skips_elements_that_were_left_out_of_the_graph():
	var hidden := _at(10, 0)
	var shown := _at(500, 0)

	_focus.build_graph([hidden, shown], _hiding([hidden]))

	assert_eq(_focus.get_nearest_to(Vector2.ZERO), shown)


func test_the_nearest_element_is_measured_from_its_centre():
	var wide := _rect(0, 0, 400, 20)    # centre (200, 10)
	var small := _rect(250, 0, 20, 20)  # centre (260, 10)

	_focus.build_graph([wide, small])

	# Measured from the corners the small one would win instead: 70px from the
	# point, against the wide one's 180px.
	assert_eq(_focus.get_nearest_to(Vector2(180, 10)), wide)


func test_a_freed_element_is_never_the_nearest():
	var near := _at(10, 0)
	var far := _at(500, 0)
	_focus.build_graph([near, far])

	near.free()

	assert_eq(_focus.get_nearest_to(Vector2.ZERO), far)


# The graph is a snapshot taken at build time. The caller usually passes its own
# live control list, and mutating that afterwards must not change what is
# navigable until the next rebuild.
func test_mutating_the_element_list_after_the_build_changes_nothing():
	var a := _at(0, 0)
	var b := _at(100, 0)
	var elements := [a]
	_focus.build_graph(elements)

	elements.append(b)

	assert_null(_focus.get_neighbor(a, Vector2.RIGHT))
	assert_eq(_focus.get_nearest_to(Vector2(100, 0)), a)


func test_node2d_elements_are_placed_by_their_global_position():
	var sprite := Node2D.new()
	sprite.position = Vector2(10, 0)
	_elements.add_child(sprite)
	var control := _at(500, 0)

	_focus.build_graph([sprite, control])

	assert_eq(_focus.get_nearest_to(Vector2.ZERO), sprite)

#endregion
