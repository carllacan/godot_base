extends GutTest

## The syncer is the bridge between a parent that shows a number and the global
## save, so every test puts a fresh GameState in Current.Save and works with
## throwaway GameResources rather than the game's own .tres files.

var _previous_save:GameState
var _save:GameState
var _resource:GameResource
var _other_resource:GameResource


## Stands in for a BaseAmountIndicator: a node with the property the syncer
## writes into, a property for the icon and the signal it listens to. The extra
## property and signal are there for the tests that move the syncer onto them.
class SyncerParent extends Node:
	signal amount_change_requested(delta:float)
	signal other_change_requested(delta:float)

	var amount:float = 0.0
	var icon:Texture = null
	var alt_icon:Texture = null


func before_each()-> void:
	_previous_save = Current.Save
	_save = GameState.new()
	_save.saving_enabled = false
	Current.Save = _save
	_resource = GameResource.new()
	_other_resource = GameResource.new()


func after_each()-> void:
	Current.Save = _previous_save


## Builds a syncer under a stand-in indicator and puts the pair in the tree,
## which is what makes the syncer run its on-ready wiring.
func _make_syncer(opts:Dictionary = {})-> GameResourceSyncer:
	var parent := SyncerParent.new()
	var syncer := GameResourceSyncer.new()
	syncer.resource = opts.get("resource", _resource)
	syncer.target_property = opts.get("target_property", "amount")
	syncer.icon_property = opts.get("icon_property", "icon")
	syncer.change_request_signal = opts.get("change_request_signal", "amount_change_requested")
	parent.add_child(syncer)
	add_child_autofree(parent)
	return syncer


func _parent(syncer:GameResourceSyncer)-> SyncerParent:
	return syncer.get_parent() as SyncerParent


#region on ready

func test_the_parent_gets_the_current_amount_on_ready():
	_save.set_resource(_resource, 7.0)

	var syncer := _make_syncer()

	assert_eq(_parent(syncer).amount, 7.0)


func test_a_resource_the_player_has_never_had_reads_as_zero():
	var syncer := _make_syncer()

	assert_eq(_parent(syncer).amount, 0.0)


func test_the_parent_gets_the_resource_icon_on_ready():
	var icon := PlaceholderTexture2D.new()
	_resource.icon = icon

	var syncer := _make_syncer()

	assert_eq(_parent(syncer).icon, icon)


func test_no_icon_is_applied_without_an_icon_property():
	_resource.icon = PlaceholderTexture2D.new()

	var syncer := _make_syncer({"icon_property": ""})

	assert_null(_parent(syncer).icon)


func test_no_icon_is_applied_without_a_resource():
	var syncer := _make_syncer({"resource": null})

	assert_null(_parent(syncer).icon)


func test_a_target_property_the_parent_does_not_have_is_reported():
	_make_syncer({"target_property": "not_a_property"})

	assert_push_error("has no property 'not_a_property'")


func test_an_icon_property_the_parent_does_not_have_is_reported():
	_make_syncer({"icon_property": "not_a_property"})

	assert_push_error("has no property 'not_a_property'")


func test_the_change_request_signal_is_connected_on_ready():
	var syncer := _make_syncer()

	assert_true(_parent(syncer).amount_change_requested.is_connected(syncer._on_change_requested))


func test_nothing_is_connected_without_a_change_request_signal():
	var syncer := _make_syncer({"change_request_signal": ""})

	assert_false(_parent(syncer).amount_change_requested.is_connected(syncer._on_change_requested))


func test_a_change_request_signal_the_parent_does_not_have_is_reported():
	_make_syncer({"change_request_signal": "not_a_signal"})

	assert_push_error("has no signal 'not_a_signal'")

#endregion


#region following the save

func test_the_parent_follows_the_resource_going_up():
	var syncer := _make_syncer()

	_save.set_resource(_resource, 12.0)

	assert_eq(_parent(syncer).amount, 12.0)


func test_the_parent_follows_the_resource_going_down():
	_save.set_resource(_resource, 12.0)
	var syncer := _make_syncer()

	_save.set_resource(_resource, 4.0)

	assert_eq(_parent(syncer).amount, 4.0)


func test_changes_to_other_resources_are_ignored():
	_save.set_resource(_resource, 3.0)
	var syncer := _make_syncer()

	_save.set_resource(_other_resource, 99.0)

	assert_eq(_parent(syncer).amount, 3.0)


func test_update_info_writes_the_current_amount():
	var syncer := _make_syncer()
	_parent(syncer).amount = 0.0

	_save.current_resources[_resource] = 5.0
	syncer.update_info()

	assert_eq(_parent(syncer).amount, 5.0)

#endregion


#region change requests

func test_a_change_request_adds_to_the_resource():
	_save.set_resource(_resource, 10.0)
	var syncer := _make_syncer()

	_parent(syncer).amount_change_requested.emit(3.0)

	assert_eq(_save.get_current_resource(_resource), 13.0)


func test_a_negative_change_request_takes_from_the_resource():
	_save.set_resource(_resource, 10.0)
	var syncer := _make_syncer()

	_parent(syncer).amount_change_requested.emit(-4.0)

	assert_eq(_save.get_current_resource(_resource), 6.0)


func test_the_parent_is_updated_after_its_own_change_request():
	_save.set_resource(_resource, 10.0)
	var syncer := _make_syncer()

	_parent(syncer).amount_change_requested.emit(3.0)

	assert_eq(_parent(syncer).amount, 13.0)


func test_a_change_request_without_a_resource_is_ignored():
	var syncer := _make_syncer({"resource": null})

	_parent(syncer).amount_change_requested.emit(3.0)

	assert_true(_save.current_resources.is_empty())


func test_a_change_request_without_a_save_is_ignored():
	var syncer := _make_syncer()
	Current.Save = null

	_parent(syncer).amount_change_requested.emit(3.0)

	Current.Save = _save
	assert_true(_save.current_resources.is_empty())

#endregion


#region changing the exports after ready

func test_changing_the_change_request_signal_moves_the_connection():
	var syncer := _make_syncer()

	syncer.change_request_signal = "other_change_requested"

	assert_false(_parent(syncer).amount_change_requested.is_connected(syncer._on_change_requested),
		"the old signal should have been let go")
	assert_true(_parent(syncer).other_change_requested.is_connected(syncer._on_change_requested),
		"the new signal should be listened to")


func test_the_new_change_request_signal_is_the_one_that_works():
	_save.set_resource(_resource, 10.0)
	var syncer := _make_syncer()
	syncer.change_request_signal = "other_change_requested"

	_parent(syncer).amount_change_requested.emit(3.0)
	assert_eq(_save.get_current_resource(_resource), 10.0, "the old signal should do nothing")

	_parent(syncer).other_change_requested.emit(3.0)

	assert_eq(_save.get_current_resource(_resource), 13.0)


func test_changing_the_icon_property_paints_the_new_one():
	var icon := PlaceholderTexture2D.new()
	_resource.icon = icon
	var syncer := _make_syncer()

	syncer.icon_property = "alt_icon"

	assert_eq(_parent(syncer).alt_icon, icon)


func test_changing_the_target_property_to_a_missing_one_is_reported():
	var syncer := _make_syncer()

	syncer.target_property = "not_a_property"

	assert_push_error("has no property 'not_a_property'")

#endregion
