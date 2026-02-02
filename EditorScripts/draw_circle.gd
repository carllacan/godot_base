@tool
extends EditorScript

# -------- CONFIG --------
var radius := 128
var line_width := 10
var dot_angle := 0.45
var gap_angle := 0.25
var resolution := 12
var output_path := "res://dotted_circle.png"
var color := Color.WHITE
var rounded_caps := true
# ------------------------

func _run():
	var size := int(radius * 2 + line_width * 2)
	var center := Vector2(size / 2, size / 2)

	var img := Image.create(size, size, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))

	# --- enforce perfect tiling ---
	var pattern := dot_angle + gap_angle
	var count := int(round(TAU / pattern))
	var scaled_pattern := TAU / count
	var scaled_dot := scaled_pattern * (dot_angle / pattern)
	var scaled_gap := scaled_pattern * (gap_angle / pattern)

	var angle := 0.0

	for i in range(count):
		_draw_arc(img, center, radius, angle, angle + scaled_dot)
		angle += scaled_dot + scaled_gap

	img.save_png(output_path)
	print("Saved dotted circle to ", output_path)

# ------------------------------------------------------------

func _draw_arc(img: Image, center: Vector2, r: float, from: float, to: float):
	for i in range(resolution + 1):
		var t := i / float(resolution)
		var a:float = lerp(from, to, t)
		var pos := center + Vector2(cos(a), sin(a)) * r
		_draw_brush(img, pos)

	# Square caps need a final stamp to avoid rounding
	if not rounded_caps:
		var start_pos := center + Vector2(cos(from), sin(from)) * r
		var end_pos := center + Vector2(cos(to), sin(to)) * r
		_draw_square(img, start_pos)
		_draw_square(img, end_pos)

func _draw_brush(img: Image, pos: Vector2):
	if rounded_caps:
		_draw_circle(img, pos, line_width * 0.5)
	else:
		_draw_square(img, pos)

func _draw_square(img: Image, pos: Vector2):
	var half := line_width * 0.5
	for y in range(int(pos.y - half), int(pos.y + half) + 1):
		for x in range(int(pos.x - half), int(pos.x + half) + 1):
			if x >= 0 and y >= 0 and x < img.get_width() and y < img.get_height():
				img.set_pixel(x, y, color)

func _draw_circle(img: Image, pos: Vector2, r: float):
	var min_x := int(pos.x - r)
	var max_x := int(pos.x + r)
	var min_y := int(pos.y - r)
	var max_y := int(pos.y + r)

	for y in range(min_y, max_y + 1):
		for x in range(min_x, max_x + 1):
			if x < 0 or y < 0 or x >= img.get_width() or y >= img.get_height():
				continue
			if Vector2(x + 0.5, y + 0.5).distance_to(pos) <= r:
				img.set_pixel(x, y, color)
