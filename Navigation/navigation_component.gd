@tool
extends BaseComponent
class_name NavigationComponent
## Turns a [Button] into a menu-screen navigation link: pressing it hides one set
## of nodes and shows another.
##
## Add this as a [b]direct child of a [Button][/b]. When that button is pressed,
## every node in [member to_hide] is hidden and every node in [member to_show] is
## shown, then [signal performed] is emitted.
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
##      |- BackButton            shortcut = ui_cancel.tres
##          |- BackToMainSettings (NavigationComponent)
##                to_hide = [../..]
##                to_show = [../../../SettingsMainMenu]
## [/codeblock]
## To also reach a navigation from the keyboard or gamepad — typically
## [kbd]Escape[/kbd] on a back button — do [b]not[/b] add anything here: set
## [member BaseButton.shortcut] on the parent [Button] to a [Shortcut] holding an
## [InputEventAction] with the [InputMap] action you want. [BaseButton] only fires
## a shortcut when the button is [method Node.is_visible_in_tree] and not
## [member BaseButton.disabled], so several back buttons can share one
## [code]ui_cancel[/code] resource and only the one on the currently-open screen
## reacts. It emits [signal BaseButton.pressed] like a real click, so the
## navigation below runs unchanged, and you get the shortcut in the button's
## tooltip and its press highlight for free.
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

## If [code]true[/code], hide [member to_hide] as soon as the parent button is
## ready, so the menu's closed state is declared by the components themselves.
@export var hide_on_ready:bool = true
## If [code]true[/code], also show [member to_show] on ready. Set this on the one
## component per menu whose destination is the screen that starts open.
@export var show_on_ready:bool = false

func _ready()-> void:
	if null in to_hide or null in to_show:
		push_error("Null references in '%s'" % get_path())


func _is_parent_valid()-> bool:
	return get_target() is Button


func _on_parent_ready()-> void:
	# hide_on_ready collapses every screen in the menu. At edit time the editor
	# would serialize that, so opening a menu scene would silently hide half of it.
	if Engine.is_editor_hint(): return

	get_target().pressed.connect(_on_parent_button_pressed)

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
	if Engine.is_editor_hint(): return

	p("%s hiding", [get_target().name])
	for node in to_hide:
		p("%s hides node %s", [get_target().name, node.name])
		node.hide()


func perform_show()-> void:
	if Engine.is_editor_hint(): return

	p("%s showing", [get_target().name])
	for node in to_show:
		p("%s shows node %s", [get_target().name, node.name])
		node.show()
