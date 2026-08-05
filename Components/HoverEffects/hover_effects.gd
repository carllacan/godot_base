@tool
extends BaseComponent
class_name HoverEffects
## Tints a [Control] while the pointer is over it, and optionally while it holds
## focus.
##
## Add this as a direct child of the [Control] it should affect. Hovering
## multiplies the target's [member CanvasItem.modulate] by
## [member modulate_factor], and leaving restores it, so a button gets a
## rollover without touching its theme or writing a script for it:
## [codeblock]
## DecreaseLevelButton
##  |- HoverEffects
##       on_focus = true
## [/codeblock]
## Pointer and focus are tracked separately but produce the same tint: the
## target is tinted while either applies, and returns to normal only when
## neither does.
## [br][br]
## [b]The tint is a multiplier, not a replacement.[/b] The target's own modulate
## is read once, when it becomes ready, and every tint is computed from that
## value. So a target that is already tinted keeps its tint and is dimmed
## relative to it — but anything that changes the target's modulate afterwards
## is overwritten the next time the hover or focus state changes. Drive a
## target's modulate from here or from elsewhere, never from both.


## Tint while the pointer is over the target.
@export var on_hover:bool = true
## Tint while the target holds keyboard or gamepad focus. Off by default, though
## worth setting on anything reachable by gamepad, so that moving the focus is
## as visible as moving the mouse.
@export var on_focus:bool = false
## Multiplied into the target's original modulate to produce the tint. The
## default leaves the colour alone and takes the alpha to 80%, so it dims rather
## than recolours.
@export var modulate_factor:Color = Color(1.0, 1.0, 1.0, 0.8)

## The target's modulate as it was when the target became ready. Every tint is
## computed from this, and it is what the target is restored to.
var original_modulate:Color

## Whether the pointer is over the target right now. Stays [code]false[/code]
## while [member on_hover] is off.
var is_parent_hovered:bool = false : set = set_is_parent_hovered
## Whether the target holds focus right now. Stays [code]false[/code] while
## [member on_focus] is off.
var is_parent_focused:bool = false : set = set_is_parent_focused


func set_is_parent_hovered(new_value:bool)-> void:
	is_parent_hovered = new_value
	update_effects()
	
	
func set_is_parent_focused(new_value:bool)-> void:
	is_parent_focused = new_value
	update_effects()
	
	
func _on_parent_ready()-> void:
	# Hovering the target would tint it, and the editor would serialize that
	# modulate into the scene.
	if Engine.is_editor_hint(): return

	var t := get_target()
	# Captured here rather than at _ready: the target has run its own _ready by
	# now, so this is the modulate it actually starts out with.
	original_modulate = t.modulate

	# TODO: the bound target is never read by any of the four handlers. Either
	# drop the bind and the unused parameter, or use it to let one component
	# watch several controls.
	t.mouse_entered.connect(_on_mouse_entered_target_control.bind(t))
	t.mouse_exited.connect(_on_mouse_exited_target_control.bind(t))
	t.focus_entered.connect(_on_focus_entered_target_control.bind(t))
	t.focus_exited.connect(_on_focus_exited_target_control.bind(t))
		
	
func _on_mouse_entered_target_control(_control:Control)-> void:
	if not on_hover: return
	is_parent_hovered = true
		
		
func _on_mouse_exited_target_control(_control:Control)-> void:
	if not on_hover: return
	is_parent_hovered = false
		
		
func _on_focus_entered_target_control(_control:Control)-> void:
	if not on_focus: return
	is_parent_focused = true
	
	
func _on_focus_exited_target_control(_control:Control)-> void:
	if not on_focus: return
	is_parent_focused = false
		
		
## Applies or removes the tint to match the current hover and focus state.
## Called on every change to either; safe to call at any time.
func update_effects()-> void:
	if Engine.is_editor_hint(): return

	if is_parent_hovered or is_parent_focused:
		get_target().modulate = original_modulate*modulate_factor
	else:
		get_target().modulate = original_modulate


func _is_parent_valid()-> bool:
	return get_target() is Control


func _get_parent_requirement()-> String:
	return "a Control"
