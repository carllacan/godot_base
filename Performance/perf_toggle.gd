extends RefCounted
class_name PerfToggle
## One reversible change to the running game, for bisecting where a frame goes.
##
## Changes are made through change(), which records the previous value, so undo
## restores exactly what was altered and nothing else. That is not tidiness --
## a toggle that blindly sets things back to a guessed default switches ON nodes
## that shipped hidden, and then measures a heavier scene than the one it was
## asked about. Recording is what makes "off" mean "off from wherever it was".

## Stable identifier, used by the --perf command line switch. Keep it short.
var id:String
## What the panel shows.
var label:String
## Keyboard shortcut number, or -1 for no shortcut. Slots 0-6 are GodotBase's;
## 7-9 are left for the project, so adding a toggle here never renumbers
## somebody else's muscle memory.
var slot:int = -1

## Called to put the change in place. Receives this toggle, and should route
## every modification through change() so it can be undone.
var apply:Callable
## Optional extra teardown for anything that is not a property -- a method call
## on a server, say. Recorded property changes are restored either way.
var undo:Callable

var active:bool = false
## Set when apply() ran but found nothing to act on. A toggle that silently does
## nothing is worse than one that fails: it produces a confident false negative.
var missing_targets:bool = false

var _changes:Array[Dictionary] = []


func _init(toggle_id:String, toggle_label:String, on_apply:Callable,
		shortcut_slot:int = -1, on_undo:Callable = Callable())-> void:
	id = toggle_id
	label = toggle_label
	apply = on_apply
	slot = shortcut_slot
	undo = on_undo


## Sets a property, remembering what it was. The only sanctioned way for an
## apply() to change anything.
func change(object:Object, property:String, value:Variant)-> void:
	if object == null or not is_instance_valid(object): return
	_changes.append({
		"object": object, "property": property, "old": object.get(property)})
	object.set(property, value)


## How many distinct objects this toggle is currently acting on. Shown in the
## panel so "lights off (0)" cannot be mistaken for "lights off, no difference".
func target_count()-> int:
	var objects:Dictionary = {}
	for change_record in _changes:
		objects[change_record["object"]] = true
	return objects.size()


func activate()-> void:
	if active: return
	_changes.clear()
	apply.call(self)
	missing_targets = _changes.is_empty()
	active = true


func deactivate()-> void:
	if not active: return
	# Reverse order, so a property written twice ends up back at its original
	# value rather than at the intermediate one.
	for i in range(_changes.size() - 1, -1, -1):
		var change_record:Dictionary = _changes[i]
		if is_instance_valid(change_record["object"]):
			change_record["object"].set(
				change_record["property"], change_record["old"])
	_changes.clear()

	if undo.is_valid(): undo.call(self)

	active = false
	missing_targets = false


## Drops the recorded changes without restoring them. For when the nodes they
## refer to are gone -- a scene rebuild -- and restoring would be meaningless.
func forget()-> void:
	_changes.clear()
	active = false
	missing_targets = false
