extends GutTest

## The controller reads three global services, so these tests drive the real
## ones: the build configuration is replaced by one that forces the flags to
## known values, and the settings and the controller type are put back the way
## they were once the tests are done. The Settings autoload saves to
## SETTINGS_SAVE_PATH on every change, so that file is snapshotted in before_all
## and restored in after_all.
##
## The controller is also kept from being ticked by the engine in the middle of
## a test: _make_controller turns physics processing off and the tests call
## _physics_process(delta) themselves. The one test that checks the engine
## really drives the countdown turns it back on.

var _real_file:PackedByteArray
var _had_file:bool

var _flag:SettingInfo
var _language:SettingInfo

var _original_controller_type:int


func before_all()-> void:
	_had_file = FileAccess.file_exists(SettingsManager.SETTINGS_SAVE_PATH)
	if _had_file:
		_real_file = FileAccess.get_file_as_bytes(SettingsManager.SETTINGS_SAVE_PATH)

	# Settings of the tests' own, so nothing here can change what the player sees
	_flag = _make_setting_info("test_visibility_flag", Variant.Type.TYPE_BOOL)

	_language = _make_setting_info("test_visibility_language", Variant.Type.TYPE_ARRAY)
	_language.options = {"en": "English", "es": "Spanish"}


func after_all()-> void:
	for setting in [_flag, _language]:
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
	Settings.settings.values[_flag] = true
	Settings.settings.values[_language] = "en"

	_original_controller_type = InputManager.current_controller_type
	InputManager.current_controller_type = InputManager.ControllerTypes.KBM

	_force_flags()


func after_each()-> void:
	InputManager.current_controller_type = _original_controller_type
	# Back to the build configuration the run was started with
	BuildConfig.Default = null


func _make_setting_info(setting_name:String, type:Variant.Type)-> SettingInfo:
	var setting := SettingInfo.new()
	setting.name = setting_name
	setting.dname = setting_name
	setting.type = type
	return setting


## Replaces the build configuration with one that forces the flags the
## controller looks at, so the tests do not depend on which configuration the
## run happened to pick up.
func _force_flags(opts:Dictionary = {})-> void:
	var config := BuildConfig.new()
	config.force_web = _forced(opts.get("web", false))
	config.force_demo = _forced(opts.get("demo", false))
	BuildConfig.Default = config


func _forced(value:bool)-> BaseBuildConfig.ForceActions:
	if value:
		return BaseBuildConfig.ForceActions.ForceTrue
	return BaseBuildConfig.ForceActions.ForceFalse


## Builds a controller hanging from the control it shows and hides, which is how
## it is used in the game's scenes. Everything is set before the parent enters
## the tree because the controller reads its exports once, while getting ready,
## and only updates the parent when the parent itself becomes ready.
func _make_controller(opts:Dictionary = {})-> VisibilityController:
	var parent := Control.new()

	var controller := VisibilityController.new()
	controller.hide_in_web = opts.get("hide_in_web", false)
	controller.hide_in_non_web = opts.get("hide_in_non_web", false)
	controller.hide_in_full = opts.get("hide_in_full", false)
	controller.hide_in_kbm = opts.get("hide_in_kbm", false)
	controller.hide_in_joypad = opts.get("hide_in_joypad", false)
	controller.hide_if_settings = opts.get("hide_if_settings", _conditions())
	controller.show_when_focused = opts.get("show_when_focused", _controls())
	controller.show_when_hovered = opts.get("show_when_hovered", _controls())
	controller.force_hide = opts.get("force_hide", false)

	parent.add_child(controller)
	add_child_autofree(parent)
	controller.set_physics_process(false)
	return controller


func _make_button()-> Button:
	var button := Button.new()
	add_child_autofree(button)
	return button


func _conditions(setting:SettingInfo = null, value:Variant = null)-> Dictionary[SettingInfo, Variant]:
	var conditions:Dictionary[SettingInfo, Variant] = {}
	if setting != null:
		conditions[setting] = value
	return conditions


func _controls(controls:Array = [])-> Array[Control]:
	var typed:Array[Control] = []
	typed.assign(controls)
	return typed


func _is_shown(controller:VisibilityController)-> bool:
	return controller.get_parent().visible


#region ready

func test_a_controller_without_conditions_shows_its_parent():
	var controller := _make_controller()

	assert_true(_is_shown(controller))


func test_the_controller_works_while_the_game_is_paused():
	var controller := _make_controller()

	assert_eq(controller.process_mode, Node.PROCESS_MODE_ALWAYS)

#endregion


#region build flags

func test_hiding_in_web_hides_the_parent_in_a_web_build():
	_force_flags({"web": true})

	var controller := _make_controller({"hide_in_web": true})

	assert_false(_is_shown(controller))


func test_hiding_in_web_leaves_the_parent_alone_outside_a_web_build():
	_force_flags({"web": false})

	var controller := _make_controller({"hide_in_web": true})

	assert_true(_is_shown(controller))


func test_hiding_outside_web_hides_the_parent_in_a_native_build():
	_force_flags({"web": false})

	var controller := _make_controller({"hide_in_non_web": true})

	assert_false(_is_shown(controller))


func test_hiding_outside_web_leaves_the_parent_alone_in_a_web_build():
	_force_flags({"web": true})

	var controller := _make_controller({"hide_in_non_web": true})

	assert_true(_is_shown(controller))


func test_hiding_in_the_full_game_hides_the_parent_outside_the_demo():
	_force_flags({"demo": false})

	var controller := _make_controller({"hide_in_full": true})

	assert_false(_is_shown(controller))


func test_hiding_in_the_full_game_leaves_the_parent_alone_in_the_demo():
	_force_flags({"demo": true})

	var controller := _make_controller({"hide_in_full": true})

	assert_true(_is_shown(controller))

#endregion


#region settings

func test_the_parent_is_hidden_while_the_setting_has_the_watched_value():
	var controller := _make_controller({"hide_if_settings": _conditions(_flag, true)})

	assert_false(_is_shown(controller))


func test_the_parent_is_shown_while_the_setting_has_another_value():
	var controller := _make_controller({"hide_if_settings": _conditions(_flag, false)})

	assert_true(_is_shown(controller))


func test_a_setting_of_any_type_can_be_watched():
	var controller := _make_controller({"hide_if_settings": _conditions(_language, "en")})

	assert_false(_is_shown(controller))


func test_the_parent_is_hidden_as_soon_as_the_setting_takes_the_watched_value():
	var controller := _make_controller({"hide_if_settings": _conditions(_flag, false)})

	Settings.set_setting(_flag, false)

	assert_false(_is_shown(controller))


func test_the_parent_is_shown_again_as_soon_as_the_setting_changes_back():
	var controller := _make_controller({"hide_if_settings": _conditions(_flag, true)})

	Settings.set_setting(_flag, false)

	assert_true(_is_shown(controller))


func test_any_of_the_watched_settings_is_enough_to_hide_the_parent():
	var conditions:Dictionary[SettingInfo, Variant] = {_flag: false, _language: "en"}
	var controller := _make_controller({"hide_if_settings": conditions})

	assert_false(_is_shown(controller), "the language matches even though the flag does not")


func test_the_parent_is_shown_when_none_of_the_watched_settings_matches():
	var conditions:Dictionary[SettingInfo, Variant] = {_flag: false, _language: "es"}
	var controller := _make_controller({"hide_if_settings": conditions})

	assert_true(_is_shown(controller))

#endregion


#region controller type

func test_hiding_in_joypad_hides_the_parent_while_a_joypad_is_in_use():
	InputManager.current_controller_type = InputManager.ControllerTypes.JOYPAD

	var controller := _make_controller({"hide_in_joypad": true})

	assert_false(_is_shown(controller))


func test_hiding_in_joypad_leaves_the_parent_alone_with_a_keyboard():
	var controller := _make_controller({"hide_in_joypad": true})

	assert_true(_is_shown(controller))


func test_hiding_in_kbm_hides_the_parent_while_a_keyboard_is_in_use():
	var controller := _make_controller({"hide_in_kbm": true})

	assert_false(_is_shown(controller))


func test_hiding_in_kbm_leaves_the_parent_alone_with_a_joypad():
	InputManager.current_controller_type = InputManager.ControllerTypes.JOYPAD

	var controller := _make_controller({"hide_in_kbm": true})

	assert_true(_is_shown(controller))


func test_the_parent_is_hidden_as_soon_as_the_controller_type_changes():
	var controller := _make_controller({"hide_in_joypad": true})

	InputManager.current_controller_type = InputManager.ControllerTypes.JOYPAD

	assert_false(_is_shown(controller))


func test_the_parent_is_shown_again_when_the_controller_type_changes_back():
	InputManager.current_controller_type = InputManager.ControllerTypes.JOYPAD
	var controller := _make_controller({"hide_in_joypad": true})

	InputManager.current_controller_type = InputManager.ControllerTypes.KBM

	assert_true(_is_shown(controller))

#endregion


#region hovered controls

func test_a_parent_that_waits_for_a_hover_starts_hidden():
	var target := _make_button()

	var controller := _make_controller({"show_when_hovered": _controls([target])})

	assert_false(_is_shown(controller))


func test_hovering_the_watched_control_shows_the_parent():
	var target := _make_button()
	var controller := _make_controller({"show_when_hovered": _controls([target])})

	target.mouse_entered.emit()

	assert_true(_is_shown(controller))


func test_leaving_the_watched_control_hides_the_parent_again():
	var target := _make_button()
	var controller := _make_controller({"show_when_hovered": _controls([target])})

	target.mouse_entered.emit()
	target.mouse_exited.emit()

	assert_false(_is_shown(controller))


func test_any_of_the_watched_controls_can_be_hovered():
	var first := _make_button()
	var second := _make_button()
	var controller := _make_controller({"show_when_hovered": _controls([first, second])})

	second.mouse_entered.emit()

	assert_true(_is_shown(controller))

#endregion


#region focused controls

func test_a_parent_that_waits_for_the_focus_starts_hidden():
	var target := _make_button()

	var controller := _make_controller({"show_when_focused": _controls([target])})

	assert_false(_is_shown(controller))


func test_the_parent_is_shown_while_the_watched_control_has_the_focus():
	var target := _make_button()
	target.grab_focus()

	var controller := _make_controller({"show_when_focused": _controls([target])})

	assert_true(_is_shown(controller))


func test_any_of_the_watched_controls_can_have_the_focus():
	var first := _make_button()
	var second := _make_button()
	second.grab_focus()

	var controller := _make_controller({"show_when_focused": _controls([first, second])})

	assert_true(_is_shown(controller))


# Nothing tells the controller that the focus moved, so the parent keeps the
# visibility it had until something else asks for an update
func test_the_focus_is_only_looked_at_while_updating_the_parent():
	var target := _make_button()
	var controller := _make_controller({"show_when_focused": _controls([target])})

	target.grab_focus()
	assert_false(_is_shown(controller))

	controller.update_parent()
	assert_true(_is_shown(controller))

#endregion


#region several conditions

func test_one_condition_is_enough_to_hide_the_parent():
	_force_flags({"web": false})

	var controller := _make_controller({"hide_in_web": true, "hide_in_kbm": true})

	assert_false(_is_shown(controller), "the build is not web, but the keyboard is in use")


func test_the_parent_is_shown_again_once_the_condition_is_gone():
	var controller := _make_controller({"force_hide": true})
	assert_false(_is_shown(controller))

	controller.force_hide = false
	controller.update_parent()

	assert_true(_is_shown(controller))

#endregion


#region forced hiding

func test_forcing_the_hiding_hides_the_parent():
	var controller := _make_controller({"force_hide": true})

	assert_false(_is_shown(controller))

#endregion


#region forced showing

# The forced time is counted down with the frame delta, so it is given in
# seconds here regardless of what the argument is called

func test_forcing_the_showing_shows_a_parent_that_would_be_hidden():
	var controller := _make_controller({"force_hide": true})

	controller.force_show_during(1.0)

	assert_true(_is_shown(controller))


func test_a_forced_showing_beats_every_hiding_condition():
	_force_flags({"web": true})
	var controller := _make_controller({
		"hide_in_web": true,
		"hide_in_kbm": true,
		"force_hide": true,
		"hide_if_settings": _conditions(_flag, true),
	})

	controller.force_show_during(1.0)

	assert_true(_is_shown(controller))


func test_the_parent_stays_shown_until_the_forced_time_is_over():
	var controller := _make_controller({"force_hide": true})
	controller.force_show_during(1.0)

	controller._physics_process(0.75)

	assert_true(_is_shown(controller))
	assert_almost_eq(controller.force_show_time_ms, 0.25, 0.001)


func test_the_parent_is_hidden_again_once_the_forced_time_runs_out():
	var controller := _make_controller({"force_hide": true})
	controller.force_show_during(1.0)

	controller._physics_process(1.0)
	controller._physics_process(1.0)

	assert_false(_is_shown(controller))
	assert_true(is_nan(controller.force_show_time_ms), "there is nothing left to count down")


func test_a_forced_showing_does_not_hide_a_parent_that_was_already_shown():
	var controller := _make_controller()
	controller.force_show_during(1.0)

	controller._physics_process(1.0)
	controller._physics_process(1.0)

	assert_true(_is_shown(controller))


func test_a_controller_without_a_forced_showing_has_nothing_to_count_down():
	var controller := _make_controller()

	controller._physics_process(1.0)

	assert_true(is_nan(controller.force_show_time_ms))


func test_the_engine_counts_down_a_forced_showing():
	var controller := _make_controller({"force_hide": true})
	controller.force_show_during(10.0)

	controller.set_physics_process(true)
	await wait_physics_frames(2)

	assert_lt(controller.force_show_time_ms, 10.0)
	assert_true(_is_shown(controller))

#endregion
