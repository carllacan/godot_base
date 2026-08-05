@tool
extends PropertyAnimator
class_name SpritesheetRunner
## Runs a [Sprite2D] once through the frames of its spritesheet.
##
## Add this as a direct child of the sprite. The frame count is read off the
## sprite's own [member Sprite2D.hframes] and [member Sprite2D.vframes], so the
## sheet is described in one place only, and [member period] sets how long the
## whole run takes.
## [br][br]
## This is a [PropertyAnimator] configured for the job: it steps
## [member Sprite2D.frame] from the first frame to the last, holds each one for
## the same slice of the run, and stops on the last frame rather than looping.
## [br][br]
## [b]The inherited animation properties are derived, not authored.[/b]
## [member property], [member mode], [member loop], [member min_value],
## [member max_value] and [member steps] are all written from the sheet once the
## sprite is ready, so setting them in the inspector has no effect. The ones
## worth touching are [member period], [member autostart], and the two below.
## [br][br]
## [member frame_start] and [member frame_end] narrow the run to part of a
## sheet, which is how one sheet can hold several animations:
## [codeblock]
## Sprite2D                 hframes = 8, vframes = 2
##  |- SpritesheetRunner    frame_start = 8, frame_end = 15
##                          -> runs the second row only
## [/codeblock]

## First frame of the run.
@export var frame_start:int = 0 : set = set_frame_start
## Last frame of the run. Leave at [code]-1[/code] to run to the end of the sheet.
@export var frame_end:int = -1 : set = set_frame_end


func _on_parent_ready()-> void:
	# The inherited exports are derived from the sheet rather than authored, so
	# they are only ever written at runtime. The editor never sees them and so
	# never serializes them into the scene.
	if Engine.is_editor_hint(): return

	apply_sheet()
	play_entire_sheet()


func _is_parent_valid()-> bool:
	return get_target() is Sprite2D


func _get_parent_requirement()-> String:
	return "a Sprite2D"


func set_frame_start(value:int)-> void:
	frame_start = value
	if is_node_ready() and not Engine.is_editor_hint():
		apply_sheet()


func set_frame_end(value:int)-> void:
	frame_end = value
	if is_node_ready() and not Engine.is_editor_hint():
		apply_sheet()


## Frames in the sheet, counting both axes. [member Sprite2D.frame] indexes the
## whole grid row by row, so a sheet is as long as its two dimensions multiplied.
func get_frame_count()-> int:
	var sprite := get_target() as Sprite2D
	if sprite == null: return 0
	return sprite.hframes * sprite.vframes


## The last frame the run will reach, resolving the [code]-1[/code] default and
## clamping anything outside the sheet.
func get_last_frame()-> int:
	var total:int = get_frame_count()
	if total <= 0: return 0

	var last:int = frame_end if frame_end >= 0 else total - 1
	return clampi(last, 0, total - 1)


## The first frame the run will start from, clamped so it never passes the last.
func get_first_frame()-> int:
	return clampi(frame_start, 0, get_last_frame())


## Points the inherited animator at this sheet's frames. Called when the sprite
## becomes ready and whenever the run's bounds change.
func apply_sheet()-> void:
	if get_frame_count() <= 0: return

	var first:int = get_first_frame()
	var last:int = get_last_frame()

	property = "frame"
	mode = Mode.RESTART
	loop = false
	min_value = float(first)
	max_value = float(last)
	steps = last - first + 1


## Runs the sheet from its first frame, after waiting [param offset_s] seconds
## if one is given. Staggering a batch of identical effects keeps them from
## animating in lockstep.
func play_entire_sheet(offset_s:float = 0)-> void:
	if offset_s > 0:
		await get_tree().create_timer(offset_s).timeout
	reset()


## A frame is a whole number, so the interpolated value is rounded rather than
## left for the assignment to truncate — 2.999 is frame 3, not frame 2.
func _refine_value(value:Variant)-> Variant:
	return roundi(value)
