extends GutTest

## The follower only wires itself up when its parent emits ready, so the tests
## build the follower under a parent that is still out of the tree and let
## add_child_autofree() ready the whole thing, which is what a scene does.
## The parent starts at PARENT_SIZE so that a parent that was left alone can be
## told apart from one that was resized to the target.

const PARENT_SIZE:Vector2 = Vector2(10, 10)
const TARGET_SIZE:Vector2 = Vector2(120, 40)


## Builds a follower hanging from the control it resizes, with the target
## already in the tree. The exports are set before the parent enters the tree,
## which is the order a scene loads them in.
func _make_follower(opts:Dictionary = {})-> SizeFollower:
	var target := Control.new()
	target.size = opts.get("target_size", TARGET_SIZE)
	target.visible = opts.get("target_visible", true)
	if opts.get("target_in_tree", true): add_child_autofree(target)
	else: autofree(target)

	var follower := SizeFollower.new()
	if opts.get("with_target", true): follower.control_followed = target
	follower.follow_visibility = opts.get("follow_visibility", true)

	var parent := Control.new()
	parent.size = PARENT_SIZE
	parent.add_child(follower)
	add_child_autofree(parent)
	return follower


func _parent_of(follower:SizeFollower)-> Control:
	return follower.get_parent()


func _target_of(follower:SizeFollower)-> Control:
	return follower.control_followed


#region setting up

func test_the_parent_takes_the_targets_size_when_it_is_ready():
	var follower := _make_follower()

	assert_eq(_parent_of(follower).size, TARGET_SIZE)


func test_the_targets_size_becomes_the_parents_minimum_size():
	var follower := _make_follower()

	assert_eq(_parent_of(follower).custom_minimum_size, TARGET_SIZE)


func test_a_follower_without_a_target_leaves_its_parent_alone():
	var follower := _make_follower({"with_target": false})

	assert_eq(_parent_of(follower).size, PARENT_SIZE)
	assert_eq(_parent_of(follower).custom_minimum_size, Vector2.ZERO)


# The follower hooks itself up when its parent emits ready, and a parent that
# is already in the tree has emitted it long ago, so a follower added by hand
# at runtime never follows anything.
func test_a_follower_added_to_a_parent_that_is_already_ready_does_nothing():
	var target:Control = add_child_autofree(Control.new())
	target.size = TARGET_SIZE
	var parent:Control = add_child_autofree(Control.new())
	parent.size = PARENT_SIZE

	var follower := SizeFollower.new()
	follower.control_followed = target
	parent.add_child(follower)

	assert_eq(parent.size, PARENT_SIZE)


# The target is read once, when the parent readies, so setting it afterwards is
# too late: the follower is not listening to it and never resizes the parent.
func test_a_target_set_after_the_parent_is_ready_is_ignored():
	var follower := _make_follower({"with_target": false})
	var target:Control = add_child_autofree(Control.new())
	target.size = TARGET_SIZE

	follower.control_followed = target
	target.size = Vector2(200, 60)

	assert_eq(_parent_of(follower).size, PARENT_SIZE)

#endregion


#region following the size

func test_the_parent_grows_with_the_target():
	var follower := _make_follower()

	_target_of(follower).size = Vector2(200, 60)

	assert_eq(_parent_of(follower).size, Vector2(200, 60))
	assert_eq(_parent_of(follower).custom_minimum_size, Vector2(200, 60))


# The minimum size is lowered before the size is, so the parent is free to
# shrink below the size it was following before.
func test_the_parent_shrinks_with_the_target():
	var follower := _make_follower()

	_target_of(follower).size = Vector2(30, 20)

	assert_eq(_parent_of(follower).size, Vector2(30, 20))
	assert_eq(_parent_of(follower).custom_minimum_size, Vector2(30, 20))


func test_the_parent_follows_a_target_that_enters_the_tree_later():
	var follower := _make_follower({"target_in_tree": false})
	var parent := _parent_of(follower)
	parent.custom_minimum_size = Vector2.ZERO
	parent.size = PARENT_SIZE

	add_child(_target_of(follower))

	assert_eq(parent.size, TARGET_SIZE)


func test_the_size_can_be_followed_by_hand():
	var follower := _make_follower()
	var parent := _parent_of(follower)
	parent.custom_minimum_size = Vector2.ZERO
	parent.size = PARENT_SIZE

	follower.follow_size()

	assert_eq(parent.size, TARGET_SIZE)


# Nothing is in the tree yet, so there is no parent size worth setting and the
# follower has to keep its hands off it
func test_a_follower_out_of_the_tree_leaves_its_parent_alone():
	var parent:Control = autofree(Control.new())
	parent.size = PARENT_SIZE
	var follower:SizeFollower = SizeFollower.new()
	parent.add_child(follower)

	follower.follow_size()

	assert_eq(parent.size, PARENT_SIZE)

#endregion


#region following the visibility

func test_the_parent_hides_with_the_target():
	var follower := _make_follower()

	_target_of(follower).hide()

	assert_false(_parent_of(follower).visible)


func test_the_parent_shows_with_the_target():
	var follower := _make_follower({"target_visible": false})

	_target_of(follower).show()

	assert_true(_parent_of(follower).visible)


func test_the_parent_starts_hidden_behind_a_hidden_target():
	var follower := _make_follower({"target_visible": false})

	assert_false(_parent_of(follower).visible)


func test_the_parent_keeps_its_own_visibility_when_the_visibility_is_not_followed():
	var follower := _make_follower({"follow_visibility": false})

	_target_of(follower).hide()

	assert_true(_parent_of(follower).visible)


func test_a_hidden_target_is_still_followed_in_size():
	var follower := _make_follower({"target_visible": false})

	_target_of(follower).size = Vector2(200, 60)

	assert_eq(_parent_of(follower).size, Vector2(200, 60))

#endregion
