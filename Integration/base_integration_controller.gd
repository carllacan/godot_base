extends Node
class_name BaseIntegrationController
 
# Manages the interaction between the game and the platform it runs on, be it
# Steam or anything else.

func _ready()-> void:
	initialize()
	
	
func is_platform_ready()-> bool:
	return false


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


class DefaultSyncCriterion:
	## A default sync criterion that reads a property both files are assumed to
	## have straight out of their text, and decides using that.
	##
	## The property is read rather than loaded because the files being compared
	## can predate the running build: a save naming a resource path that has
	## moved does not load at all, and two files that both fail to load compare
	## equal, which hands the decision to whichever side happens to be local.
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

		
	## Only text resources can be read this way. A binary save gives null, the
	## same answer an unreadable file gave before.
	static func _load_resource_property(bytes:PackedByteArray, property_name:String) -> Variant:
		if bytes.is_empty():
			return null

		var value:Variant = SaveMigrator.read_property_from_text(
			bytes.get_string_from_utf8(), property_name)

		if value == null:
			print("SYNC: Could not read '%s' for sync comparison" % property_name)

		return value


## Downloads a file from the remote cloud and compares it with its local version.
## filename: the name of the file to sync.
## criterion: a callable that takes two files in PackedByteArray form and returns
## true if the first file should overwrite the latter. For example: a criterion 
## could be a method that parses both files, checks an intermal timestamp, and
## returns true if the first one is more recent.
func sync_file(local_path:String, 
	criterion:Callable = DefaultSyncCriterion.criterion.bind("timestamp_unix")
	) -> void:
				
	if not Settings.get_setting_value_by_id("steam_cloud_enabled"):
		return

	# Without cloud storage there is no remote side to compare against, and
	# every save would otherwise report itself as missing from the remote and
	# "upload" into a no-op.
	if not is_cloud_available():
		return

	var remote_path = local_to_remote_filepath(local_path)

	# A missing local file is not an error: it is the case a fresh install is in,
	# and the one where the remote copy has to come down.
	var local_bytes := PackedByteArray()
	if FileAccess.file_exists(local_path):
		var f := FileAccess.open(local_path, FileAccess.READ)
		local_bytes = f.get_buffer(f.get_length())
		f.close()


	var remote_bytes := read_remote_file(remote_path)

	# Nothing exists anywhere
	if local_bytes.is_empty() and remote_bytes.is_empty():
		print("SYNC: Can't sync file %s. Its empty locally and remotely" % local_path)	
		return

	# Only remote exists
	if local_bytes.is_empty():
		print("SYNC: File %s not found locally. Downloading remote." % local_path)
		_write_downloaded_file(local_path, remote_bytes)
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
		_write_downloaded_file(local_path, remote_bytes)
	else:
		#print("SYNC: Local file %s found to be newer. Uploading to remote." % local_path)
		# Overwrite remote with ocal
		write_remote_file(remote_path, local_bytes)

	
## Writes a file that came down from the cloud. The directory it belongs in may
## not exist yet: on a fresh install nothing has saved there, and the demo keeps
## its saves in a subdirectory of its own.
func _write_downloaded_file(local_path:String, bytes:PackedByteArray)-> void:
	var dir:String = local_path.get_base_dir()
	if not DirAccess.dir_exists_absolute(dir):
		var result:Error = DirAccess.make_dir_recursive_absolute(dir)
		if result != OK:
			push_error("SYNC: Could not create %s to download %s into (error %d)" % [
				dir, local_path, result])
			return

	Utils.write_local_file(local_path, bytes)


func local_to_remote_filepath(local_path:String)-> String:
	return local_path.get_file()
	
	
## Whether the platform's cloud storage is configured and usable right now.
## Platforms that have cloud storage answer this after checking at startup; the
## base controller has none, so nothing syncs.
func is_cloud_available()-> bool:
	return false


func write_remote_file(_local_path:String, _bytes:PackedByteArray)-> void:
	pass
	
	
func read_remote_file(_remote_path:String) -> PackedByteArray:
	return []
	
	
# Opens the platform's in-app overlay on a given page, if it has one.
func open_overlay(_page_id:String)-> bool:
	return false
