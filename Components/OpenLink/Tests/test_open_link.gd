extends GutTest

## The component's two halves are tested differently. get_link and the signal
## wiring are plain logic and are tested directly. Pressing is not: _on_pressed
## ends in OS.shell_open, which would really open a browser on the machine
## running the tests, so only the store branch, which returns before reaching
## it, is exercised here. To see that branch happen at all the Integration
## autoload gets a spy script for the duration of each test and its own script
## back afterwards, which is safe because the controller holds no state.

## Feature tags the tests use to steer get_link. Tests always run from an
## editor build, so "editor" is there and "template" and "web", which only
## exported builds carry, are not.
const PRESENT_FEATURE:String = "editor"
const ABSENT_FEATURE:String = "template"
const OTHER_ABSENT_FEATURE:String = "web"

const LINK:String = "https://example.com"
const FEATURE_LINK:String = "https://feature.example.com"

var _original_integration_script:Script


class IntegrationSpy extends BaseIntegrationController:
	var store_page_calls:Array = []
	var overlay_calls:Array = []

	func open_store_page(store_id:Variant = null)-> void:
		store_page_calls.append(store_id)

	## The base controller has no such method, only the Steam one does, so the
	## spy provides it to keep the overlay branch from erroring out.
	func open_overlay(page_id:String)-> void:
		overlay_calls.append(page_id)


func before_each():
	_original_integration_script = Integration.get_script()
	Integration.set_script(IntegrationSpy)


func after_each():
	Integration.set_script(_original_integration_script)


## Builds the component under the button it acts on, which is how it is used in
## the game's scenes. The exports are set before the button enters the tree, so
## the component is configured by the time the button is pressable, like a
## scene loading its properties.
func _make_open_link(opts:Dictionary = {})-> OpenLink:
	var button := Button.new()

	var open_link := OpenLink.new()
	open_link.link = opts.get("link", "")
	open_link.link_if_feature = opts.get("link_if_feature", {} as Dictionary[String, String])
	open_link.store_id_if_feature = opts.get("store_id_if_feature", [] as Array[String])
	open_link.overlay_id = opts.get("overlay_id", "")

	button.add_child(open_link)
	add_child_autofree(button)
	return open_link


func _button(open_link:OpenLink)-> Button:
	return open_link.get_parent() as Button


func _store_page_calls()-> Array:
	return Integration.get("store_page_calls")


func _overlay_calls()-> Array:
	return Integration.get("overlay_calls")


#region the tags the tests are built on

func test_the_feature_tags_the_tests_steer_with_are_what_they_claim():
	assert_true(OS.has_feature(PRESENT_FEATURE), "%s is present" % PRESENT_FEATURE)
	assert_false(OS.has_feature(ABSENT_FEATURE), "%s is absent" % ABSENT_FEATURE)
	assert_false(OS.has_feature(OTHER_ABSENT_FEATURE), "%s is absent" % OTHER_ABSENT_FEATURE)

#endregion


#region wiring

func test_the_component_listens_to_its_parents_pressed_signal():
	var open_link := _make_open_link({"link": LINK})

	assert_true(_button(open_link).pressed.is_connected(open_link._on_pressed))


## The component waits for its parent to be ready before listening, so a button
## that has not entered the tree yet is not hooked up.
func test_a_parent_that_is_not_ready_yet_is_not_listened_to():
	var button:Button = autofree(Button.new())
	var open_link := OpenLink.new()
	button.add_child(open_link)

	assert_false(button.pressed.is_connected(open_link._on_pressed))


## The parent emits "ready" once, so a component added to a button that is
## already in the tree never gets to listen to it. Components have to be part
## of the scene, or added before it, to do anything.
func test_a_component_added_to_a_ready_parent_never_listens():
	var button:Button = autofree(Button.new())
	add_child_autofree(button)

	var open_link := OpenLink.new()
	button.add_child(open_link)

	assert_false(button.pressed.is_connected(open_link._on_pressed))

#endregion


#region the link

func test_the_plain_link_is_used_when_no_feature_link_is_configured():
	var open_link := _make_open_link({"link": LINK})

	assert_eq(open_link.get_link(), LINK)


func test_a_component_without_any_link_returns_nothing():
	var open_link := _make_open_link()

	assert_eq(open_link.get_link(), "")


func test_the_link_of_a_present_feature_wins_over_the_plain_link():
	var open_link := _make_open_link({
		"link": LINK,
		"link_if_feature": {PRESENT_FEATURE: FEATURE_LINK} as Dictionary[String, String],
	})

	assert_eq(open_link.get_link(), FEATURE_LINK)


func test_the_link_of_an_absent_feature_is_ignored():
	var open_link := _make_open_link({
		"link": LINK,
		"link_if_feature": {ABSENT_FEATURE: FEATURE_LINK} as Dictionary[String, String],
	})

	assert_eq(open_link.get_link(), LINK)


func test_a_present_feature_is_found_among_absent_ones():
	var open_link := _make_open_link({
		"link": LINK,
		"link_if_feature": {
			ABSENT_FEATURE: "https://absent.example.com",
			PRESENT_FEATURE: FEATURE_LINK,
			OTHER_ABSENT_FEATURE: "https://other.example.com",
		} as Dictionary[String, String],
	})

	assert_eq(open_link.get_link(), FEATURE_LINK)


func test_a_feature_link_is_used_even_without_a_plain_link():
	var open_link := _make_open_link({
		"link_if_feature": {PRESENT_FEATURE: FEATURE_LINK} as Dictionary[String, String],
	})

	assert_eq(open_link.get_link(), FEATURE_LINK)


## Nothing configured for the build it runs on means the plain link, empty or
## not: the feature links are overrides, not requirements.
func test_no_present_feature_and_no_plain_link_returns_nothing():
	var open_link := _make_open_link({
		"link_if_feature": {ABSENT_FEATURE: FEATURE_LINK} as Dictionary[String, String],
	})

	assert_eq(open_link.get_link(), "")

#endregion


#region pressing on a store build

func test_pressing_opens_the_store_page_when_a_store_feature_is_present():
	var open_link := _make_open_link({
		"link": LINK,
		"store_id_if_feature": [PRESENT_FEATURE] as Array[String],
	})

	_button(open_link).pressed.emit()

	assert_eq(_store_page_calls().size(), 1)


func test_a_present_store_feature_is_found_among_absent_ones():
	var open_link := _make_open_link({
		"link": LINK,
		"store_id_if_feature": [ABSENT_FEATURE, PRESENT_FEATURE] as Array[String],
	})

	_button(open_link).pressed.emit()

	assert_eq(_store_page_calls().size(), 1)


## The store page is opened without an id, so the platform opens this app's own
## page rather than some other app's.
func test_the_store_page_is_opened_without_an_id():
	var open_link := _make_open_link({
		"link": LINK,
		"store_id_if_feature": [PRESENT_FEATURE] as Array[String],
	})

	_button(open_link).pressed.emit()

	assert_eq(_store_page_calls(), [null])


func test_the_store_page_is_opened_instead_of_the_overlay():
	var open_link := _make_open_link({
		"link": LINK,
		"store_id_if_feature": [PRESENT_FEATURE] as Array[String],
		"overlay_id": "some_overlay",
	})

	_button(open_link).pressed.emit()

	assert_eq(_store_page_calls().size(), 1)
	assert_eq(_overlay_calls(), [])


func test_the_store_page_is_opened_even_with_a_feature_link_set():
	var open_link := _make_open_link({
		"link": LINK,
		"link_if_feature": {PRESENT_FEATURE: FEATURE_LINK} as Dictionary[String, String],
		"store_id_if_feature": [PRESENT_FEATURE] as Array[String],
	})

	_button(open_link).pressed.emit()

	assert_eq(_store_page_calls().size(), 1)

#endregion
