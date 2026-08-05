extends GutTest


func _additive(key:String, value:float)-> Modifier:
	return Modifier.make_new_additive(key, value)


func _multiplicative(key:String, value:float)-> Modifier:
	return Modifier.make_new_multiplicative(key, value)


#region factories

func test_make_new_additive_sets_fields():
	var mod := Modifier.make_new_additive("speed", 3.0)

	assert_eq(mod.key, "speed")
	assert_eq(mod.value, 3.0)
	assert_eq(mod.mode, Modifier.Mode.ADDITIVE)


func test_make_new_multiplicative_sets_fields():
	var mod := Modifier.make_new_multiplicative("speed", 0.25)

	assert_eq(mod.key, "speed")
	assert_eq(mod.value, 0.25)
	assert_eq(mod.mode, Modifier.Mode.MULTIPLICATIVE)

#endregion


#region apply

func test_additive_adds_value():
	var mod := _additive("speed", 3.0)

	assert_eq(mod.apply(10.0), 13.0)


func test_additive_with_negative_value_subtracts():
	var mod := _additive("speed", -4.0)

	assert_eq(mod.apply(10.0), 6.0)


func test_multiplicative_applies_value_as_a_fraction_over_one():
	var mod := _multiplicative("speed", 0.5)

	assert_eq(mod.apply(10.0), 15.0)


func test_multiplicative_with_negative_value_reduces():
	var mod := _multiplicative("speed", -0.25)

	assert_eq(mod.apply(10.0), 7.5)


func test_multiplicative_of_zero_base_stays_zero():
	var mod := _multiplicative("speed", 2.0)

	assert_eq(mod.apply(0.0), 0.0)


func test_unknown_mode_returns_nan():
	var mod := Modifier.new()
	mod.key = "speed"
	mod.value = 3.0
	mod.mode = Modifier.Mode._undef

	assert_true(is_nan(mod.apply(10.0)), "an undefined mode should not produce a usable value")
	assert_push_error("Unknown mode")

#endregion


#region get_value

func test_get_value_returns_the_exported_value_by_default():
	var mod := _additive("speed", 3.0)
	mod.override_value = 99.0

	assert_eq(mod.get_value(), 3.0, "the override is ignored unless apply_override is set")


func test_get_value_returns_the_override_when_enabled():
	var mod := _additive("speed", 3.0)
	mod.override_value = 99.0
	mod.apply_override = true

	assert_eq(mod.get_value(), 99.0)


func test_apply_uses_the_override():
	var mod := _additive("speed", 3.0)
	mod.override_value = 99.0
	mod.apply_override = true

	assert_eq(mod.apply(10.0), 109.0)

#endregion


#region get_value_str

func test_value_str_of_additive_is_the_rounded_value():
	assert_eq(_additive("speed", 3.0).get_value_str(), "3")


func test_value_str_of_multiplicative_is_a_percentage():
	assert_eq(_multiplicative("speed", 0.25).get_value_str(), "25%")


func test_value_str_of_negative_multiplicative_keeps_the_sign():
	assert_eq(_multiplicative("speed", -0.25).get_value_str(), "-25%")


func test_value_str_of_unknown_mode_is_empty():
	var mod := Modifier.new()
	mod.mode = Modifier.Mode._undef

	assert_eq(mod.get_value_str(), "")

#endregion


#region apply_list

func test_apply_list_on_an_empty_list_returns_the_base_value():
	var mods:Array[Modifier] = []

	assert_eq(Modifier.apply_list(10.0, "speed", mods), 10.0)


func test_apply_list_ignores_other_keys():
	var mods:Array[Modifier] = [_additive("weight", 5.0)]

	assert_eq(Modifier.apply_list(10.0, "speed", mods), 10.0)


func test_apply_list_chains_matching_modifiers():
	var mods:Array[Modifier] = [
		_additive("speed", 3.0),
		_additive("weight", 100.0),
		_multiplicative("speed", 1.0),
	]

	# (10 + 3) * 2
	assert_eq(Modifier.apply_list(10.0, "speed", mods), 26.0)


func test_apply_list_respects_the_order_of_the_list():
	var add_first:Array[Modifier] = [
		_additive("speed", 3.0),
		_multiplicative("speed", 1.0),
	]
	var mult_first:Array[Modifier] = [
		_multiplicative("speed", 1.0),
		_additive("speed", 3.0),
	]

	assert_eq(Modifier.apply_list(10.0, "speed", add_first), 26.0)
	assert_eq(Modifier.apply_list(10.0, "speed", mult_first), 23.0)


func test_apply_list_compounds_several_multiplicative_modifiers():
	var mods:Array[Modifier] = [
		_multiplicative("speed", 1.0),
		_multiplicative("speed", 1.0),
	]

	# 10 * 2 * 2, unlike ModifierManager, which sums the values first
	assert_eq(Modifier.apply_list(10.0, "speed", mods), 40.0)

#endregion


#region apply_all

func test_apply_all_on_empty_sources_returns_the_base_value():
	assert_eq(Modifier.apply_all(10.0, "speed", []), 10.0)


func test_apply_all_chains_across_sources():
	var first:Array[Modifier] = [_additive("speed", 3.0)]
	var second:Array[Modifier] = [_multiplicative("speed", 1.0)]

	# (10 + 3) * 2
	assert_eq(Modifier.apply_all(10.0, "speed", [first, second]), 26.0)


func test_apply_all_ignores_other_keys():
	var first:Array[Modifier] = [_additive("weight", 3.0)]
	var second:Array[Modifier] = [_additive("speed", 5.0)]

	assert_eq(Modifier.apply_all(10.0, "speed", [first, second]), 15.0)


func test_apply_all_skips_empty_sources():
	var empty:Array[Modifier] = []
	var mods:Array[Modifier] = [_additive("speed", 5.0)]

	assert_eq(Modifier.apply_all(10.0, "speed", [empty, mods, empty]), 15.0)

#endregion
