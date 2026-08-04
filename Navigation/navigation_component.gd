extends Node
class_name NavigationComponent
## Turns a [Button] into a menu-screen navigation link: pressing it hides one set
## of nodes and shows another.
##
## Add this as a [b]direct child of a [Button][/b]. When that button is pressed
## (or when [member action_shortcut] is triggered) every node in
## [member to_hide] is hidden and every node in [member to_show] is shown, then
## [signal performed] is emitted.
## [br][br]
## This is meant for menus built as sibling screens under a common parent, where
## exactly one screen is visible at a time. Each button that moves between two
## screens gets one of these:
## [codeblock]
## SettingsControls
##  |- SettingsMainMenu          (visible)
##  |   |- GraphicSettingsButton
##  |       |- ToGraphicSettings (NavigationComponent)
##  |             to_hide = [../..]              -> SettingsMainMenu
##  |             to_show = [../../../Graphics]  -> GraphicSettings
##  |- GraphicSettings           (hidden)
##      |- BackButton
##          |- BackToMainSettings (NavigationComponent)
##                to_hide = [../..]
##                to_show = [../../../SettingsMainMenu]
##                action_shortcut = "ui_cancel"
## [/codeblock]
## Set [member action_shortcut] to an [InputMap] action name to also reach the
## navigation via the keyboard/gamepad — typically [code]"ui_cancel"[/code] on
## back buttons. Leave it empty for forward navigation, which should only be
## reachable by pressing the button.
## [br][br]
## The shortcut only fires when [method can_perform] is true, i.e. when the
## navigation is not already in its destination state: every node in
## [member to_show] must currently be invisible and every node in
## [member to_hide] must currently be visible. This is what keeps several
## components sharing [code]"ui_cancel"[/code] from all reacting to the same
## press — only the one on the currently-open screen matches. Consuming the
## event is left to whichever component acts first, so two components that can
## both perform on the same action are a scene-authoring mistake.
## [br][br]
## Nodes are hidden before they are shown, which matters when a [FocusManager]
## is watching them: the outgoing screen releases focus before the incoming one
## grabs it. Do not swap the [method perform_hide] / [method perform_show] calls
## in [method perform_navigation].
## [br][br]
## [member hide_on_ready] and [member show_on_ready] let the components declare
## the menu's initial state instead of it being hand-maintained as [code]visible[/code]
## flags across the scene. With the defaults, every component hides its
## [member to_hide] once the parent button is ready, so the screens collapse to
## whatever the [member show_on_ready] component opts into. Exactly one component
## per menu should set [member show_on_ready].
## [br][br]
## [b]Note:[/b] entries are stored as [NodePath]s, so a sub-scene may ship with a
## [code]null[/code] placeholder in [member to_show] that each instancing scene
## overrides with the real destination.

signal performed

## Nodes hidden when the navigation is performed. Usually the screen the parent
## button lives on, e.g. [code][NodePath("../..")][/code].
@export var to_hide:Array[Node]
## Nodes shown when the navigation is performed — the destination screen.
@export var to_show:Array[Node]
## Name of an [InputMap] action that also triggers this navigation, or
## [code]""[/code] for button-press only. Only fires when [method can_perform].
@export var action_shortcut:String = ""

## If [code]true[/code], hide [member to_hide] as soon as the parent button is
## ready, so the menu's closed state is declared by the components themselves.
@export var hide_on_ready:bool = true
## If [code]true[/code], also show [member to_show] on ready. Set this on the one
## component per menu whose destination is the screen that starts open.
@export var show_on_ready:bool = false

@export_group("Debug")
## Print every hide/show this component performs to the console.
@export var verbose:bool = false


func _ready()-> void:
	var parent = get_parent()
	parent.ready.connect(_on_parent_ready)
	
	if null in to_hide or null in to_show:
		push_error("Null references in '%s'" % get_path())
	
	if parent is Button:
		parent.pressed.connect(_on_parent_button_pressed)
	else:
		push_error("Unexpected parent type")
		

func p(msg:String)-> void:
	if not verbose: return
	print("[Navigation] " + msg)
	
	
func _on_parent_ready()-> void:
	if hide_on_ready:
		perform_hide()
	if show_on_ready:
		perform_show()


func _on_parent_button_pressed()-> void:
	perform_navigation()
	
	
func perform_navigation()-> void:
	perform_hide()
	perform_show()
	performed.emit()
	
	
func perform_hide()-> void:
	p("%s hiding" % get_parent().name)
	for node in to_hide:
		p("%s hides node %s" % [get_parent().name, node.name])
		node.hide()
		
		
func perform_show()-> void:
	p("%s showing" % get_parent().name)
	for node in to_show:
		p("%s shows node %s" % [get_parent().name, node.name])
		node.show()
		
	
func can_perform()-> bool:
	if not is_node_ready(): return false
	
	# check if any of the elements that must be shown is already visible
	if to_show.any(func(n): return n.visible): 
		return false
	# check if any of the elements that must be shown is already invisible
	if to_hide.any(func(n): return not n.visible): 
		return false
		
	return true
		

func _input(event: InputEvent) -> void:
	if action_shortcut == "": return
	if not can_perform(): 
		return
	
	if event.is_action_pressed(action_shortcut):
		get_viewport().set_input_as_handled()
		perform_navigation()
