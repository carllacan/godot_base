@tool
extends CollisionPolygon2D
class_name ArcCollisionPolygon2D

## Procedurally generates a CollisionPolygon2D shaped as a circle, arc, ring,
## or arc segment. Updates live in the editor when any export property changes.
##
## Special cases:
##   - angular_width == TAU and width == radius → filled circle (perimeter only, no center point)
##   - angular_width == TAU and 0 < width < radius → ring (near-full arc, gap < 0.02 px)
##   - width == 0 → BUILD_SEGMENTS mode (1D edges, no fill)

const MIN_SOLID_POINTS: int = 3
const MIN_SEGMENT_POINTS: int = 2

## Outer radius of the arc.
@export var radius: float = 100.0:
	set(v):
		radius = v
		_regenerate()

## Radial thickness of the arc. Set to 0 for segment (1D) mode,
## or equal to radius for a fully filled circle.
@export var width: float = 10.0:
	set(v):
		width = v
		_regenerate()

## Angular span of the arc in radians. Clamped to [0, TAU].
@export_range(0, 360, 0.1, "radians_as_degrees") var angular_width: float = TAU:
	set(v):
		angular_width = clamp(v, 0.0, TAU)
		_regenerate()

## Angle at which the arc begins, in radians.
@export_range(0, 360, 0.1, "radians_as_degrees") var starting_angle: float = 0.0:
	set(v):
		starting_angle = v
		_regenerate()

## How many polygon points are generated per pixel of arc perimeter.
## Higher values produce smoother shapes at the cost of physics performance.
## A minimum of 3 points (solids) or 2 points (segments) is always enforced.
@export var points_per_px: float = 0.1:
	set(v):
		points_per_px = v
		_regenerate()


func _ready() -> void:
	_regenerate()


func _regenerate() -> void:
	if not is_node_ready():
		return

	var clamped_width: float = clamp(width, 0.0, radius)
	var is_full_circle: bool = is_equal_approx(angular_width, TAU)
	var is_segment_mode: bool = is_zero_approx(clamped_width)

	if is_segment_mode:
		build_mode = BUILD_SEGMENTS
		polygon = _generate_segment_polygon(is_full_circle)
	elif is_full_circle and is_equal_approx(clamped_width, radius):
		build_mode = BUILD_SOLIDS
		polygon = _generate_filled_circle()
	else:
		build_mode = BUILD_SOLIDS
		# For full rings (360°, width < radius), a slit polygon leaves a small physical
		# gap where the polygon's two radial closure edges don't perfectly align. Instead,
		# use TAU - ε so the arc's two cap edges are nearly coincident — the resulting
		# slit is < 0.02 px wide at typical radii, too narrow for any ball to pass through.
		var effective_angle: float = TAU - 1e-4 if is_full_circle else angular_width
		polygon = _generate_arc(clamped_width, effective_angle)


# Returns how many points to use for an arc of the given angle and radius,
# respecting points_per_px and clamping to the required minimum.
func _point_count(arc_angle: float, r: float, min_count: int) -> int:
	var count: int = int(ceil(arc_angle * r * points_per_px))
	if count < min_count:
		push_warning(
			"ArcCollisionPolygon2D: computed %d points for arc (radius=%.1f, angle=%.3f, points_per_px=%.4f). Clamping to minimum of %d. Consider increasing points_per_px." \
			% [count, r, arc_angle, points_per_px, min_count]
		)
		return min_count
	return count


# Generates n evenly-spaced points along an arc from start_a to end_a at radius r.
# include_endpoint=true  → both start and end angles are included (for open arcs).
# include_endpoint=false → end angle is excluded (for full circles, avoids duplicating
#                          the point that the implicit polygon closure already provides).
func _arc_points(start_a: float, end_a: float, r: float, n: int, include_endpoint: bool) -> PackedVector2Array:
	var pts := PackedVector2Array()
	pts.resize(n)
	var denom: float = float(n - 1) if include_endpoint else float(n)
	for i in range(n):
		var a: float = start_a + (end_a - start_a) * float(i) / denom
		pts[i] = Vector2(cos(a), sin(a)) * r
	return pts


# For open arcs in segment mode, the implicit chain closure (last point → first point)
# would create an unwanted chord across the arc gap. This converts [p0,p1,p2,...,pN]
# into [p0,p1, p1,p2, p2,p3, ..., p(N-1),pN] so each segment is an explicit pair,
# preventing any implicit closure from contributing geometry.
func _pairs_from_arc(pts: PackedVector2Array) -> PackedVector2Array:
	var n := pts.size()
	var result := PackedVector2Array()
	result.resize((n - 1) * 2)
	for i in range(n - 1):
		result[i * 2] = pts[i]
		result[i * 2 + 1] = pts[i + 1]
	return result


func _generate_segment_polygon(is_full_circle: bool) -> PackedVector2Array:
	var n := _point_count(angular_width, radius, MIN_SEGMENT_POINTS)
	if is_full_circle:
		# The implicit chain closure (p(N-1) → p0) naturally completes the circle.
		return _arc_points(starting_angle, starting_angle + TAU, radius, n, false)
	else:
		# Use explicit pairs to avoid the closing chord.
		var pts := _arc_points(starting_angle, starting_angle + angular_width, radius, n, true)
		return _pairs_from_arc(pts)


func _generate_filled_circle() -> PackedVector2Array:
	# Full circle, width == radius: only perimeter points are needed.
	# The polygon fill covers the interior without a center point.
	var n := _point_count(TAU, radius, MIN_SOLID_POINTS)
	return _arc_points(starting_angle, starting_angle + TAU, radius, n, false)


func _generate_arc(clamped_width: float, arc_angle: float) -> PackedVector2Array:
	# Solid arc. Caps are formed implicitly by the polygon edges:
	#   end cap:   outer[-1] → inner[-1]  (explicit, last outer to first reversed inner)
	#   start cap: inner[0]  → outer[0]   (implicit polygon closure)
	var inner_radius: float = radius - clamped_width
	var end_angle: float = starting_angle + arc_angle
	var n_outer: int = _point_count(arc_angle, radius, MIN_SOLID_POINTS)
	var n_inner: int = _point_count(arc_angle, inner_radius, MIN_SOLID_POINTS)

	var outer := _arc_points(starting_angle, end_angle, radius, n_outer, true)
	var inner := _arc_points(starting_angle, end_angle, inner_radius, n_inner, true)

	var result := PackedVector2Array()
	result.append_array(outer)
	for i in range(n_inner - 1, -1, -1):
		result.append(inner[i])
	return result
