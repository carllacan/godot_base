@tool
extends BaseComponent
class_name FocusManager
## Gives one screen's worth of [Control]s their keyboard/gamepad focus: focuses
## the screen when it is shown, releases the focus when it is hidden, and
## remembers where the focus was so reopening the screen returns to it.
##
## Add this as a [b]direct child of the [Control] that is the screen[/b] — the
## panel or container the whole menu hangs off, not an individual button. From
## there it watches three things and calls [method focus] / [method unfocus]:
## [br][br]
## - the target's [signal CanvasItem.visibility_changed]: shown focuses,
##   hidden unfocuses. This is the main entry point, and it is what makes a
##   [NavigationComponent] menu move the focus along with the visible screen —
##   see that class about why it hides before it shows.
## [br]
## - [code]InputManager.type_changed[/code], under [member focus_on_joypad] and
##   [member unfocus_on_kbm], so picking up a gamepad puts a focus highlight on
##   screen and touching the mouse takes it away again. Both are off by default
##   and both only fire on a screen that is currently visible, so every closed
##   screen ignores the change.
## [br]
## - the viewport's [signal Viewport.gui_focus_changed], to play
##   [member sound_on_focus_change] when the focus lands on something inside the
##   target. At most one click per frame, so a menu that moves the focus twice
##   in one frame does not stack two sounds.
## [br][br]
## [codeblock]
## PauseWindow            (Control)
##  |- FocusManager       first_focus = [NodePath("../Buttons/Resume")]
##  |                     sound_on_focus_change = [NodePath("../FocusSound")]
##  |- FocusSound         (AudioStreamPlayer)
##  |- Buttons
##      |- Resume
##      |- Settings
##      |- Quit
## [/codeblock]
## Nothing needs to call this: showing and hiding the screen is enough. Both
## [method focus] and [method unfocus] are public for the cases that are not
## about visibility — a modal that hands the focus back to the screen underneath,
## say.
## [br][br]
## [b]Note:[/b] a screen that is already visible when its scene loads never gets
## a [signal CanvasItem.visibility_changed], so it starts unfocused until
## something shows it again or the controller type changes.
## [br][br]
## [b]Note:[/b] this needs the [code]InputManager[/code] autoload, which does not
## exist at edit time, so everything here is inert in the editor.

## The [Control] focused when the screen opens. Leave it empty to open the screen
## with nothing focused. It should be a descendant of the target with a
## [member Control.focus_mode] that allows focus, or [method Control.grab_focus]
## warns and nothing happens.
@export var first_focus:Control
## If [code]true[/code], reopening the screen returns the focus to whatever held
## it when the screen closed, instead of going back to [member first_focus].
## Turn it off for screens that should always open on the same control.
@export var persist_focus:bool = true
## If [code]true[/code], switching to a gamepad focuses this screen while it is
## visible. Set it on the screen that should own the focus when the player picks
## up a controller — if two visible screens both set it, the last one to react
## wins.
@export var focus_on_joypad:bool = false
## If [code]true[/code], switching to mouse or keyboard clears the focus on this
## screen while it is visible, so no stale focus highlight is left sitting under
## the cursor.
@export var unfocus_on_kbm:bool = false
@export_group("Focus change")
## Played whenever the focus moves onto a control inside the target, at most once
## per frame. Leave it empty for a silent screen.
@export var sound_on_focus_change:AudioStreamPlayer

## Guards [member sound_on_focus_change] against playing several times in a
## frame. Cleared one process frame after it is raised.
var focus_change_played_this_frame:bool = false
## Where [member persist_focus] keeps the focus between closing and reopening the
## screen. Whatever held the focus at the moment of the last [method unfocus],
## which is [code]null[/code] if that was nothing.
var last_focused_control:Control


func _ready()-> void:
	# InputManager is an autoload, so it does not exist at edit time.
	if Engine.is_editor_hint(): return

	InputManager.type_changed.connect(_on_input_type_changed)


func _on_parent_ready()-> void:
	# Grabbing or releasing focus at edit time would fight the editor's own
	# focus handling, so nothing is wired up there.
	if Engine.is_editor_hint(): return

	var t := get_target()
	t.visibility_changed.connect(_on_parent_visibility_changed)
	t.get_viewport().gui_focus_changed.connect(_on_focus_changed)


func _is_parent_valid()-> bool:
	return get_target() is Control


func _on_focus_changed(_receiver:Control)-> void:
	if not get_target().is_visible_in_tree(): return

	if not focus_change_played_this_frame:
		if sound_on_focus_change != null:
			if get_target().is_ancestor_of(_receiver):
				sound_on_focus_change.play()
				focus_change_played_this_frame = true
				await get_tree().process_frame
				focus_change_played_this_frame = false
	
	
func focus()-> void:
	var to_focus:Control
	if persist_focus and last_focused_control != null:
		to_focus = last_focused_control
	else:
		if first_focus != null:
			to_focus = first_focus
			
	if to_focus != null:
		#print("Focusing control '%s'" % to_focus)
		to_focus.grab_focus()
	
	
func unfocus()-> void:
	if persist_focus:
		last_focused_control = get_viewport().gui_get_focus_owner()
		#print("Last focused control: '%s'" % last_focused_control)
	get_viewport().gui_release_focus()
	
	
	
func _on_input_type_changed(_new_type)-> void:
	match InputManager.current_controller_type:
		InputManager.ControllerTypes.KBM:
			if unfocus_on_kbm and get_target().is_visible_in_tree():
				unfocus()
		InputManager.ControllerTypes.JOYPAD:
			if focus_on_joypad and get_target().is_visible_in_tree():
				focus()


func _on_parent_visibility_changed()-> void:
	var t := get_target()

	if t.is_visible_in_tree(): # if was SHOWN
		focus()
		focus_change_played_this_frame = true
		await get_tree().process_frame
		focus_change_played_this_frame = false
	else: # if it was HIDDEN
		unfocus()
