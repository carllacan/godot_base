extends Node
class_name Utils


## Returns a copy of an array with no duplicate elements
static func unique(array:Array)-> Array:
	var unique_values:Array = []
	
	for element in array:
		if not element in unique_values:
			unique_values.append(element)
			
	return unique_values


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
		values = catalog.values()
	else:
		# If the catalog is not sorted then we have no guarantee that the element
		# at position X in catalog.keys() corresponds to the element at position X
		# in catalog.values(), so we need to compile two arrays for consistency.
		for k in catalog.keys():
			keys.append(k)
			values.append(catalog[k])
			
		
	var chosen_idx = rng.rand_weighted(values)
	
	return keys[chosen_idx]
	
	
	
	
static func get_magnitude_order(amount:float)-> int:
	var magnitude = 1
	while abs(amount) >= pow(10, magnitude):
		magnitude += 1
	#print("%s is of magnitude order %s" % [amount, magnitude-1])
	return magnitude-1

	
		
	
	
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
