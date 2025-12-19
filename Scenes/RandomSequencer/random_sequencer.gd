extends Node
class_name RandomSequencer

## A node that generates a random sequence from a catalog of objects, following
## a configuration that allows for complex operations like dynamic weights,
## temporal overrides, limiting occurrences in a row, etcetera.

@export var configuration:RandomSequenceConfiguration : set = set_configuration
@export var constant_override:Resource

var history:Array = []
## Dictionary of counters that must be maintained externally
var existing:Dictionary[Resource, int] = {}
var override_uses:Dictionary[RandomSequenceOverride, int] = {}


func set_configuration(new_value:RandomSequenceConfiguration)-> void:
	#var old_value = configuration
	#var changed:bool = old_value != new_value
	#if changed:
		#reset()
	configuration = new_value
		
		
func start_with(new_config:RandomSequenceConfiguration)-> void:
	assert(new_config != null)
	configuration = new_config
	reset()
	
		
func get_next(
			time:float	
		)-> Variant:
	assert(configuration != null)
	
	if constant_override != null:
		return constant_override
	
	# req 1: don't spawn more than X in a row
	# req 2: don't spawn if there are more than X in the game already
	# req 3: wait X seconds before spawning the first
		
	
	var weights:Dictionary[Variant, float] 
	
	for entry in configuration.entries:
		var element = entry.element
		
		# Start by getting the default weight for this level and enemy model
		weights[element] = entry.weight
		
		# Get the overrides for this element and check if any is valid now
		var overrides = configuration.get_element_overrides(element)
		
		for override:RandomSequenceOverride in overrides:			
			if override.has_limited_uses():
				if get_override_count(override) >= override.max_uses:
					continue
				
			if override.is_active_at(time):
				if weights[element] == override.overriden_weight:
					var w = "Override '%s' is the same as the base weight" % element
					push_warning(w)
				weights[element] = override.overriden_weight
				count_override(override)
			
				
		# Check if we have already spawned too many in a row
		if entry.has_a_repetition_max():					
			# Count how many in a row we have spawned right now
			var same_in_a_row:int = 0
			for i in range(len(history)-1, -1, -1):
				if history[i] == entry.element: 
					same_in_a_row += 1
				else:
					break
		
			# If we have spawned too many in a row already, set the weight to 0
			if same_in_a_row >= entry.max_in_a_row:
				weights[entry.element] = 0
				
		# Check if there are already too many of these in the world
		if entry.has_a_simultaneous_max():				
			var in_world:int
			if entry.element not in existing:
				in_world = 0
			else:
				in_world = get_element_count(entry.element)
			# If we have too many in the world already, set the weight to 0		
			if in_world >= entry.max_simultaneous:
				weights[entry.element] = 0
				
				
	var chosen = Utils.rand_weighted(weights)
	history.append(chosen)
	return chosen
	
	
func reset()-> void:
	history = []
	existing = {}
	override_uses = {}
	
	
func get_element_count(element:Resource)-> int:
	if not element in existing:
		existing[element] = 0
		
	return existing[element]
	
	
func count_element(element:Resource)-> void:
	if not element in existing:
		existing[element] = 0
	
	existing[element] += 1
	
	
func discount_element(element:Resource)-> void:
	if not element in existing:
		push_error("configurationNo existing elements")
		return
	
	existing[element] -= 1
	
	
func get_override_count(override:RandomSequenceOverride)-> int:
	if override not in override_uses:
		return 0
	return override_uses[override]


func count_override(override:RandomSequenceOverride)-> void:
	if override not in override_uses:
		override_uses[override] = 0
	override_uses[override] += 1
