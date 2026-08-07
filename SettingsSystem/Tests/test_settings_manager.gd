extends GutTest

## These tests build their own SettingsManager instead of using the Settings
## autoload, so the settings the player sees are never touched. Most of them
## keep that manager out of the tree: _ready is what connects setting_changed
## to the reactions that change the window mode and the locale, so a manager
## that never entered the tree can be written to freely. The ones that do need
## _ready (the startup section) are careful to only write settings that have no
## reaction wired to them.
##
## SETTINGS_SAVE_PATH is a constant, so every manager saves to the real file.
## It is snapshotted in before_all and put back in after_all.

var _real_file:PackedByteArray
var _had_file:bool
var _original_locale:String

var _quality:SettingInfo
var _flag:SettingInfo
var _language:SettingInfo


func before_all()-> void:
	_had_file = FileAccess.file_exists(SettingsManager.SETTINGS_SAVE_PATH)
	if _had_file:
		_real_file = FileAccess.get_file_as_bytes(SettingsManager.SETTINGS_SAVE_PATH)


func after_all()-> void:
	if _had_file:
		var file := FileAccess.open(SettingsManager.SETTINGS_SAVE_PATH, FileAccess.WRITE)
		file.store_buffer(_real_file)
		file.close()
	else:
		_remove_settings_file()


func before_each()-> void:
	_original_locale = TranslationServer.get_locale()

	_quality = _make_setting_info("test_quality", Variant.Type.TYPE_INT)
	_quality.min_value = 1
	_quality.max_value = 3

	_flag = _make_setting_info("test_flag", Variant.Type.TYPE_BOOL)

	_language = _make_setting_info("test_language", Variant.Type.TYPE_ARRAY)
	_language.options = {"en": "English", "es": "Spanish", "ca": "Catalan"}


func after_each()-> void:
	TranslationServer.set_locale(_original_locale)


func _make_setting_info(setting_name:String, type:Variant.Type)-> SettingInfo:
	var setting := SettingInfo.new()
	setting.name = setting_name
	setting.dname = setting_name
	setting.type = type
	return setting


## A manager holding the three test settings. It is not in the tree, so
## _on_setting_changed is not connected and writing to it has no side effects
## beyond the settings file.
func _make_manager()-> SettingsManager:
	var manager := SettingsManager.new()
	manager.settings = SettingsContainer.new()
	manager.settings.values[_quality] = 1
	manager.settings.values[_flag] = true
	manager.settings.values[_language] = "en"
	return autofree(manager)


func _remove_settings_file()-> void:
	DirAccess.remove_absolute(
		ProjectSettings.globalize_path(SettingsManager.SETTINGS_SAVE_PATH))


## A setting from the game's defaults that _on_setting_changed does not react
## to, so the startup tests cannot change the window mode or the locale
func _pick_neutral_setting()-> SettingInfo:
	var reacted:Array[String] = [
		GodotBase.settings.window_mode_setting.name,
		GodotBase.settings.language_setting.name,
	]
	for setting in SettingsManager.DEFAULT_SETTINGS.values.keys():
		if setting.name not in reacted:
			return setting
	return null


## Any value other than the given one, so the startup tests can tell a value
## that was applied from one that was already there
func _other_value(setting:SettingInfo, current:Variant)-> Variant:
	match setting.type:
		Variant.Type.TYPE_BOOL:
			return not current
		Variant.Type.TYPE_INT:
			return int(current) + 1
		Variant.Type.TYPE_ARRAY:
			for key in setting.options.keys():
				if key != current:
					return key
	return null


#region reading

func test_a_setting_is_read_by_resource():
	var manager := _make_manager()

	assert_eq(manager.get_setting_value(_quality), 1)


func test_a_setting_is_read_by_name():
	var manager := _make_manager()

	assert_eq(manager.get_setting_value_by_name("test_language"), "en")

#endregion


#region writing

func test_writing_by_name_changes_the_value():
	var manager := _make_manager()

	manager.set_setting_value_by_name("test_quality", 2)

	assert_eq(manager.get_setting_value(_quality), 2)


func test_writing_by_resource_changes_the_value():
	var manager := _make_manager()

	manager.set_setting(_quality, 2)

	assert_eq(manager.get_setting_value(_quality), 2)


func test_writing_by_name_announces_the_change():
	var manager := _make_manager()
	watch_signals(manager)

	manager.set_setting_value_by_name("test_quality", 2)

	assert_signal_emitted_with_parameters(manager, "setting_changed", ["test_quality", 2])


func test_writing_by_resource_announces_the_change_under_the_settings_name():
	var manager := _make_manager()
	watch_signals(manager)

	manager.set_setting(_flag, false)

	assert_signal_emitted_with_parameters(manager, "setting_changed", ["test_flag", false])


func test_writing_a_setting_saves_the_whole_configuration():
	var manager := _make_manager()

	manager.set_setting_value_by_name("test_quality", 3)

	var saved:SettingsContainer = ResourceLoader.load(
		SettingsManager.SETTINGS_SAVE_PATH, "", ResourceLoader.CACHE_MODE_IGNORE)
	assert_eq(saved.get_setting_value_by_name("test_quality"), 3)
	assert_eq(saved.get_setting_value_by_name("test_language"), "en",
		"the settings that did not change are saved too")

#endregion


#region applying a whole configuration

func test_applying_a_configuration_writes_all_of_its_values():
	var manager := _make_manager()
	var configuration := SettingsContainer.new()
	configuration.values[_quality] = 3
	configuration.values[_flag] = false

	manager.apply_configuration(configuration)

	assert_eq(manager.get_setting_value(_quality), 3)
	assert_eq(manager.get_setting_value(_flag), false)


func test_applying_a_configuration_matches_the_settings_by_name():
	# A configuration read back from disk can hold different SettingInfo
	# instances than the ones the manager started with
	var manager := _make_manager()
	var configuration := SettingsContainer.new()
	configuration.values[_make_setting_info("test_quality", Variant.Type.TYPE_INT)] = 3

	manager.apply_configuration(configuration)

	assert_eq(manager.get_setting_value(_quality), 3)
	assert_eq(manager.settings.values.size(), 3, "no second entry was added")


func test_applying_a_configuration_announces_every_setting():
	var manager := _make_manager()
	var configuration := SettingsContainer.new()
	configuration.values[_quality] = 3
	configuration.values[_flag] = false
	watch_signals(manager)

	manager.apply_configuration(configuration)

	assert_signal_emit_count(manager, "setting_changed", 2,
		"reactions are triggered one setting at a time")

#endregion


#region cycling

func test_cycling_a_bool_toggles_it():
	var manager := _make_manager()

	manager.cycle_setting("test_flag")

	assert_eq(manager.get_setting_value(_flag), false)


func test_cycling_a_bool_toggles_it_however_many_steps_are_asked_for():
	var manager := _make_manager()

	manager.cycle_setting("test_flag", 2)

	assert_eq(manager.get_setting_value(_flag), false)


func test_cycling_an_int_moves_one_step_up():
	var manager := _make_manager()

	manager.cycle_setting("test_quality")

	assert_eq(manager.get_setting_value(_quality), 2)


func test_cycling_an_int_over_several_steps_at_once():
	var manager := _make_manager()

	manager.cycle_setting("test_quality", 2)

	assert_eq(manager.get_setting_value(_quality), 3)


func test_cycling_an_int_past_the_top_wraps_to_the_bottom():
	var manager := _make_manager()
	manager.set_setting(_quality, 3)

	manager.cycle_setting("test_quality")

	assert_eq(manager.get_setting_value(_quality), 1, "the maximum is included in the range")


func test_cycling_an_int_backwards_from_the_bottom_wraps_to_the_top():
	var manager := _make_manager()

	manager.cycle_setting("test_quality", -1)

	assert_eq(manager.get_setting_value(_quality), 3)


func test_cycling_an_option_moves_to_the_next_one():
	var manager := _make_manager()

	manager.cycle_setting("test_language")

	assert_eq(manager.get_setting_value(_language), "es")


func test_cycling_an_option_wraps_around_the_list():
	var manager := _make_manager()
	manager.set_setting(_language, "ca")

	manager.cycle_setting("test_language")

	assert_eq(manager.get_setting_value(_language), "en")


func test_cycling_an_option_backwards_wraps_around_the_list():
	var manager := _make_manager()

	manager.cycle_setting("test_language", -1)

	assert_eq(manager.get_setting_value(_language), "ca")


func test_cycling_announces_the_change():
	var manager := _make_manager()
	watch_signals(manager)

	manager.cycle_setting("test_quality")

	assert_signal_emitted_with_parameters(manager, "setting_changed", ["test_quality", 2])

#endregion


#region startup

func test_startup_falls_back_to_the_defaults_without_a_settings_file():
	_remove_settings_file()

	var manager:SettingsManager = add_child_autofree(SettingsManager.new())

	for setting in SettingsManager.DEFAULT_SETTINGS.values.keys():
		assert_eq(manager.get_setting_value(setting),
			SettingsManager.DEFAULT_SETTINGS.values[setting], setting.name)


func test_startup_applies_the_saved_settings_over_the_defaults():
	var setting:SettingInfo = _pick_neutral_setting()
	var default_value:Variant = SettingsManager.DEFAULT_SETTINGS.get_setting_value(setting)
	var saved_value:Variant = _other_value(setting, default_value)
	# Only the one setting is saved, which is also what an old settings file
	# written before the rest of them existed looks like
	var saved := SettingsContainer.new()
	saved.values[setting] = saved_value
	ResourceSaver.save(saved, SettingsManager.SETTINGS_SAVE_PATH)

	var manager:SettingsManager = add_child_autofree(SettingsManager.new())

	assert_eq(manager.get_setting_value(setting), saved_value)


func test_startup_keeps_the_defaults_for_the_settings_the_file_does_not_mention():
	var setting:SettingInfo = _pick_neutral_setting()
	var saved := SettingsContainer.new()
	saved.values[setting] = _other_value(
		setting, SettingsManager.DEFAULT_SETTINGS.get_setting_value(setting))
	ResourceSaver.save(saved, SettingsManager.SETTINGS_SAVE_PATH)

	var manager:SettingsManager = add_child_autofree(SettingsManager.new())

	for default_setting in SettingsManager.DEFAULT_SETTINGS.values.keys():
		if default_setting == setting: continue
		assert_eq(manager.get_setting_value(default_setting),
			SettingsManager.DEFAULT_SETTINGS.values[default_setting], default_setting.name)


func test_changing_a_setting_does_not_write_into_the_defaults():
	# The manager works on a copy, otherwise the preloaded defaults would drift
	# with every change and stop being defaults
	_remove_settings_file()
	var setting:SettingInfo = _pick_neutral_setting()
	var default_value:Variant = SettingsManager.DEFAULT_SETTINGS.get_setting_value(setting)
	var manager:SettingsManager = add_child_autofree(SettingsManager.new())

	manager.set_setting(setting, _other_value(setting, default_value))

	assert_eq(SettingsManager.DEFAULT_SETTINGS.get_setting_value(setting), default_value)


func test_startup_keeps_running_while_the_game_is_paused():
	_remove_settings_file()

	var manager:SettingsManager = add_child_autofree(SettingsManager.new())

	assert_eq(manager.process_mode, Node.PROCESS_MODE_ALWAYS,
		"settings are changed from the pause menu")

#endregion


#region reactions

func test_changing_the_language_switches_the_locale():
	var manager := _make_manager()

	manager._on_setting_changed(GodotBase.settings.language_setting.name, "es")

	assert_eq(TranslationServer.get_locale(), "es")


func test_the_default_language_follows_the_system_one():
	var manager := _make_manager()
	var expected:String = Integration.get_current_language()
	if expected == "":
		expected = OS.get_locale_language()
	expected = TranslationServer.standardize_locale(expected)   # compare like for like


	manager._on_setting_changed(GodotBase.settings.language_setting.name, "default")

	assert_eq(TranslationServer.get_locale(), expected)


func test_a_setting_without_a_reaction_leaves_the_locale_alone():
	var manager := _make_manager()

	manager._on_setting_changed("test_quality", 2)

	assert_eq(TranslationServer.get_locale(), _original_locale)


func test_changing_the_window_mode_switches_the_window():
	if DisplayServer.get_name() == "headless":
		pending("there is no window to switch when running headless")
		return
	var manager := _make_manager()
	var original_mode := DisplayServer.window_get_mode()

	manager._on_setting_changed(GodotBase.settings.window_mode_setting.name, "fullscreen")
	var fullscreen_mode := DisplayServer.window_get_mode()
	manager._on_setting_changed(GodotBase.settings.window_mode_setting.name, "windowed")
	var windowed_mode := DisplayServer.window_get_mode()

	DisplayServer.window_set_mode(original_mode)
	assert_eq(fullscreen_mode, DisplayServer.WINDOW_MODE_FULLSCREEN)
	assert_eq(windowed_mode, DisplayServer.WINDOW_MODE_MAXIMIZED,
		"'windowed' maximizes rather than restoring the previous window size")

#endregion
