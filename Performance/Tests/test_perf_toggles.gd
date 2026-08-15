extends GutTest

## The registry and the generic toggles, against a synthetic viewport marked as
## the perf target.

var _sub:SubViewport
var _toggles:BasePerformanceToggles


func before_each()-> void:
	_sub = SubViewport.new()
	_sub.size = Vector2i(64, 64)
	_sub.add_to_group(BaseGroups.PERF_TARGET)
	add_child_autofree(_sub)


func _start()-> BasePerformanceToggles:
	## Registered after the content exists, so target resolution has something
	## to find.
	_toggles = BasePerformanceToggles.new()
	add_child_autofree(_toggles)
	return _toggles


func test_registers_the_generic_toggles()-> void:
	var toggles := _start()
	for id in ["pause", "lights_off", "one_light", "shadows_off", "hide_content",
			"scale_50", "overdraw"]:
		assert_true(toggles.by_id.has(id), "registered '%s'" % id)


func test_slots_zero_to_six_are_taken_and_seven_up_are_free()-> void:
	## Projects get 7-9. If GodotBase ever spills past 6 it silently renumbers
	## every project's shortcuts, so this is worth pinning.
	var toggles := _start()
	var used:Array[int] = []
	for toggle in toggles.toggles:
		if toggle.slot >= 0: used.append(toggle.slot)

	for slot in used:
		assert_between(slot, 0, 6, "GodotBase slot stays within 0-6")
	assert_eq(used.size(), used.duplicate().size(), "no duplicate slots")


func test_duplicate_registration_is_refused()-> void:
	var toggles := _start()
	var before:int = toggles.toggles.size()
	toggles.register("pause", "another pause", func(_t:PerfToggle): pass)
	assert_eq(toggles.toggles.size(), before, "second registration ignored")


func test_lights_off_only_touches_visible_lights()-> void:
	var lit := OmniLight3D.new()
	var dark := OmniLight3D.new()
	dark.visible = false
	_sub.add_child(lit)
	_sub.add_child(dark)

	var toggles := _start()
	toggles.flip_id("lights_off")

	assert_false(lit.visible, "the visible one went off")
	assert_false(dark.visible, "the hidden one is still hidden")

	toggles.flip_id("lights_off")
	assert_true(lit.visible, "restored")
	assert_false(dark.visible, "never turned ON -- it shipped hidden")


func test_one_light_keeps_a_single_directional()-> void:
	var directional := DirectionalLight3D.new()
	var second_directional := DirectionalLight3D.new()
	var omni := OmniLight3D.new()
	_sub.add_child(directional)
	_sub.add_child(second_directional)
	_sub.add_child(omni)

	var toggles := _start()
	toggles.flip_id("one_light")

	assert_true(directional.visible, "first directional kept for legibility")
	assert_false(second_directional.visible)
	assert_false(omni.visible)


func test_shadows_off_only_touches_lights_that_cast()-> void:
	var caster := OmniLight3D.new()
	caster.shadow_enabled = true
	var plain := OmniLight3D.new()
	plain.shadow_enabled = false
	_sub.add_child(caster)
	_sub.add_child(plain)

	var toggles := _start()
	toggles.flip_id("shadows_off")
	assert_false(caster.shadow_enabled)

	toggles.flip_id("shadows_off")
	assert_true(caster.shadow_enabled, "restored")
	assert_false(plain.shadow_enabled, "left alone throughout")


func test_hide_content_spares_cameras_and_lights_and_stops_at_what_it_hides()-> void:
	var content := Node3D.new()
	var below_content := Node3D.new()
	var shipped_hidden := Node3D.new()
	shipped_hidden.visible = false
	var camera := Camera3D.new()
	var light := OmniLight3D.new()

	_sub.add_child(content)
	content.add_child(below_content)
	_sub.add_child(shipped_hidden)
	_sub.add_child(camera)
	_sub.add_child(light)

	var toggles := _start()
	toggles.flip_id("hide_content")

	assert_false(content.visible, "content hidden")
	assert_true(below_content.visible,
		"not touched -- its parent is hidden, so it is not drawing anyway")
	assert_true(camera.visible, "cameras kept")
	assert_true(light.visible, "lights kept, so the cost of lighting stays in")

	toggles.flip_id("hide_content")
	assert_true(content.visible, "restored")
	assert_false(shipped_hidden.visible, "never turned ON")


func test_viewport_toggles_act_on_the_marked_viewport()-> void:
	var toggles := _start()
	assert_eq(toggles.target_viewport(), _sub, "resolved the marked viewport")

	toggles.flip_id("scale_50")
	assert_almost_eq(_sub.scaling_3d_scale, 0.5, 0.001)

	toggles.flip_id("scale_50")
	assert_almost_eq(_sub.scaling_3d_scale, 1.0, 0.001, "restored")


func test_overdraw_also_clears_transparent_bg()-> void:
	## Otherwise the additive overdraw result is read against whatever is
	## layered behind the viewport instead of against black.
	_sub.transparent_bg = true

	var toggles := _start()
	toggles.flip_id("overdraw")

	assert_eq(_sub.debug_draw, Viewport.DEBUG_DRAW_OVERDRAW)
	assert_false(_sub.transparent_bg)

	toggles.flip_id("overdraw")
	assert_eq(_sub.debug_draw, Viewport.DEBUG_DRAW_DISABLED, "restored")
	assert_true(_sub.transparent_bg, "restored")


func test_uncap_never_leaves_the_frame_rate_unlimited()-> void:
	## Uncapped play on a scene near saturation has hard-frozen a machine here.
	## vsync and the cap are one toggle so the dangerous pair cannot be chosen.
	var toggles := _start()
	toggles.flip_id("uncap")

	assert_eq(Engine.max_fps, BasePerformanceToggles.UNCAPPED_FPS)
	assert_gt(Engine.max_fps, 0, "never unlimited")

	toggles.flip_id("uncap")


func test_missing_target_is_reported_on_the_toggle()-> void:
	## No lights in the scene, so lights_off has nothing to do and must say so
	## rather than read as "turning lights off changed nothing".
	var toggles := _start()
	toggles.flip_id("lights_off")

	assert_true(toggles.by_id["lights_off"].missing_targets)


func test_flip_slot_finds_the_toggle_by_shortcut()-> void:
	var toggles := _start()
	toggles.flip_slot(0)
	assert_true(toggles.by_id["pause"].active, "slot 0 is pause")
	toggles.flip_slot(0)
	assert_false(toggles.by_id["pause"].active)
	get_tree().paused = false


func test_reset_all_clears_everything()-> void:
	var light := OmniLight3D.new()
	_sub.add_child(light)

	var toggles := _start()
	toggles.flip_id("lights_off")
	toggles.flip_id("scale_50")

	toggles.reset_all()

	assert_true(light.visible, "light restored")
	assert_almost_eq(_sub.scaling_3d_scale, 1.0, 0.001, "scale restored")
	for toggle in toggles.toggles:
		assert_false(toggle.active, "'%s' is off" % toggle.id)


func test_unknown_toggle_id_is_survivable()-> void:
	var toggles := _start()
	toggles.flip_id("no_such_toggle")
	assert_true(true, "warned rather than crashed")
