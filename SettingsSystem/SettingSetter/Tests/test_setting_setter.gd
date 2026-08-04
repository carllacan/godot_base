extends GutTest

## These tests drive the real Settings autoload, since that is what the
## component talks to. They add three settings of their own to it instead of
## touching the game's, so nothing here can change what the player sees. The
## autoload still saves to SETTINGS_SAVE_PATH on every change, so that file is
## snapshotted in before_all and put back in after_all.

var _real_file:PackedByteArray
var _had_file:bool

var _quality:SettingInfo
var _flag:SettingInfo
var _language:SettingInfo


func before_all()-> void:
	_had_file = FileAccess.file_exists(SettingsManager.SETTINGS_SAVE_PATH)
	if _had_file:
		_real_file = FileAccess.get_file_as_bytes(SettingsManager.SETTINGS_SAVE_PATH)

	_quality = _make_setting_info("test_quality", "Quality", Variant.Type.TYPE_INT)
	_quality.min_value = 0
	_quality.max_value = 10

	_flag = _make_setting_info("test_flag", "Flag", Variant.Type.TYPE_BOOL)

	_language = _make_setting_info("test_language", "Language", Variant.Type.TYPE_ARRAY)
	_language.options = {"en": "English", "es": "Spanish", "ca": "Catalan"}


func after_all()-> void:
	for setting in [_quality, _flag, _language]:
		Settings.settings.values.erase(setting)

	if _had_file:
		var file := FileAccess.open(SettingsManager.SETTINGS_SAVE_PATH, FileAccess.WRITE)
		file.store_buffer(_real_file)
		file.close()
	else:
		DirAccess.remove_absolute(
			ProjectSettings.globalize_path(SettingsManager.SETTINGS_SAVE_PATH))


func before_each()-> void:
	# Registered directly, without going through the autoload, so no
	# setting_changed is emitted while the tests are setting themselves up
	Settings.settings.values[_quality] = 0
	Settings.settings.values[_flag] = true
	Settings.settings.values[_language] = "en"


func _make_setting_info(setting_name:String, dname:String, type:Variant.Type)-> SettingInfo:
	var setting := SettingInfo.new()
	setting.name = setting_name
	setting.dname = dname
	setting.type = type
	return setting


## Builds a Button with a SettingSetterComponent under it and puts it in the
## tree, which is what makes the parent emit "ready" and update itself.
func _make_setter(setting:SettingInfo, opts:Dictionary = {})-> SettingSetterComponent:
	var no_icons:Dictionary[Variant, Texture] = {}
	var no_reps:Dictionary[Variant, String] = {}

	var button := Button.new()
	button.icon = opts.get("icon", null)

	var setter := SettingSetterComponent.new()
	setter.target_setting = setting
	setter.icon_overrides = opts.get("icon_overrides", no_icons)
	setter.value_representation_overrides = opts.get("value_representation_overrides", no_reps)
	setter.show_only_overridden_values = opts.get("show_only_overridden_values", false)
	setter.override_button_text = opts.get("override_button_text", true)
	setter.include_settings_name = opts.get("include_settings_name", true)
	setter.left_click_increases = opts.get("left_click_increases", true)
	setter.right_click_decreases = opts.get("right_click_decreases", true)

	button.add_child(setter)
	add_child_autofree(button)
	return setter


## The three quality steps the pause menu exposes out of the 0..10 range
func _quality_reps()-> Dictionary[Variant, String]:
	var reps:Dictionary[Variant, String] = {0: "Low", 5: "Medium", 10: "High"}
	return reps


func _value(setting:SettingInfo)-> Variant:
	return Settings.get_setting_value_by_name(setting.name)


func _mouse_event(button_index:int, released:bool = true)-> InputEventMouseButton:
	var event := InputEventMouseButton.new()
	event.button_index = button_index
	event.pressed = not released
	return event


#region get_shown_values

func test_shown_values_are_the_overridden_setting_values():
	var setter := _make_setter(_quality, {"value_representation_overrides": _quality_reps()})

	assert_eq(setter.get_shown_values(), [0, 5, 10] as Array[Variant])


func test_shown_values_merge_both_override_dictionaries():
	var icons:Dictionary[Variant, Texture] = {10: PlaceholderTexture2D.new()}
	var reps:Dictionary[Variant, String] = {0: "Low"}
	var setter := _make_setter(_quality, {
		"icon_overrides": icons,
		"value_representation_overrides": reps,
	})

	assert_eq(setter.get_shown_values(), [10, 0] as Array[Variant])


func test_shown_values_do_not_repeat_a_value_overridden_twice():
	var icons:Dictionary[Variant, Texture] = {0: PlaceholderTexture2D.new()}
	var setter := _make_setter(_quality, {
		"icon_overrides": icons,
		"value_representation_overrides": _quality_reps(),
	})

	assert_eq(setter.get_shown_values(), [0, 5, 10] as Array[Variant])


func test_shown_values_are_empty_without_overrides():
	var setter := _make_setter(_quality)

	assert_eq(setter.get_shown_values(), [] as Array[Variant])

#endregion


#region must_show_value

func test_every_value_is_shown_when_not_restricted_to_overrides():
	var setter := _make_setter(_quality, {"value_representation_overrides": _quality_reps()})

	assert_true(setter.must_show_value(0))
	assert_true(setter.must_show_value(7), "7 has no override, but nothing is restricted")


func test_only_overridden_values_are_shown_when_restricted():
	var setter := _make_setter(_quality, {
		"value_representation_overrides": _quality_reps(),
		"show_only_overridden_values": true,
	})

	assert_true(setter.must_show_value(5))
	assert_false(setter.must_show_value(7))


func test_an_icon_override_is_enough_to_show_a_value():
	var icons:Dictionary[Variant, Texture] = {5: PlaceholderTexture2D.new()}
	var setter := _make_setter(_quality, {
		"icon_overrides": icons,
		"show_only_overridden_values": true,
	})

	assert_true(setter.must_show_value(5))
	assert_false(setter.must_show_value(0))

#endregion


#region cycling the whole range

func test_cycling_walks_the_whole_range_by_default():
	var setter := _make_setter(_quality)

	setter.cycle_setting(1)

	assert_eq(_value(_quality), 1)


func test_cycling_wraps_around_the_range():
	Settings.set_setting_value_by_name(_quality.name, 10)
	var setter := _make_setter(_quality)

	setter.cycle_setting(1)

	assert_eq(_value(_quality), 0)


func test_cycling_a_bool_toggles_it():
	var setter := _make_setter(_flag)

	setter.cycle_setting(1)

	assert_eq(_value(_flag), false)


func test_cycling_an_array_setting_moves_to_the_next_option():
	var setter := _make_setter(_language)

	setter.cycle_setting(1)

	assert_eq(_value(_language), "es")

#endregion


#region cycling only the overridden values

func test_cycling_skips_the_values_without_an_override():
	var setter := _make_setter(_quality, {
		"value_representation_overrides": _quality_reps(),
		"show_only_overridden_values": true,
	})

	setter.cycle_setting(1)
	assert_eq(_value(_quality), 5, "should jump from 0 to 5, not to 1")

	setter.cycle_setting(1)
	assert_eq(_value(_quality), 10)


func test_cycling_the_overridden_values_wraps_around():
	Settings.set_setting_value_by_name(_quality.name, 10)
	var setter := _make_setter(_quality, {
		"value_representation_overrides": _quality_reps(),
		"show_only_overridden_values": true,
	})

	setter.cycle_setting(1)

	assert_eq(_value(_quality), 0)


func test_cycling_backwards_wraps_to_the_last_overridden_value():
	var setter := _make_setter(_quality, {
		"value_representation_overrides": _quality_reps(),
		"show_only_overridden_values": true,
	})

	setter.cycle_setting(-1)

	assert_eq(_value(_quality), 10)


func test_cycling_forward_from_an_unshown_value_lands_on_the_first_one():
	# A settings file written before the overrides were set up can hold a
	# value that is no longer offered
	Settings.set_setting_value_by_name(_quality.name, 7)
	var setter := _make_setter(_quality, {
		"value_representation_overrides": _quality_reps(),
		"show_only_overridden_values": true,
	})

	setter.cycle_setting(1)

	assert_eq(_value(_quality), 0)


func test_cycling_backward_from_an_unshown_value_lands_on_the_last_one():
	Settings.set_setting_value_by_name(_quality.name, 7)
	var setter := _make_setter(_quality, {
		"value_representation_overrides": _quality_reps(),
		"show_only_overridden_values": true,
	})

	setter.cycle_setting(-1)

	assert_eq(_value(_quality), 10)


func test_cycling_over_several_steps_at_once():
	var setter := _make_setter(_quality, {
		"value_representation_overrides": _quality_reps(),
		"show_only_overridden_values": true,
	})

	setter.cycle_setting(2)

	assert_eq(_value(_quality), 10)


func test_cycling_without_overrides_leaves_the_value_alone():
	# Misconfiguration: the component is restricted to overridden values but
	# no override was set up. It reports the error and changes nothing.
	var setter := _make_setter(_quality, {"show_only_overridden_values": true})

	setter.cycle_setting(1)

	assert_eq(_value(_quality), 0)
	assert_push_error("only shows overridden values")

#endregion


#region button text

func test_button_text_shows_the_setting_name_and_value():
	var setter := _make_setter(_quality, {"value_representation_overrides": _quality_reps()})

	assert_eq(setter.get_parent().text, "QUALITY: Low")


func test_button_text_can_leave_out_the_setting_name():
	var setter := _make_setter(_quality, {
		"value_representation_overrides": _quality_reps(),
		"include_settings_name": false,
	})

	assert_eq(setter.get_parent().text, "Low")


func test_button_text_is_left_alone_when_not_overriding_it():
	var setter := _make_setter(_quality, {
		"value_representation_overrides": _quality_reps(),
		"override_button_text": false,
	})

	assert_eq(setter.get_parent().text, "")


func test_button_text_falls_back_to_the_settings_own_representation():
	Settings.set_setting_value_by_name(_quality.name, 7)
	var setter := _make_setter(_quality, {"value_representation_overrides": _quality_reps()})

	assert_eq(setter.get_parent().text, "QUALITY: 7")


func test_button_text_of_an_array_setting_uses_its_options():
	var setter := _make_setter(_language)

	assert_eq(setter.get_parent().text, "LANGUAGE: English")


func test_button_text_updates_when_the_setting_changes():
	var setter := _make_setter(_quality, {"value_representation_overrides": _quality_reps()})

	Settings.set_setting_value_by_name(_quality.name, 5)
	await wait_process_frames(2)

	assert_eq(setter.get_parent().text, "QUALITY: Medium")

#endregion


#region button icon

func test_button_icon_comes_from_the_override_of_the_current_value():
	var low_icon := PlaceholderTexture2D.new()
	var icons:Dictionary[Variant, Texture] = {0: low_icon}
	var setter := _make_setter(_quality, {"icon_overrides": icons})

	assert_eq(setter.get_parent().icon, low_icon)


func test_button_icon_returns_to_the_original_for_values_without_one():
	var original := PlaceholderTexture2D.new()
	var icons:Dictionary[Variant, Texture] = {5: PlaceholderTexture2D.new()}
	var setter := _make_setter(_quality, {"icon": original, "icon_overrides": icons})

	assert_eq(setter.get_parent().icon, original)


func test_button_icon_follows_the_setting():
	var high_icon := PlaceholderTexture2D.new()
	var icons:Dictionary[Variant, Texture] = {10: high_icon}
	var setter := _make_setter(_quality, {"icon_overrides": icons})

	Settings.set_setting_value_by_name(_quality.name, 10)
	await wait_process_frames(2)

	assert_eq(setter.get_parent().icon, high_icon)

#endregion


#region bool settings

func test_a_bool_setting_puts_its_button_in_toggle_mode():
	var setter := _make_setter(_flag)

	assert_true((setter.get_parent() as Button).toggle_mode)


func test_a_non_bool_setting_leaves_toggle_mode_off():
	var setter := _make_setter(_quality)

	assert_false((setter.get_parent() as Button).toggle_mode)

#endregion


#region mouse input

func test_left_click_cycles_forward():
	var setter := _make_setter(_quality)

	setter._on_parent_received_input(_mouse_event(MOUSE_BUTTON_LEFT))

	assert_eq(_value(_quality), 1)


func test_right_click_cycles_backwards():
	Settings.set_setting_value_by_name(_quality.name, 5)
	var setter := _make_setter(_quality)

	setter._on_parent_received_input(_mouse_event(MOUSE_BUTTON_RIGHT))

	assert_eq(_value(_quality), 4)


func test_clicks_are_ignored_until_the_button_is_released():
	var setter := _make_setter(_quality)

	setter._on_parent_received_input(_mouse_event(MOUSE_BUTTON_LEFT, false))

	assert_eq(_value(_quality), 0)


func test_left_click_can_be_turned_off():
	var setter := _make_setter(_quality, {"left_click_increases": false})

	setter._on_parent_received_input(_mouse_event(MOUSE_BUTTON_LEFT))

	assert_eq(_value(_quality), 0)


func test_right_click_can_be_turned_off():
	var setter := _make_setter(_quality, {"right_click_decreases": false})

	setter._on_parent_received_input(_mouse_event(MOUSE_BUTTON_RIGHT))

	assert_eq(_value(_quality), 0)


func test_clicking_only_offers_the_overridden_values():
	var setter := _make_setter(_quality, {
		"value_representation_overrides": _quality_reps(),
		"show_only_overridden_values": true,
	})

	setter._on_parent_received_input(_mouse_event(MOUSE_BUTTON_LEFT))
	await wait_process_frames(2)

	assert_eq(_value(_quality), 5)
	assert_eq(setter.get_parent().text, "QUALITY: Medium")

#endregion
