extends GutTest


#region piecewise_linear

func test_single_segment_no_threshold_crossed():
	var thresholds:Array[float] = [10.0]
	var slopes:Array[float] = [2.0, 5.0]

	var result := Utils.piecewise_linear(5.0, thresholds, slopes)

	assert_eq(result, 2.0 * 5.0)


func test_second_segment_after_threshold():
	var thresholds:Array[float] = [10.0]
	var slopes:Array[float] = [2.0, 5.0]

	var result := Utils.piecewise_linear(15.0, thresholds, slopes)

	# Offset at threshold: 10 * 2 = 20
	# Result: 20 + 5*5 = 45
	assert_eq(result, 45.0)


func test_multiple_thresholds_middle_segment():
	var thresholds:Array[float] = [10.0, 20.0]
	var slopes:Array[float] = [1.0, 2.0, 3.0]

	var result := Utils.piecewise_linear(15.0, thresholds, slopes)

	# First segment offset: 10 * 1 = 10
	# Result: 10 + 5*2 = 20
	assert_eq(result, 20.0)


func test_continuity_at_threshold():
	var thresholds:Array[float] = [10.0]
	var slopes:Array[float] = [2.0, 5.0]

	var left := Utils.piecewise_linear(10.0, thresholds, slopes)
	var right := Utils.piecewise_linear(10.0001, thresholds, slopes)

	assert_almost_eq(left, right, 0.01)


func test_exactly_at_threshold_uses_previous_piece():
	var thresholds:Array[float] = [10.0]
	var slopes:Array[float] = [2.0, 5.0]

	var result := Utils.piecewise_linear(10.0, thresholds, slopes)

	assert_eq(result, 20.0)


func test_negative_x_uses_first_slope():
	var thresholds:Array[float] = [10.0]
	var slopes:Array[float] = [2.0, 5.0]

	var result := Utils.piecewise_linear(-5.0, thresholds, slopes)

	# Negative X is not supported
	assert_eq(result, 0.0)

#endregion


#region unique

func test_unique_removes_duplicates():
	var result := Utils.unique([1, 2, 2, 3, 3, 3])
	assert_eq(result, [1, 2, 3])


func test_unique_preserves_order():
	var result := Utils.unique([3, 1, 2, 1, 3])
	assert_eq(result, [3, 1, 2])


func test_unique_empty_array():
	var result := Utils.unique([])
	assert_eq(result, [])


func test_unique_no_duplicates_unchanged():
	var result := Utils.unique([1, 2, 3])
	assert_eq(result, [1, 2, 3])


func test_unique_works_with_strings():
	var result := Utils.unique(["a", "b", "a", "c"])
	assert_eq(result, ["a", "b", "c"])

#endregion


#region sum_array

func test_sum_array_integers():
	var result := Utils.sum_array([1, 2, 3, 4])
	assert_eq(result, 10.0)


func test_sum_array_floats():
	var result := Utils.sum_array([1.5, 2.5, 3.0])
	assert_almost_eq(result, 7.0, 0.001)


func test_sum_array_empty():
	var result := Utils.sum_array([])
	assert_eq(result, 0.0)


func test_sum_array_single_element():
	var result := Utils.sum_array([42])
	assert_eq(result, 42.0)


func test_sum_array_mixed_int_float():
	var result := Utils.sum_array([1, 2.5, 3])
	assert_almost_eq(result, 6.5, 0.001)

#endregion


#region staircase

func test_staircase_basic():
	# floor(7/3) * 2 = 2 * 2 = 4
	var result := Utils.staircase(7.0, 3.0, 2.0)
	assert_eq(result, 4.0)


func test_staircase_exactly_on_step():
	# floor(6/3) * 2 = 2 * 2 = 4
	var result := Utils.staircase(6.0, 3.0, 2.0)
	assert_eq(result, 4.0)


func test_staircase_zero_input():
	var result := Utils.staircase(0.0, 3.0, 2.0)
	assert_eq(result, 0.0)


func test_staircase_step_equals_height():
	# floor(5/1) * 1 = 5
	var result := Utils.staircase(5.0, 1.0, 1.0)
	assert_eq(result, 5.0)


func test_staircase_large_step():
	# floor(4/10) * 5 = 0 * 5 = 0
	var result := Utils.staircase(4.0, 10.0, 5.0)
	assert_eq(result, 0.0)


func test_staircase_negative_input():
	# floor(-1/3) * 2 = -1 * 2 = -2
	var result := Utils.staircase(-1.0, 3.0, 2.0)
	assert_eq(result, -2.0)


func test_staircase_zero_step_width_returns_zero():
	var result := Utils.staircase(7.0, 0.0, 2.0)
	assert_push_error("step_width cannot be 0")
	assert_eq(result, 0.0)

#endregion


#region angle_distance

func test_angle_distance_same_angle():
	var result := Utils.angle_distance(0.0, 0.0)
	assert_almost_eq(result, 0.0, 0.001)


func test_angle_distance_quarter_turn_forward():
	var result := Utils.angle_distance(0.0, PI / 2)
	assert_almost_eq(result, PI / 2, 0.001)


func test_angle_distance_quarter_turn_backward():
	var result := Utils.angle_distance(PI / 2, 0.0)
	assert_almost_eq(result, -PI / 2, 0.001)


func test_angle_distance_wraps_short_way():
	# Going from almost-PI to almost-PI-negative should be a small distance
	var result := Utils.angle_distance(PI - 0.1, -(PI - 0.1))
	assert_almost_eq(abs(result), 0.2, 0.001)

#endregion


#region angle_distance_deg

func test_angle_distance_deg_same_angle():
	var result := Utils.angle_distance_deg(0.0, 0.0)
	assert_almost_eq(result, 0.0, 0.01)


func test_angle_distance_deg_quarter_turn():
	var result := Utils.angle_distance_deg(0.0, 90.0)
	assert_almost_eq(result, 90.0, 0.01)


func test_angle_distance_deg_backward():
	var result := Utils.angle_distance_deg(90.0, 0.0)
	assert_almost_eq(result, -90.0, 0.01)


func test_angle_distance_deg_consistent_with_rad_version():
	var deg_result := Utils.angle_distance_deg(30.0, 60.0)
	var rad_result := rad_to_deg(Utils.angle_distance(deg_to_rad(30.0), deg_to_rad(60.0)))
	assert_almost_eq(deg_result, rad_result, 0.001)

#endregion


#region correct_target_angle

func test_correct_target_angle_no_correction_needed():
	var result := Utils.correct_target_angle(90.0, 180.0)
	assert_eq(result, 180.0)


func test_correct_target_angle_subtracts_360_when_too_far_ahead():
	# target 200 > current 10 + 180 = 190 → subtract 360
	var result := Utils.correct_target_angle(10.0, 200.0)
	assert_eq(result, -160.0)


func test_correct_target_angle_adds_360_when_too_far_behind():
	# target 10 < current 200 - 180 = 20 → add 360
	var result := Utils.correct_target_angle(200.0, 10.0)
	assert_eq(result, 370.0)


func test_correct_target_angle_at_boundary_no_correction():
	# target exactly at current + 180 → no correction
	var result := Utils.correct_target_angle(0.0, 180.0)
	assert_eq(result, 180.0)

#endregion


#region bunch

func test_bunch_exact_division():
	var result := Utils.bunch(10, 5)
	assert_eq(result, [2, 2, 2, 2, 2])


func test_bunch_with_remainder():
	var result := Utils.bunch(7, 5)
	assert_eq(result, [2, 2, 1, 1, 1])


func test_bunch_amount_less_than_max_bunches():
	var result := Utils.bunch(3, 5)
	var total:int = 0
	for v in result:
		total += v
	assert_eq(total, 3)


func test_bunch_zero_amount():
	var result := Utils.bunch(0, 5)
	assert_eq(result, [])


func test_bunch_sums_correctly_for_many_inputs():
	for amount in range(0, 15):
		for bunches in range(1, 6):
			var result := Utils.bunch(amount, bunches)
			var total:int = 0
			for v in result:
				total += v
			assert_eq(total, amount,
				"bunch(%d, %d) should sum to %d" % [amount, bunches, amount])


func test_bunch_values_differ_by_at_most_one():
	var result := Utils.bunch(7, 5)
	var min_val:int = result.min()
	var max_val:int = result.max()
	assert_true(max_val - min_val <= 1)

#endregion


#region get_magnitude_order

func test_get_magnitude_order_single_digit():
	assert_eq(Utils.get_magnitude_order(5.0), 0)


func test_get_magnitude_order_tens():
	assert_eq(Utils.get_magnitude_order(50.0), 1)


func test_get_magnitude_order_hundreds():
	assert_eq(Utils.get_magnitude_order(500.0), 2)


func test_get_magnitude_order_thousands():
	assert_eq(Utils.get_magnitude_order(5000.0), 3)


func test_get_magnitude_order_exactly_ten():
	assert_eq(Utils.get_magnitude_order(10.0), 1)


func test_get_magnitude_order_exactly_one():
	assert_eq(Utils.get_magnitude_order(1.0), 0)

#endregion


#region get_rect_segment_intersection

func test_get_rect_segment_intersection_hits_right_edge():
	var rect := Rect2(Vector2(0, 0), Vector2(10, 10))
	var inside := Vector2(5, 5)
	var outside := Vector2(20, 5)
	var hit := Utils.get_rect_segment_intersection(rect, inside, outside)
	assert_almost_eq(hit.x, 10.0, 0.001)
	assert_almost_eq(hit.y, 5.0, 0.001)


func test_get_rect_segment_intersection_hits_top_edge():
	var rect := Rect2(Vector2(0, 0), Vector2(10, 10))
	var inside := Vector2(5, 5)
	var outside := Vector2(5, -5)
	var hit := Utils.get_rect_segment_intersection(rect, inside, outside)
	assert_almost_eq(hit.x, 5.0, 0.001)
	assert_almost_eq(hit.y, 0.0, 0.001)


func test_get_rect_segment_intersection_hits_bottom_edge():
	var rect := Rect2(Vector2(0, 0), Vector2(10, 10))
	var inside := Vector2(5, 5)
	var outside := Vector2(5, 20)
	var hit := Utils.get_rect_segment_intersection(rect, inside, outside)
	assert_almost_eq(hit.y, 10.0, 0.001)


func test_get_rect_segment_intersection_no_hit_returns_zero():
	var rect := Rect2(Vector2(0, 0), Vector2(10, 10))
	# Both endpoints inside the rect → no edge intersection
	var inside := Vector2(3, 3)
	var outside := Vector2(6, 6)
	var hit := Utils.get_rect_segment_intersection(rect, inside, outside)
	assert_eq(hit, Vector2.ZERO)

#endregion


#region format_as_rkm

func test_format_as_rkm_below_threshold():
	assert_eq(Utils.format_as_rkm(999.0), "999")


func test_format_as_rkm_thousands():
	assert_eq(Utils.format_as_rkm(3547.0), "3k5")


func test_format_as_rkm_millions():
	assert_eq(Utils.format_as_rkm(1200000.0), "1M2")


func test_format_as_rkm_negative():
	assert_eq(Utils.format_as_rkm(-3547.0), "-3k5")


func test_format_as_rkm_no_decimal_figures():
	assert_eq(Utils.format_as_rkm(3547.0, 0), "3k")


func test_format_as_rkm_two_decimal_figures():
	assert_eq(Utils.format_as_rkm(3547.0, 2), "3k54")

#endregion


#region format_with_suffix

func test_format_with_suffix_below_threshold():
	assert_eq(Utils.format_with_suffix(999.0), "999")


func test_format_with_suffix_thousands():
	assert_eq(Utils.format_with_suffix(3547.0), "3.5k")


func test_format_with_suffix_millions():
	assert_eq(Utils.format_with_suffix(1200000.0), "1.2M")


func test_format_with_suffix_negative():
	assert_eq(Utils.format_with_suffix(-3547.0), "-3.5k")


func test_format_with_suffix_no_decimal_figures():
	assert_eq(Utils.format_with_suffix(3547.0, 0), "3k")


func test_format_with_suffix_two_decimal_figures():
	assert_eq(Utils.format_with_suffix(3547.0, 2), "3.54k")

#endregion


#region standardize_string

func test_standardize_string_capitalizes_first_letter():
	assert_eq(Utils.standardize_string("hello world"), "Hello world")


func test_standardize_string_strips_trailing_whitespace():
	assert_eq(Utils.standardize_string("Hello   "), "Hello")


func test_standardize_string_strips_leading_whitespace():
	assert_eq(Utils.standardize_string("   Hello"), "Hello")


func test_standardize_string_removes_trailing_period():
	assert_eq(Utils.standardize_string("Hello."), "Hello")


func test_standardize_string_keeps_ellipsis():
	assert_eq(Utils.standardize_string("Hello..."), "Hello...")


func test_standardize_string_adds_period_when_requested():
	assert_eq(Utils.standardize_string("Hello", true), "Hello.")


func test_standardize_string_does_not_double_period():
	assert_eq(Utils.standardize_string("Hello.", true), "Hello.")


func test_standardize_string_empty_returns_empty():
	assert_eq(Utils.standardize_string(""), "")

#endregion


#region rstrip_whitespace and lstrip_whitespace

func test_rstrip_whitespace_removes_trailing_spaces():
	assert_eq(Utils.rstrip_whitespace("Hello   "), "Hello")


func test_rstrip_whitespace_preserves_leading_spaces():
	assert_eq(Utils.rstrip_whitespace("   Hello"), "   Hello")


func test_rstrip_whitespace_removes_trailing_newline():
	assert_eq(Utils.rstrip_whitespace("Hello\n"), "Hello")


func test_lstrip_whitespace_removes_leading_spaces():
	assert_eq(Utils.lstrip_whitespace("   Hello"), "Hello")


func test_lstrip_whitespace_preserves_trailing_spaces():
	assert_eq(Utils.lstrip_whitespace("Hello   "), "Hello   ")


func test_lstrip_whitespace_removes_leading_newline():
	assert_eq(Utils.lstrip_whitespace("\nHello"), "Hello")

#endregion


#region format_number_compact

func test_format_number_compact_small_number_returned_as_is():
	assert_eq(Utils.format_number_compact(999.0), "999")


func test_format_number_compact_uses_million_suffix():
	var result := Utils.format_number_compact(1500000.0)
	assert_true(result.ends_with("M"), "Expected M suffix, got: %s" % result)


func test_format_number_compact_respects_max_chars():
	var result := Utils.format_number_compact(1234567.0, 6)
	assert_true(result.length() <= 6,
		"Result '%s' exceeds max_chars of 6" % result)


func test_format_number_compact_truncates_not_rounds():
	# 1999999 / 1e6 = 1.999999; truncated to fit = 1.999M (6 chars) or similar
	var result := Utils.format_number_compact(1999000.0, 5)
	assert_false(result.begins_with("2"),
		"Should truncate, not round up to 2M, got: %s" % result)


func test_format_number_compact_uses_custom_suffixes():
	# ABB uses "B" for 1e9, SI uses "G" — confirms the suffix dictionary is respected
	var abb_result := Utils.format_number_compact(2e9, 6, Utils.ABB_SUFFIXES)
	var si_result := Utils.format_number_compact(2e9, 6, Utils.SI_SUFFIXES)
	assert_true(abb_result.ends_with("B"), "Expected B suffix, got: %s" % abb_result)
	assert_true(si_result.ends_with("G"), "Expected G suffix, got: %s" % si_result)

#endregion


#region rand_weighted

func test_rand_weighted_empty_catalog_returns_null():
	var result: Variant = Utils.rand_weighted({})
	assert_null(result)


func test_rand_weighted_single_element_always_returns_it():
	for i in range(10):
		var result: Variant = Utils.rand_weighted({"only": 1.0})
		assert_eq(result, "only")


func test_rand_weighted_infinite_weight_always_selected():
	var rng := RandomNumberGenerator.new()
	rng.seed = 12345
	for i in range(20):
		var result: Variant = Utils.rand_weighted({"finite": 1.0, "infinite": INF}, false, rng)
		assert_eq(result, "infinite")


func test_rand_weighted_returns_key_from_catalog():
	var catalog := {"a": 1.0, "b": 2.0, "c": 3.0}
	var rng := RandomNumberGenerator.new()
	rng.seed = 42
	for i in range(30):
		var result: Variant = Utils.rand_weighted(catalog, false, rng)
		assert_true(result in catalog,
			"Result '%s' not in catalog" % str(result))


func test_rand_weighted_sorted_catalog_same_as_unsorted():
	var rng1 := RandomNumberGenerator.new()
	rng1.seed = 99
	var rng2 := RandomNumberGenerator.new()
	rng2.seed = 99
	var catalog := {"a": 1.0, "b": 2.0, "c": 3.0}
	for i in range(20):
		var r1: Variant = Utils.rand_weighted(catalog, false, rng1)
		var r2: Variant = Utils.rand_weighted(catalog, true, rng2)
		assert_eq(r1, r2)

#endregion


#region get_layer_number

const TEST_LAYER_SETTING := "layer_names/2d_physics/layer_7"


## Names physics layer 7 for the duration of the callable, then restores it
func _with_named_layer(layer_name:String, body:Callable)-> void:
	var had_setting := ProjectSettings.has_setting(TEST_LAYER_SETTING)
	var previous:Variant = ProjectSettings.get_setting(TEST_LAYER_SETTING) if had_setting else null

	ProjectSettings.set_setting(TEST_LAYER_SETTING, layer_name)
	body.call()

	if had_setting:
		ProjectSettings.set_setting(TEST_LAYER_SETTING, previous)
	else:
		ProjectSettings.clear(TEST_LAYER_SETTING)


func test_get_layer_number_unknown_returns_minus_one():
	var result := Utils.get_layer_number("__nonexistent_layer_xyz__")
	assert_eq(result, -1)


func test_get_layer_number_finds_named_layer():
	_with_named_layer("TestLayerName", func():
		assert_eq(Utils.get_layer_number("TestLayerName"), 7)
	)


func test_get_layer_number_is_case_insensitive():
	_with_named_layer("TestLayerName", func():
		assert_eq(Utils.get_layer_number("testlayername"), 7)
	)

#endregion


#region rand_bool

func test_rand_bool_zero_probability_never_true():
	for i in range(100):
		assert_false(Utils.rand_bool(0.0))


func test_rand_bool_one_probability_always_true():
	# randf() is inclusive of 1.0, so this can in principle fail, but only for
	# one out of ~2^32 draws.
	for i in range(100):
		assert_true(Utils.rand_bool(1.0))


func test_rand_bool_half_probability_produces_both_outcomes():
	seed(12345)
	var trues:int = 0
	for i in range(200):
		if Utils.rand_bool(0.5):
			trues += 1
	assert_between(trues, 1, 199,
		"Expected a mix of outcomes at p=0.5, got %d trues out of 200" % trues)


func test_rand_bool_probability_above_one_warns_and_returns_true():
	var result := Utils.rand_bool(1.5)
	assert_push_warning("not in [0,1]")
	assert_true(result)


func test_rand_bool_negative_probability_warns_and_returns_false():
	var result := Utils.rand_bool(-0.5)
	assert_push_warning("not in [0,1]")
	assert_false(result)

#endregion


#region rand_sort

func test_rand_sort_preserves_length():
	var original := [1, 2, 3, 4, 5]
	var result := Utils.rand_sort(original)
	assert_eq(result.size(), original.size())


func test_rand_sort_preserves_elements():
	var original := [1, 2, 3, 4, 5]
	var result := Utils.rand_sort(original)
	var sorted_result := result.duplicate()
	sorted_result.sort()
	assert_eq(sorted_result, original)


func test_rand_sort_does_not_modify_original():
	var original := [1, 2, 3, 4, 5]
	Utils.rand_sort(original)
	assert_eq(original, [1, 2, 3, 4, 5])


func test_rand_sort_empty_array():
	var result := Utils.rand_sort([])
	assert_eq(result, [])


func test_rand_sort_single_element():
	var result := Utils.rand_sort([42])
	assert_eq(result, [42])


func test_rand_sort_keeps_duplicates():
	var result := Utils.rand_sort([1, 1, 2])
	var sorted_result := result.duplicate()
	sorted_result.sort()
	assert_eq(sorted_result, [1, 1, 2])


func test_rand_sort_eventually_produces_a_different_order():
	seed(12345)
	var original := [1, 2, 3, 4, 5, 6]
	var shuffled := false
	for i in range(20):
		if Utils.rand_sort(original) != original:
			shuffled = true
			break
	assert_true(shuffled, "20 sorts of a 6-element array all came back in order")

#endregion


#region format_without_zero_decimals

func test_format_without_zero_decimals_whole_number_has_no_decimals():
	assert_eq(Utils.format_without_zero_decimals(5.0), "5")


func test_format_without_zero_decimals_keeps_two_decimals():
	assert_eq(Utils.format_without_zero_decimals(5.25), "5.25")


func test_format_without_zero_decimals_pads_to_two_decimals():
	assert_eq(Utils.format_without_zero_decimals(5.5), "5.50")


func test_format_without_zero_decimals_rounds_extra_decimals():
	assert_eq(Utils.format_without_zero_decimals(5.256), "5.26")


func test_format_without_zero_decimals_zero():
	assert_eq(Utils.format_without_zero_decimals(0.0), "0")


func test_format_without_zero_decimals_negative_whole():
	assert_eq(Utils.format_without_zero_decimals(-5.0), "-5")


func test_format_without_zero_decimals_negative_with_decimals():
	assert_eq(Utils.format_without_zero_decimals(-5.25), "-5.25")

#endregion


#region write_local_file

func test_write_local_file_creates_file_with_correct_content():
	var path := "user://test_write_local_file.tmp"
	var data := "hello".to_utf8_buffer()
	Utils.write_local_file(path, data)
	var f := FileAccess.open(path, FileAccess.READ)
	assert_not_null(f)
	var read_back := f.get_buffer(data.size())
	f.close()
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	assert_eq(read_back, data)

#endregion


#region get_all_subnodes

func test_get_all_subnodes_returns_document_order():
	## Callers pick "the first light" out of this, so sibling order is part of
	## the contract, not an implementation detail.
	var root := Node.new()
	root.name = "Root"
	var first := Node.new()
	first.name = "First"
	var second := Node.new()
	second.name = "Second"
	var nested := Node.new()
	nested.name = "Nested"

	root.add_child(first)
	first.add_child(nested)
	root.add_child(second)

	var names:Array[String] = []
	for node in Utils.get_all_subnodes(root):
		names.append(node.name)

	assert_eq(names, ["Root", "First", "Nested", "Second"] as Array[String],
		"parents before children, siblings in scene order")
	root.free()


func test_get_all_subnodes_handles_null():
	assert_eq(Utils.get_all_subnodes(null).size(), 0)


func test_get_all_subnodes_of_type_matches_subclasses():
	var root := Node3D.new()
	var omni := OmniLight3D.new()
	var plain := Node3D.new()
	root.add_child(omni)
	root.add_child(plain)

	var found := Utils.get_all_subnodes_of_type(root, "Light3D")

	assert_eq(found.size(), 1, "is_class matches the subclass")
	assert_eq(found[0], omni)
	root.free()

#endregion
