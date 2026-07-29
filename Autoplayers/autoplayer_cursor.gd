extends CanvasLayer
class_name AutoplayerCursor
## A fake mouse pointer drawn on top of everything, so an autoplayer's actions
## can be followed by eye.
##
## It is decoration: it never sends input, it just travels to whatever the player
## is about to act on and flashes when it acts. It keeps moving while the tree is
## paused, since the player can drive windows that pause the game.

## How fast the pointer closes the distance to its target, per second.
const TRAVEL_SPEED:float = 12.0
## How far down the pointer shrinks when it acts, and how fast it springs back.
const CLICK_SCALE:float = 0.7
const CLICK_RECOVERY:float = 6.0

var target_position:Vector2 = Vector2.ZERO

var _body:Node2D
var _click:float = 0.0


func _ready()-> void:
	# The player can act while a window has the tree paused.
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = 128

	_body = Node2D.new()
	add_child(_body)

	# Pointer shape, in pixels, tip at the origin.
	var pointer := PackedVector2Array([
		Vector2(0, 0), Vector2(0, 17), Vector2(4.4, 12.9), Vector2(7.4, 19.5),
		Vector2(10.4, 18.2), Vector2(7.5, 11.9), Vector2(12.6, 11.4)])

	var outline := Polygon2D.new()
	outline.polygon = pointer
	outline.color = Color(0, 0, 0, 0.65)
	outline.scale = Vector2(1.4, 1.4)
	outline.position = Vector2(-1.5, -1.5)
	_body.add_child(outline)

	var fill := Polygon2D.new()
	fill.polygon = pointer
	fill.color = Color(1, 0.95, 0.4, 0.95)
	_body.add_child(fill)

	_body.position = target_position


## Sends the pointer travelling towards a point in window space.
func move_to(position:Vector2)-> void:
	target_position = position


## Plays the press flash, for when the player actually acts on something.
func click()-> void:
	_click = 1.0


func _process(delta:float)-> void:
	if _body == null: return

	var travel:float = clampf(TRAVEL_SPEED * delta, 0.0, 1.0)
	_body.position = _body.position.lerp(target_position, travel)

	_click = move_toward(_click, 0.0, CLICK_RECOVERY * delta)
	_body.scale = Vector2.ONE * lerpf(1.0, CLICK_SCALE, _click)
