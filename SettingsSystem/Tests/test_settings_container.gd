extends GutTest

## SettingsContainer is a plain resource holding a SettingInfo -> value map, so
## every test builds its own container and none of them touch the Settings
## autoload or the settings file.

var _quality:SettingInfo
var _flag:SettingInfo
var _unregistered:SettingInfo


func before_each()-> void:
	_quality = _make_setting_info("test_quality", Variant.Type.TYPE_INT)
	_flag = _make_setting_info("test_flag", Variant.Type.TYPE_BOOL)
	_unregistered = _make_setting_info("test_unregistered", Variant.Type.TYPE_BOOL)


func _make_setting_info(setting_name:String, type:Variant.Type)-> SettingInfo:
	var setting := SettingInfo.new()
	setting.name = setting_name
	setting.dname = setting_name
	setting.type = type
	return setting


func _make_container()-> SettingsContainer:
	var container := SettingsContainer.new()
	container.values[_quality] = 3
	container.values[_flag] = true
	return container


#region reading by resource

func test_a_stored_value_is_returned():
	var container := _make_container()

	assert_eq(container.get_setting_value(_quality), 3)


func test_a_setting_that_was_never_stored_reads_as_null():
	var container := _make_container()

	assert_null(container.get_setting_value(_unregistered))


func test_settings_are_told_apart_by_resource_and_not_by_name():
	# Two SettingInfo instances can share a name, and the resource keyed lookup
	# only answers for the one that is actually in the container
	var container := _make_container()
	var twin := _make_setting_info("test_quality", Variant.Type.TYPE_INT)

	assert_null(container.get_setting_value(twin))

#endregion


#region reading by name

func test_a_stored_value_is_found_by_name():
	var container := _make_container()

	assert_eq(container.get_setting_value_by_name("test_quality"), 3)


func test_a_false_value_is_returned_and_not_mistaken_for_a_missing_one():
	var container := _make_container()
	container.values[_flag] = false

	assert_eq(container.get_setting_value_by_name("test_flag"), false)


func test_an_unknown_name_reads_as_null_and_is_reported():
	var container := _make_container()

	assert_null(container.get_setting_value_by_name("test_unregistered"))
	assert_push_warning("No value defined for setting 'test_unregistered'")


func test_the_setting_resource_is_found_by_name():
	var container := _make_container()

	assert_eq(container.get_setting_by_name("test_flag"), _flag)


func test_an_unknown_name_has_no_setting_resource():
	var container := _make_container()

	assert_null(container.get_setting_by_name("test_unregistered"))

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


func test_a_setting_can_be_overwritten_by_name():
	var container := _make_container()

	container.set_setting_by_name("test_flag", false)

	assert_eq(container.get_setting_value(_flag), false)


func test_writing_by_name_does_not_add_a_second_entry():
	var container := _make_container()

	container.set_setting_by_name("test_quality", 7)

	assert_eq(container.values.size(), 2)

#endregion


#region persistence

func test_a_container_survives_a_save_and_load_round_trip():
	# The settings file is written and read back this way on every change, and
	# the setting resources have to come back as the same instances for the
	# resource keyed lookups to keep working
	var path:String = "user://test_settings_container_%d.tres" % Time.get_ticks_usec()
	var quality_path:String = "user://test_setting_info_%d.tres" % Time.get_ticks_usec()
	# Only settings saved as their own resource can be referenced by a container
	# file, which is how the real ones (BaseSettings/*.tres) are set up
	ResourceSaver.save(_quality, quality_path)
	var container := _make_container()

	ResourceSaver.save(container, path)
	var loaded:SettingsContainer = ResourceLoader.load(
		path, "", ResourceLoader.CACHE_MODE_IGNORE)

	assert_eq(loaded.get_setting_value_by_name("test_quality"), 3)
	assert_eq(loaded.get_setting_by_name("test_quality"), _quality,
		"the saved file points at the setting resource, not at a copy of it")

	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	DirAccess.remove_absolute(ProjectSettings.globalize_path(quality_path))

#endregion
