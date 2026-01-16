extends Node
class_name BaseIntegrationController
 
# Manages the interaction between the game and the platform it runs on, be it
# Steam or anything else.

func _ready()-> void:
	initialize()
	
	
func _process(_delta: float) -> void:
	pass
	
	
func initialize()-> void:	
	pass
		

func mark_achievement_as_completed(_ach_name:String)-> void:
	pass
	
	
# Tries to open the store page for a given ID, or this app's page if none is given.
func open_store_page(_store_id:Variant = null)-> void:
	pass
	
	
# Gets the language set in the external platform, or an empty string if none.
func get_current_language()-> String:
	return ""


func upload_save(_filepath:String)-> void:
	pass



class DefaultSyncCriterion:
	## A default sync criterion that parses both files as Godot custom Resources
	## and decides using a property both of them are assumed to have.
	static func criterion(file_a:PackedByteArray, file_b:PackedByteArray,
		property_name:String)-> bool:
		var a_value = _load_resource_property(file_a, property_name)
		var b_value = _load_resource_property(file_b, property_name)

		# If both invalid → no overwrite
		if a_value == null and b_value == null:
			return false

		# Prefer the one that has valid data
		if a_value == null:
			return false
		if b_value == null:
			return true

		# Must be comparable
		if typeof(a_value) != typeof(b_value):
			return false

		if typeof(a_value) in [TYPE_INT, TYPE_FLOAT]:
			return a_value > b_value

		return false

		
	static func _load_resource_property(bytes:PackedByteArray,	property_name:String) -> Variant:
		if bytes.is_empty():
			return null

		var tmp_path := "user://_cloud_sync_tmp.tres"

		var f := FileAccess.open(tmp_path, FileAccess.WRITE)
		if f == null:
			return null

		f.store_buffer(bytes)
		f.close()

		var res := ResourceLoader.load(tmp_path)
		if res == null:
			print("SYNC: Could not load file for sync comparison")
			return null

		if property_name not in res.get_property_list().map(func(p): return p["name"]):
			return null

		return res.get(property_name)



## Downloads a file from the remote cloud and compares it with its local version.
## filename: the name of the file to sync.
## criterion: a callable that takes two files in PackedByteArray form and returns
## true if the first file should overwrite the latter. For example: a criterion 
## could be a method that parses both files, checks an intermal timestamp, and
## returns true if the first one is more recent.
func sync_file(local_path:String, 
	criterion:Callable = DefaultSyncCriterion.criterion.bind("timestamp_unix")
	) -> void:
		
	var remote_path = local_to_remote_filepath(local_path)

	var local_bytes := PackedByteArray()
	if FileAccess.file_exists(local_path):
		var f := FileAccess.open(local_path, FileAccess.READ)
		local_bytes = f.get_buffer(f.get_length())
		f.close()
	else:
		push_error("Can't sync file %s: it doesn't exist" % remote_path)	
	

	var remote_bytes := read_remote_file(remote_path)

	# Nothing exists anywhere
	if local_bytes.is_empty() and remote_bytes.is_empty():
		print("SYNC: Can't sync file %s. Its empty locally and remotely" % local_path)	
		return

	# Only remote exists
	if local_bytes.is_empty():
		print("SYNC: File %s not found locally. Downloading remote." % local_path)
		Utils.write_local_file(local_path, remote_bytes)
		return

	# Only local exists
	if remote_bytes.is_empty():
		print("SYNC: File %s not found in remote. Uploading local version." % local_path)
		write_remote_file(remote_path, local_bytes)
		return

	# Both exist → policy decides
	if criterion.call(remote_bytes, local_bytes):		
		print("SYNC: Remote file %s found to be newer. Backing up and downloading." % local_path)
		# Backup local
		if FileAccess.file_exists(local_path):
			DirAccess.copy_absolute(
				local_path,
				local_path + ".bk",
			)
			
		# Overwrite local with remote
		Utils.write_local_file(local_path, remote_bytes)
	else:
		print("SYNC: Local file %s found to be newer. Uploading to remote." % local_path)
		#Overwrite remote with ocal
		write_remote_file(remote_path, local_bytes)

	
func local_to_remote_filepath(local_path:String)-> String:
	return local_path.get_file()
	
	
func write_remote_file(_local_path:String, _bytes:PackedByteArray)-> void:
	pass
	
	
func read_remote_file(_remote_path:String) -> PackedByteArray:
	return []
	
	
