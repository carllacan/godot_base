extends Node
class_name BaseComponent
## Base class for a node whose job is to modify another node, usually the parent
## it is attached to.
##
## [b]Not [code]@tool[/code] itself:[/b] the annotation is not inherited, so it
## would buy nothing here while making every subclass that lacks it emit a
## MISSING_TOOL warning. A component that wants [method _get_configuration_warnings]
## to reach the editor declares [code]@tool[/code] on its own script.
##
## A component is added as a child of the node it acts on, so behaviour is
## composed in the scene tree instead of by inheritance: the same [Button]
## becomes a navigation link, a fading label or a setting control depending on
## which components hang off it.
## [br][br]
## Subclasses hook in through [method _on_parent_ready] rather than
## [method Node._ready]. Children are ready before their parent, so at
## [method Node._ready] time the target has not run its own [method Node._ready]
## yet — anything that reads or connects to the target belongs in
## [method _on_parent_ready].
## [br][br]
## [b]Editor safety:[/b] a component only runs in the editor when its own script
## declares [code]@tool[/code], and one that does is responsible for guarding its
## own edit-time behaviour with [method Engine.is_editor_hint]. This matters more
## than it looks: a component that writes to its target at edit time has those
## writes serialised into the scene the next time it is saved, silently replacing
## whatever the scene was authored with.

## Points the component at a node other than its parent. Leave empty for the
## usual case, where the parent is the target.
##
## Named an override rather than "target" on purpose: it holds only what the
## scene explicitly set, so it is empty far more often than not. Everything that
## wants the node being acted on calls [method get_target].
@export var target_override:Node

## Whether the component does its work. What that means is up to each subclass;
## on its own this only drives the processing callbacks selected below.
@export var enabled:bool = true : set = set_enabled

@export_group("Enabled")
## If [code]true[/code], [member enabled] switches [method Node._process] on and
## off. Off by default so that inheriting from this class cannot change when an
## existing component processes.
@export var enabled_controls_process:bool = false : set = set_enabled_controls_process
## As [member enabled_controls_process], for [method Node._physics_process].
@export var enabled_controls_physics_process:bool = false : set = set_enabled_controls_physics_process

@export_group("Debug")
## Print what this component does, through [method p].
@export var verbose:bool = false


## The node this component acts on: [member target_override] when one is set,
## the parent otherwise.
##
## Deliberately not cached. Measured on 4.7, [method Node.get_parent] costs about
## 38 ns more per call than reading a cached variable, and nothing here calls it
## in an inner loop — some ten calls a frame across twenty components comes to
## roughly 7 us, or 0.05% of a 16 ms frame. Caching would buy none of that back
## and would go stale the first time anything reparented a component.
func get_target()-> Node:
	return target_override if target_override != null else get_parent()


## Override to declare what this component may be attached to. Reported as an
## error at runtime and as a configuration warning in the editor.
func _is_parent_valid()-> bool:
	return true


## Override to describe a valid parent, e.g. [code]"a Button"[/code], so the
## error and the configuration warning can say something useful.
func _get_parent_requirement()-> String:
	return ""


## Called once the target has finished its own [method Node._ready]. Connections
## to the target's signals belong here.
func _on_parent_ready()-> void:
	pass


## Prints [param msg] when [member verbose] is on, labelled with the component's
## name. [param args] is applied to [param msg] as a format string, so that the
## interpolation does not happen at all while verbose is off.
func p(msg:String, args:Array = [])-> void:
	if not verbose: return
	print("[%s] %s" % [_get_component_name(), msg if args.is_empty() else msg % args])


func _notification(what:int)-> void:
	# GDScript calls _notification for every script in the inheritance chain,
	# base first, so this still runs when a subclass defines _ready without
	# calling super(). It lands *after* that subclass _ready though, so nothing
	# set up here may be relied on from there.
	match what:
		NOTIFICATION_READY:
			_base_ready()
		NOTIFICATION_PARENTED, NOTIFICATION_UNPARENTED:
			update_configuration_warnings()


func _base_ready()-> void:
	_apply_enabled()

	var parent:Node = get_parent()
	if parent == null: return

	if not _is_parent_valid():
		push_error(_get_invalid_parent_message())

	# A component added to an already ready parent would otherwise wait forever
	# for a signal that has been emitted before it could connect to it.
	if parent.is_node_ready():
		_on_parent_ready.call_deferred()
	else:
		parent.ready.connect(_on_parent_ready)


func set_enabled(value:bool)-> void:
	if enabled == value: return
	enabled = value
	_apply_enabled()


func set_enabled_controls_process(value:bool)-> void:
	if enabled_controls_process == value: return
	enabled_controls_process = value
	_apply_enabled()


func set_enabled_controls_physics_process(value:bool)-> void:
	if enabled_controls_physics_process == value: return
	enabled_controls_physics_process = value
	_apply_enabled()


## Applies [member enabled] to the processing callbacks it was told to control.
## Only the callbacks whose flag is set are touched, so a component that manages
## its own processing keeps doing so.
func _apply_enabled()-> void:
	if not is_inside_tree(): return

	if enabled_controls_process:
		set_process(enabled)
	if enabled_controls_physics_process:
		set_physics_process(enabled)


func _get_configuration_warnings()-> PackedStringArray:
	var warnings:PackedStringArray = []

	if get_parent() == null:
		return warnings
	if not _is_parent_valid():
		warnings.append(_get_invalid_parent_message())

	return warnings


func _get_invalid_parent_message()-> String:
	var requirement:String = _get_parent_requirement()
	var tail:String = "" if requirement == "" else ", it must be a child of %s" % requirement
	return "%s cannot be attached to a %s%s" % [
		_get_component_name(), get_parent().get_class(), tail
	]


## How this component is labelled in errors and verbose output: its class_name
## when it has one, its node name otherwise.
func _get_component_name()-> String:
	var script:Script = get_script()
	if script == null: return name

	var global_name:StringName = script.get_global_name()
	return global_name if global_name != &"" else name
