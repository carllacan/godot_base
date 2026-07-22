extends Node
class_name Utils

const RPM_TO_RADS:float = TAU/60
const RADS_TO_RPM:float = 1.0/RPM_TO_RADS

const WHITESPACE = " ¶\n"

#region Suffixes

## Abbreviated suffixes: K, M, B, T, Qa, Qi, Sx, Sp, Oc, No, Dc
const ABB_SUFFIXES: Dictionary[float, String] = {
	1e33: "Dc",  # decillion
	1e30: "No",  # nonillion
	1e27: "Oc",  # octillion
	1e24: "Sp",  # septillion
	1e21: "Sx",  # sextillion
	1e18: "Qi",  # quintillion
	1e15: "Qa",  # quadrillion
	1e12: "T",   # trillion
	1e9:  "B",   # billion
	1e6:  "M",   # million
	1e3:  "K",   # thousand
}

## Standard SI prefixes: k, M, G, T, P, E, Z, Y, R, Q
const SI_SUFFIXES: Dictionary[float, String] = {
	1e30: "Q",   # quetta
	1e27: "R",   # ronna
	1e24: "Y",   # yotta
	1e21: "Z",   # zetta
	1e18: "E",   # exa
	1e15: "P",   # peta
	1e12: "T",   # tera
	1e9:  "G",   # giga
	1e6:  "M",   # mega
	1e3:  "k",   # kilo
}

## Scientific notation suffixes: e3, e6, e9, ...
const SCI_SUFFIXES: Dictionary[float, String] = {
	1e33: "e33",
	1e30: "e30",
	1e27: "e27",
	1e24: "e24",
	1e21: "e21",
	1e18: "e18",
	1e15: "e15",
	1e12: "e12",
	1e9:  "e9",
	1e6:  "e6",
	1e3:  "e3",
}

#endregion

## Returns a copy of an array with no duplicate elements
static func unique(array:Array)-> Array:
	var unique_values:Array = []
	
	for element in array:
		if not element in unique_values:
			unique_values.append(element)
			
	return unique_values


static func sum_array(a:Array)-> float:
	var acc = 0
	for n in a:
		assert(n is float or n is int)
		acc += n
	return acc
	
	
static func staircase(x: float, step_width: float, step_height: float) -> float:
	if step_width == 0.0:
		push_error("step_width cannot be 0")
		return 0.0
	
	return floor(x / step_width) * step_height


static func angle_distance(angle1:float, angle2:float)-> float:
	return Vector2.from_angle(angle1).angle_to(Vector2.from_angle(angle2))
	
	
static func angle_distance_deg(angle1:float, angle2:float)-> float:
	#print("angle1: %s, angle2: %s, distance: %s" % [
		#angle1, angle2, rad_to_deg(angle_difference(deg_to_rad(angle1), deg_to_rad(angle2)))
	#])
	return rad_to_deg(angle_distance(deg_to_rad(angle1), deg_to_rad(angle2)))
	

static func correct_target_angle(current_angle:float, target_angle:float)-> float:
	var corrected_target:float
	
	if target_angle > current_angle + 180:
		corrected_target = target_angle - 360
	elif target_angle < current_angle - 180:
		corrected_target = target_angle + 360
	else:
		corrected_target = target_angle
		
	return corrected_target


static func get_layer_number(layer_name:String)-> int:
	for i in range(1, 21):
		var sn = "layer_names/2d_physics/layer_%d" % i
		var n:String = ProjectSettings.get_setting(sn)
		if n.to_lower() == layer_name.to_lower():
			return i
	return -1

# Splits 'amount' units into at most 'max_bunches' integers as equally as possible
# Ex: bunch(3, 5) = [1, 1, 1, 0, 0]
# Ex: bunch(7, 5) = [2, 2, 1, 1, 1]
# Ex: bunch(70, 8) = [9, 9, 9, 9, 9, 9, 8, 8]
static func bunch(amount:int, max_bunches:int)-> Array[int]:
	assert(amount >= 0, "'amount' must be non-negative")
	assert(max_bunches > 0, "'max_bunches' must be bigger than 1")
	
	var bunches:Array[int] = []
	var left := amount
	
	# optimize with a preliminar division
	if amount > max_bunches:
		@warning_ignore("integer_division")
		var starting_amount:int = amount/max_bunches
		for b in range(max_bunches):
			bunches.append(starting_amount)
		left = amount - starting_amount*max_bunches
			
	while left != 0:
		for i in range(max_bunches):
			if left == 0:
				continue
				
			if len(bunches) <= i:
				bunches.append(0)
				
			bunches[i] += 1
			left -= 1
				
	return bunches
	
## Like RandomNumberGenerator.rand_weighted, but allows using a dictionary that 
## maps options to weights, allows infinite weights, and automatically creates
## an RNG
## * catalog: Dictionary mapping each of the options to its weight
## * catalog_is_sorted
static func rand_weighted(
	catalog:Dictionary, 
	catalog_is_sorted:bool = false,
	rng:RandomNumberGenerator = null
	)-> Variant:
	if len(catalog) == 0:
		return null
	
	# Create a new RNG, if the user hasn't used a custom one
	if rng == null:
		rng = RandomNumberGenerator.new()
		
	# If there are infinite-weighted elements, pick one of them randomly
	var infinite_weighted:Array = []
	for k in catalog.keys():
		if catalog[k] == INF:
			infinite_weighted.append(k)
	if not infinite_weighted.is_empty():
		return infinite_weighted.pick_random()

	# Ensure consistent index-based access to the catalog		
	var keys:Array[Variant] = []
	var values:Array[float] = []
	if catalog_is_sorted:
		# If the catalog has been sorted we can avoid traversing it to maintain
		# consistent access.
		keys = catalog.keys()
		
		values.clear()
		for v in catalog.values():
			values.append(v)
	else:
		# If the catalog is not sorted then we have no guarantee that the element
		# at position X in catalog.keys() corresponds to the element at position X
		# in catalog.values(), so we need to compile two arrays for consistency.
		for k in catalog.keys():
			keys.append(k)
			values.append(catalog[k])
			
		
	var chosen_idx = rng.rand_weighted(values)
	
	return keys[chosen_idx]
	
	
static func rand_bool(probability:float)-> bool:
	if probability < 0 or probability > 1: 
		push_warning("rand_bool called with p %0.2f, not in [0,1]" % probability)
	return randf() < probability
	
	
## Returns a copy of the given array, sorted randomly
static func rand_sort(array:Array)-> Array:
	var d = array.duplicate()
	var random_sort := []
	for i in len(array):
		var chosen_element = d.pick_random()
		d.erase(chosen_element)
		random_sort.append(chosen_element)
	return random_sort
		
		
static func get_magnitude_order(amount:float)-> int:
	var magnitude = 1
	while abs(amount) >= pow(10, magnitude):
		magnitude += 1
	#print("%s is of magnitude order %s" % [amount, magnitude-1])
	return magnitude-1


static func get_rect_segment_intersection(rect: Rect2, inside: Vector2, outside: Vector2) -> Vector2:
	var edges = [
		# Top
		[rect.position, rect.position + Vector2(rect.size.x, 0)],
		# Bottom
		[rect.position + Vector2(0, rect.size.y), rect.position + rect.size],
		# Left
		[rect.position, rect.position + Vector2(0, rect.size.y)],
		# Right
		[rect.position + Vector2(rect.size.x, 0), rect.position + rect.size]
	]
	
	for edge in edges:
		var hit = Geometry2D.segment_intersects_segment(
			inside,
			outside,
			edge[0],
			edge[1]
		)
		
		if hit != null:
			return hit
	
	return Vector2.ZERO
	
	
## Implements a piece-wise linear function 
## thresholds: assumed to be sorted
## slopes: there must be one more than thresholds, to account for the initial slope
static func piecewise_linear(
		x:float,
		thresholds:Array[float],
		slopes:Array[float]
		) -> float:
	assert(not thresholds.is_empty())
	assert(slopes.size() == thresholds.size() + 1)

	if x <= 0:
		return 0
		
	var result:float = 0.0
	var prev_x:float = 0.0

		
	for i in range(thresholds.size()):
		var th:float = thresholds[i]

		if x <= prev_x:
			return result

		var segment_end:float = min(x, th)
		var dx:float = segment_end - prev_x
		result += dx * slopes[i]

		if x <= th:
			return result

		prev_x = th

	# Remaining segment after last threshold
	if x > prev_x:
		result += (x - prev_x) * slopes[slopes.size() - 1]

	return result
	
	
	
static func write_local_file(path:String, bytes:PackedByteArray) -> void:
	var f := FileAccess.open(path, FileAccess.WRITE)
	f.store_buffer(bytes)
	f.close()


static func rstrip_whitespace(original_string:String)-> String:
	return original_string.rstrip(WHITESPACE)
	
	
static func lstrip_whitespace(original_string:String)-> String:
	return original_string.lstrip(WHITESPACE)
	
	

## Transforms the string to a standard form that starts with a capital letter
## and removes all trailing and starting whitespace.
## If final_period is false it removes any existing period at the end (unless
## it ends in ...). If it is true it ensures it finishes with a period.
## Formats a number using RKM notation (IEC 60062): SI prefix symbols act as
## infix decimal markers. e.g. 3547 -> "3k5", 1200000 -> "1M2", 999 -> "999"
## right_hand_figures controls how many digits appear after the infix symbol.
static func format_as_rkm(amount:float, right_hand_figures:int = 1)-> String:
	const THRESHOLDS:Array = [
		[1e12, "T"],
		[1e9,  "B"],
		[1e6,  "M"],
		[1e3,  "k"],
	]

	var sign_str:String = "-" if amount < 0 else ""
	var abs_amount:float = abs(amount)

	for entry in THRESHOLDS:
		var threshold:float = entry[0]
		var symbol:String = entry[1]
		if abs_amount >= threshold:
			var divided:float = abs_amount / threshold
			var integer_part:int = int(divided)
			if right_hand_figures <= 0:
				return "%s%d%s" % [sign_str, integer_part, symbol]
			var frac_digits:int = int((divided - integer_part) * pow(10, right_hand_figures) + 1e-9)
			return "%s%d%s%s" % [sign_str, integer_part, symbol,
				str(frac_digits).pad_zeros(right_hand_figures)]

	return sign_str + str(int(abs_amount))

## TODO: merge with format_number_compact, but probably keep this name
## Formats a number with SI prefix symbols as trailing suffixes and a decimal
## point. e.g. 3547 -> "3.5k", 1200000 -> "1.2M", 999 -> "999"
## right_hand_figures controls decimal places when a suffix is used.
static func format_with_suffix(amount:float, right_hand_figures:int = 1)-> String:
	const THRESHOLDS:Array = [
		[1e12, "T"],
		[1e9,  "B"],
		[1e6,  "M"],
		[1e3,  "k"],
	]

	var sign_str:String = "-" if amount < 0 else ""
	var abs_amount:float = abs(amount)

	for entry in THRESHOLDS:
		var threshold:float = entry[0]
		var symbol:String = entry[1]
		if abs_amount >= threshold:
			var divided:float = abs_amount / threshold
			var factor:float = pow(10, max(right_hand_figures, 0))
			var truncated:float = int(divided * factor) / factor
			if right_hand_figures <= 0:
				return "%s%d%s" % [sign_str, int(truncated), symbol]
			var format_str:String = "%." + str(right_hand_figures) + "f"
			return sign_str + (format_str % truncated) + symbol

	return sign_str + str(int(abs_amount))


static func standardize_string(original:String, final_period:bool = false)-> String:
	if original.is_empty(): return ""
	
	var std = original
	std[0] = std[0].to_upper()
	
	std = rstrip_whitespace(std)
	std = lstrip_whitespace(std)	
	
	if final_period:
		# Ensure it finishes with a period.
		if not std.ends_with("."):
			std += "."
	else:
		# Remove the final period, unless it ends in dot dot dot.
		if std.ends_with("."):
			if not std.ends_with("..."):
				std = std.rstrip(".")
					
	return std



## Returns a compact string representation of a large number using order-of-magnitude suffixes.
## Truncates (does not round) to fit within max_chars, including the suffix character(s).
## Numbers that already fit within max_chars are returned as-is.
static func format_number_compact(value: float, 
	max_chars: int = 6, suffixes:Dictionary[float, String] = ABB_SUFFIXES
	) -> String:
	var plain := str(int(value))
	if plain.length() <= max_chars:
		return plain

	var sorted_keys: Array = suffixes.keys()
	sorted_keys.sort()
	sorted_keys.reverse()

	var chosen_divisor := 1.0
	var chosen_suffix := ""
	for key: float in sorted_keys:
		if value >= key:
			chosen_divisor = key
			chosen_suffix = suffixes[key]
			break

	var divided := value / chosen_divisor
	var digits_before := int(floor(log(divided) / log(10.0))) + 1
	var available_for_num := max_chars - chosen_suffix.length()
	var decimals := available_for_num - digits_before - 1  # reserve one char for decimal point

	if decimals <= 0:
		return str(int(divided)) + chosen_suffix

	# Truncate (floor) to avoid rounding up past the visible digits
	var scale := pow(10.0, decimals)
	var truncated: float = floor(divided * scale) / scale
	var fmt := "%." + str(decimals) + "f"
	return (fmt % truncated) + chosen_suffix


static func format_without_zero_decimals(amount:float)-> String:
	var has_decimals = (amount != floor(amount))
	
	if has_decimals:
		return "%0.2f" % amount
	else:
		return str(int(floor(amount)))
