extends GutTest

## SettingsContainer is a plain resource holding an id -> value map, so
## every test builds its own container and none of them touch the Settings
## autoload or the settings file.

var _quality:SettingInfo
var _flag:SettingInfo
var _unregistered:SettingInfo


func before_each()-> void:
	_quality = _make_setting_info("test_quality", Variant.Type.TYPE_INT)
	_flag = _make_setting_info("test_flag", Variant.Type.TYPE_BOOL)
	_unregistered = _make_setting_info("test_unregistered", Variant.Type.TYPE_BOOL)


func _make_setting_info(setting_id:String, type:Variant.Type)-> SettingInfo:
	var setting := SettingInfo.new()
	setting.id = setting_id
	setting.dname = setting_id
	setting.type = type
	return setting


func _make_container()-> SettingsContainer:
	var container := SettingsContainer.new()
	container.known_settings = [_quality, _flag]
	container.values[_quality.id] = 3
	container.values[_flag.id] = true
	return container


#region reading by resource

func test_a_stored_value_is_returned():
	var container := _make_container()

	assert_eq(container.get_setting_value(_quality), 3)


func test_a_setting_that_was_never_stored_reads_as_null():
	var container := _make_container()

	assert_null(container.get_setting_value(_unregistered))


func test_settings_are_told_apart_by_id_and_not_by_resource():
	# Values are keyed by id, so any SettingInfo carrying the id reads the
	# stored value: a copy of a setting is the same setting
	var container := _make_container()
	var twin := _make_setting_info("test_quality", Variant.Type.TYPE_INT)

	assert_eq(container.get_setting_value(twin), 3)

#endregion


#region reading by id

func test_a_stored_value_is_found_by_id():
	var container := _make_container()

	assert_eq(container.get_setting_value_by_id("test_quality"), 3)


func test_a_false_value_is_returned_and_not_mistaken_for_a_missing_one():
	var container := _make_container()
	container.values[_flag.id] = false

	assert_eq(container.get_setting_value_by_id("test_flag"), false)


func test_an_unknown_id_reads_as_null_and_is_reported():
	var container := _make_container()

	assert_null(container.get_setting_value_by_id("test_unregistered"))
	assert_push_warning("No value defined for setting 'test_unregistered'")


func test_the_setting_resource_is_found_by_id():
	var container := _make_container()

	assert_eq(container.get_setting_by_id("test_flag"), _flag)


func test_an_id_the_catalog_does_not_list_has_no_setting_resource():
	var container := _make_container()

	assert_null(container.get_setting_by_id("test_unregistered"))

#endregion


#region writing

func test_a_setting_can_be_overwritten():
	var container := _make_container()

	container.set_setting(_quality, 7)

	assert_eq(container.get_setting_value(_quality), 7)


func test_writing_a_setting_the_container_did_not_have_adds_it():
	var container := _make_container()

	container.set_setting(_unregistered, true)

	assert_eq(container.get_setting_value(_unregistered), true)


func test_a_setting_can_be_overwritten_by_id():
	var container := _make_container()

	container.set_setting_by_id("test_flag", false)

	assert_eq(container.get_setting_value(_flag), false)


func test_writing_by_id_does_not_add_a_second_entry():
	var container := _make_container()

	container.set_setting_by_id("test_quality", 7)

	assert_eq(container.values.size(), 2)

#endregion


#region persistence

func test_a_container_survives_a_save_and_load_round_trip():
	# The settings file is written and read back this way on every change
	var path:String = "user://test_settings_container_%d.tres" % Time.get_ticks_usec()
	var container := _make_container()

	ResourceSaver.save(container, path)
	var loaded:SettingsContainer = ResourceLoader.load(
		path, "", ResourceLoader.CACHE_MODE_IGNORE)

	assert_eq(loaded.get_setting_value_by_id("test_quality"), 3)

	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))


func test_a_saved_file_refers_to_the_settings_by_id_and_not_by_resource():
	# The whole point of keying by id: a player's settings file must not hold
	# references to the SettingInfo resources the build happens to ship
	var path:String = "user://test_settings_container_%d.tres" % Time.get_ticks_usec()
	var container := SettingsContainer.new()
	container.values[_quality.id] = 3

	ResourceSaver.save(container, path)
	var written:String = FileAccess.get_file_as_string(path)

	assert_string_contains(written, "values = Dictionary[String, Variant]")
	assert_string_contains(written, "\"test_quality\": 3")

	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))

#endregion
