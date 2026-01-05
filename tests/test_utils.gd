extends GutTest

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

	# Should be -10, but negative X is not supported
	assert_eq(result, 0.0)
