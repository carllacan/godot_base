extends GutTest

## The runner builds its animation in _ready and starts it when the parent
## sprite is ready, so every test gets a real Sprite2D in the tree with the
## component under it. Where the animation has to be at a given point in time
## the tests seek the AnimationPlayer by hand instead of waiting, which keeps
## them exact; the few tests that check the engine really drives the sprite do
## wait, and pick a sheet short enough for the wait to be short too.

const DELTA:float = 0.0001
## The single value track the animation is made of
const TRACK:int = 0


## Builds a sprite with a runner under it and puts it in the tree, which is what
## makes the sprite emit "ready" and the runner start playing.
func _make_runner(hframes:int = 4, time:float = 1.0)-> SpritesheetRunner:
	var sprite := Sprite2D.new()
	sprite.hframes = hframes

	var runner := SpritesheetRunner.new()
	runner.time = time

	sprite.add_child(runner)
	add_child_autofree(sprite)
	return runner


func _animation(runner:SpritesheetRunner)-> Animation:
	return runner.anim_player.get_animation("run")


## The frame the sprite shows at a given point of the animation, in animation
## seconds rather than real ones, so the configured time does not matter here.
func _frame_at(runner:SpritesheetRunner, animation_time:float)-> int:
	runner.anim_player.seek(animation_time, true)
	return (runner.get_parent() as Sprite2D).frame


#region the animation

func test_the_runner_gets_an_animation_player():
	var runner := _make_runner()

	assert_not_null(runner.anim_player)
	assert_eq(runner.anim_player.get_parent(), runner)


func test_the_sheet_is_turned_into_a_run_animation():
	var runner := _make_runner()

	assert_true(runner.anim_player.has_animation("run"))


func test_the_animation_is_normalized_to_one_second():
	var runner := _make_runner()

	assert_almost_eq(_animation(runner).length, 1.0, DELTA)


func test_the_animation_drives_the_parents_frame():
	var runner := _make_runner()
	var sprite := runner.get_parent() as Sprite2D

	assert_eq(
		_animation(runner).track_get_path(TRACK),
		NodePath("%s:frame" % sprite.get_path()))


func test_the_animation_runs_from_the_first_frame_to_the_last():
	var runner := _make_runner(4)
	var anim := _animation(runner)

	assert_eq(anim.track_get_key_count(TRACK), 2)
	assert_eq(anim.track_get_key_value(TRACK, 0), 0)
	assert_eq(anim.track_get_key_value(TRACK, 1), 3)


# The last key is one frame short of the end so the last frame is shown for as
# long as every other one instead of only flashing at the very end.
func test_the_last_frame_is_reached_one_frame_before_the_end():
	var runner := _make_runner(4)
	var anim := _animation(runner)

	assert_almost_eq(anim.track_get_key_time(TRACK, 1), 0.75, DELTA)


func test_a_longer_sheet_leaves_a_shorter_tail():
	var runner := _make_runner(10)
	var anim := _animation(runner)

	assert_almost_eq(anim.track_get_key_time(TRACK, 1), 0.9, DELTA)
	assert_eq(anim.track_get_key_value(TRACK, 1), 9)

#endregion


#region playing

func test_the_sheet_starts_playing_when_the_parent_is_ready():
	var runner := _make_runner()

	assert_true(runner.anim_player.is_playing())
	assert_eq(runner.anim_player.current_animation, "run")


func test_the_animation_is_slowed_down_to_last_the_configured_time():
	var runner := _make_runner(4, 2.0)

	assert_almost_eq(runner.anim_player.speed_scale, 0.5, DELTA)


func test_the_animation_is_sped_up_for_a_short_time():
	var runner := _make_runner(4, 0.25)

	assert_almost_eq(runner.anim_player.speed_scale, 4.0, DELTA)


func test_an_offset_delays_the_start():
	var runner := _make_runner()
	runner.anim_player.stop()

	runner.play_entire_sheet(0.2)

	assert_false(runner.anim_player.is_playing(), "the offset has not passed yet")

	await wait_seconds(0.4)

	assert_true(runner.anim_player.is_playing())

#endregion


#region the frames shown

func test_the_sprite_starts_on_the_first_frame():
	var runner := _make_runner(4)

	assert_eq(_frame_at(runner, 0.0), 0)


func test_the_sprite_ends_on_the_last_frame():
	var runner := _make_runner(4)

	assert_eq(_frame_at(runner, 1.0), 3)


func test_every_frame_gets_the_same_share_of_the_animation():
	var runner := _make_runner(4)

	assert_eq(_frame_at(runner, 0.1), 0)
	assert_eq(_frame_at(runner, 0.3), 1)
	assert_eq(_frame_at(runner, 0.6), 2)
	assert_eq(_frame_at(runner, 0.9), 3)


func test_a_single_frame_sheet_just_shows_its_one_frame():
	var runner := _make_runner(1)

	assert_eq(_frame_at(runner, 0.0), 0)
	assert_eq(_frame_at(runner, 1.0), 0)

#endregion


#region the engine driving it

func test_the_sprite_advances_on_its_own():
	var runner := _make_runner(4, 0.4)
	var sprite := runner.get_parent() as Sprite2D

	await wait_seconds(0.25)

	assert_gt(sprite.frame, 0)


# The sheet is run once rather than looped, so what is left on screen when it is
# over is the last frame of the sheet.
func test_the_sheet_stops_on_the_last_frame_instead_of_looping():
	var runner := _make_runner(4, 0.2)
	var sprite := runner.get_parent() as Sprite2D

	await wait_seconds(0.5)

	assert_false(runner.anim_player.is_playing())
	assert_eq(sprite.frame, 3)

#endregion
