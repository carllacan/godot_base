extends GutTest

var manager:ModifierManager


func before_each():
	manager = ModifierManager.new()


func after_each()-> void:
	# Back to the build configuration the run was started with
	BuildConfig.Default = null


func _additive(key:String, value:float)-> Modifier:
	return Modifier.make_new_additive(key, value)


func _multiplicative(key:String, value:float)-> Modifier:
	return Modifier.make_new_multiplicative(key, value)


## Replaces the build configuration with one of those sitting next to this
## script, so the tests do not depend on which configuration the run happened to
## pick up. The file is found relative to the script so the tests travel with
## their configurations.
func _use_build_config(file_name:String)-> void:
	var path:String = get_script().resource_path.get_base_dir().path_join(file_name)
	var config:BuildConfig = load(path)
	assert_not_null(config, "No build configuration at %s" % path)
	BuildConfig.Default = config


#region apply_modifiers

func test_a_new_manager_leaves_the_base_value_alone():
	assert_eq(manager.apply_modifiers(10.0, "speed"), 10.0)


func test_an_unknown_key_leaves_the_base_value_alone():
	manager.add_modifier(_additive("weight", 5.0))

	assert_eq(manager.apply_modifiers(10.0, "speed"), 10.0)


func test_additive_modifier_is_added_to_the_base_value():
	manager.add_modifier(_additive("speed", 3.0))

	assert_eq(manager.apply_modifiers(10.0, "speed"), 13.0)


func test_multiplicative_modifier_scales_the_base_value():
	manager.add_modifier(_multiplicative("speed", 0.5))

	assert_eq(manager.apply_modifiers(10.0, "speed"), 15.0)


func test_additive_modifiers_of_the_same_key_stack():
	manager.add_modifier(_additive("speed", 3.0))
	manager.add_modifier(_additive("speed", 4.0))

	assert_eq(manager.apply_modifiers(10.0, "speed"), 17.0)


func test_multiplicative_modifiers_of_the_same_key_sum_before_being_applied():
	manager.add_modifier(_multiplicative("speed", 1.0))
	manager.add_modifier(_multiplicative("speed", 1.0))

	# 10 * (1 + 1 + 1), not 10 * 2 * 2
	assert_eq(manager.apply_modifiers(10.0, "speed"), 30.0)


func test_additive_modifiers_are_applied_before_multiplicative_ones():
	manager.add_modifier(_multiplicative("speed", 1.0))
	manager.add_modifier(_additive("speed", 3.0))

	# (10 + 3) * 2, regardless of the order they were added in
	assert_eq(manager.apply_modifiers(10.0, "speed"), 26.0)


func test_keys_do_not_interfere_with_each_other():
	manager.add_modifier(_additive("speed", 3.0))
	manager.add_modifier(_multiplicative("weight", 1.0))

	assert_eq(manager.apply_modifiers(10.0, "speed"), 13.0)
	assert_eq(manager.apply_modifiers(10.0, "weight"), 20.0)


func test_negative_additive_modifier_subtracts():
	manager.add_modifier(_additive("speed", -4.0))

	assert_eq(manager.apply_modifiers(10.0, "speed"), 6.0)


func test_the_same_modifier_instance_can_be_added_twice():
	# This is what leveling an upgrade up does: the same resource is applied again
	var mod := _additive("speed", 3.0)
	manager.add_modifier(mod)
	manager.add_modifier(mod)

	assert_eq(manager.apply_modifiers(10.0, "speed"), 16.0)
	assert_eq(manager.modifiers.size(), 2)


func test_a_modifier_with_an_undefined_mode_has_no_effect():
	var mod := Modifier.new()
	mod.key = "speed"
	mod.value = 3.0
	mod.mode = Modifier.Mode._undef

	manager.add_modifier(mod)

	assert_eq(manager.apply_modifiers(10.0, "speed"), 10.0)
	assert_eq(manager.modifiers.size(), 1, "it is still tracked, it just does not contribute")

#endregion


#region times

func test_times_multiplies_the_additive_contribution():
	manager.add_modifier(_additive("speed", 3.0))

	assert_eq(manager.apply_modifiers(10.0, "speed", 3), 19.0)


func test_times_compounds_the_multiplicative_contribution():
	manager.add_modifier(_multiplicative("speed", 1.0))

	# 10 * 2^3
	assert_eq(manager.apply_modifiers(10.0, "speed", 3), 80.0)


func test_times_applies_to_both_contributions():
	manager.add_modifier(_additive("speed", 3.0))
	manager.add_modifier(_multiplicative("speed", 1.0))

	# (10 + 3*2) * 2^2
	assert_eq(manager.apply_modifiers(10.0, "speed", 2), 64.0)


func test_times_of_zero_leaves_the_base_value_alone():
	manager.add_modifier(_additive("speed", 3.0))
	manager.add_modifier(_multiplicative("speed", 1.0))

	assert_eq(manager.apply_modifiers(10.0, "speed", 0), 10.0)


func test_times_of_one_matches_the_default():
	manager.add_modifier(_additive("speed", 3.0))
	manager.add_modifier(_multiplicative("speed", 0.5))

	assert_eq(manager.apply_modifiers(10.0, "speed", 1), manager.apply_modifiers(10.0, "speed"))

#endregion


#region remove_modifier

func test_removing_an_additive_modifier_undoes_its_effect():
	var mod := _additive("speed", 3.0)
	manager.add_modifier(mod)

	manager.remove_modifier(mod)

	assert_eq(manager.apply_modifiers(10.0, "speed"), 10.0)
	assert_eq(manager.modifiers.size(), 0)


func test_removing_a_multiplicative_modifier_undoes_its_effect():
	var mod := _multiplicative("speed", 0.5)
	manager.add_modifier(mod)

	manager.remove_modifier(mod)

	assert_eq(manager.apply_modifiers(10.0, "speed"), 10.0)
	assert_eq(manager.modifiers.size(), 0)


func test_removing_one_of_two_modifiers_leaves_the_other_one():
	var mod := _additive("speed", 3.0)
	manager.add_modifier(mod)
	manager.add_modifier(_additive("speed", 4.0))

	manager.remove_modifier(mod)

	assert_eq(manager.apply_modifiers(10.0, "speed"), 14.0)


func test_removing_a_twice_added_instance_only_undoes_one_of_them():
	var mod := _additive("speed", 3.0)
	manager.add_modifier(mod)
	manager.add_modifier(mod)

	manager.remove_modifier(mod)

	assert_eq(manager.apply_modifiers(10.0, "speed"), 13.0)
	assert_eq(manager.modifiers.size(), 1)


func test_removing_a_modifier_that_was_never_added_does_nothing():
	manager.add_modifier(_additive("speed", 3.0))

	manager.remove_modifier(_additive("speed", 3.0))

	assert_eq(manager.apply_modifiers(10.0, "speed"), 13.0, "an equivalent copy is not the same modifier")
	assert_eq(manager.modifiers.size(), 1)


func test_removing_from_an_empty_manager_does_nothing():
	manager.remove_modifier(_additive("speed", 3.0))

	assert_eq(manager.apply_modifiers(10.0, "speed"), 10.0)
	assert_eq(manager.modifiers.size(), 0)


func test_a_key_can_be_emptied_and_refilled():
	var mod := _multiplicative("speed", 0.5)
	manager.add_modifier(mod)
	manager.remove_modifier(mod)

	manager.add_modifier(_multiplicative("speed", 1.0))

	assert_eq(manager.apply_modifiers(10.0, "speed"), 20.0)

#endregion


#region overrides

func test_an_overridden_value_is_the_one_that_gets_registered():
	_use_build_config("debug_on_build_config.tres")
	var mod := _additive("speed", 3.0)
	mod.override_value = 99.0
	mod.apply_override = true

	manager.add_modifier(mod)

	assert_eq(manager.apply_modifiers(10.0, "speed"), 109.0)

#endregion
