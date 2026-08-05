extends GutTest

## SettingInfo is a plain resource, so every test builds its own and nothing
## here touches the Settings autoload or the settings file. The only shared
## state is the TranslationServer, which the dname/description getters and
## get_value_representation go through; the tests that need it install their
## own translation and take it out again afterwards.

const TRANSLATED_KEY:String = "TEST_SETTING_INFO_KEY"
const TRANSLATED_TEXT:String = "Translated text"

var _translation:Translation


func before_each()-> void:
	_translation = Translation.new()
	_translation.locale = TranslationServer.get_locale()
	_translation.add_message(TRANSLATED_KEY, TRANSLATED_TEXT)
	_translation.add_message("ON", "Enabled")
	TranslationServer.add_translation(_translation)


func after_each()-> void:
	TranslationServer.remove_translation(_translation)


func _make_setting(type:Variant.Type)-> SettingInfo:
	var setting := SettingInfo.new()
	setting.name = "test_setting"
	setting.dname = "Test setting"
	setting.type = type
	return setting


func _make_array_setting()-> SettingInfo:
	var setting := _make_setting(Variant.Type.TYPE_ARRAY)
	setting.options = {"en": "English", "es": "Spanish"}
	return setting


#region translated getters

func test_dname_is_translated():
	var setting := _make_setting(Variant.Type.TYPE_BOOL)
	setting.dname = TRANSLATED_KEY

	assert_eq(setting.dname, TRANSLATED_TEXT)


func test_dname_without_a_translation_is_returned_as_written():
	var setting := _make_setting(Variant.Type.TYPE_BOOL)
	setting.dname = "Music"

	assert_eq(setting.dname, "Music")


func test_description_is_translated():
	var setting := _make_setting(Variant.Type.TYPE_BOOL)
	setting.description = TRANSLATED_KEY

	assert_eq(setting.description, TRANSLATED_TEXT)

#endregion


#region is_bool

func test_a_bool_setting_is_bool():
	assert_true(_make_setting(Variant.Type.TYPE_BOOL).is_bool())


func test_other_types_are_not_bool():
	assert_false(_make_setting(Variant.Type.TYPE_INT).is_bool())
	assert_false(_make_array_setting().is_bool())
	assert_false(_make_setting(Variant.Type.TYPE_FLOAT).is_bool())

#endregion


#region range

func test_a_bool_setting_has_a_zero_to_one_range():
	var setting := _make_setting(Variant.Type.TYPE_BOOL)
	setting.min_value = -5
	setting.max_value = 5

	assert_eq(setting.min_value, 0.0, "the exported values are ignored for bools")
	assert_eq(setting.max_value, 1.0)


func test_an_int_setting_truncates_its_range():
	var setting := _make_setting(Variant.Type.TYPE_INT)
	setting.min_value = 1.7
	setting.max_value = 9.9

	assert_eq(setting.min_value, 1.0)
	assert_eq(setting.max_value, 9.0)


func test_an_array_setting_has_no_range():
	var setting := _make_array_setting()

	assert_true(is_nan(setting.min_value), "the range is meaningless for options")
	assert_true(is_nan(setting.max_value))


func test_a_float_setting_keeps_the_range_it_was_given():
	var setting := _make_setting(Variant.Type.TYPE_FLOAT)
	setting.min_value = 0.5
	setting.max_value = 2.5

	assert_eq(setting.min_value, 0.5)
	assert_eq(setting.max_value, 2.5)

#endregion


#region get_value_representation

func test_a_true_bool_reads_as_on():
	var setting := _make_setting(Variant.Type.TYPE_BOOL)

	# "ON" has a translation installed, so this also covers the representation
	# going through the TranslationServer
	assert_eq(setting.get_value_representation(true), "Enabled")


func test_a_false_bool_reads_as_off():
	var setting := _make_setting(Variant.Type.TYPE_BOOL)

	assert_eq(setting.get_value_representation(false), "OFF")


func test_an_int_reads_as_its_digits():
	var setting := _make_setting(Variant.Type.TYPE_INT)

	assert_eq(setting.get_value_representation(7), "7")


func test_an_option_reads_as_its_external_representation():
	var setting := _make_array_setting()

	assert_eq(setting.get_value_representation("es"), "Spanish")


func test_an_unknown_option_is_reported():
	var setting := _make_array_setting()

	var representation:String = setting.get_value_representation("de")

	assert_eq(representation, "", "there is nothing sensible to show")
	assert_push_error("is not valid for setting")


func test_an_unsupported_type_is_reported():
	var setting := _make_setting(Variant.Type.TYPE_VECTOR2)

	var representation:String = setting.get_value_representation(Vector2.ZERO)

	assert_eq(representation, "")
	assert_push_error("Unexpected setting type")

#endregion
