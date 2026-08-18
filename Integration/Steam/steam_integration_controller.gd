extends BaseIntegrationController
#class_name SteamIntegrationController


var info:SteamIntegrationInfo

## Whether Steam Cloud can actually be written to. Set by validate_cloud() at
## startup so that a misconfigured app reports once, instead of every save
## pushing a warning from write_remote_file().
var cloud_available:bool = false


func _ready()-> void:
	if not Flags.STEAM:
		return
				
	initialize()	
	
		
func initialize()-> void:	
	if not Flags.STEAM:
		return
		
	var p = SteamIntegrationInfo.DEFAULT_PATH
	if not ResourceLoader.exists(p):
		push_error("Integration info not found at %s" % p)
		return
	info = load(p)
	if info == null:
		push_error("Could not load integration info at %s" % p)
		return

	if not validate_app_id():
		return

	if not initialize_steam():
		return

	validate_achievements()
	validate_cloud()


#region Steam

## Gets the Steam app ID of the app that is currently running
func get_steam_app_id()-> int:	
	if not Flags.STEAM:	return -1
	if info == null: return -1
	
	if Flags.DEMO:
		return info.demo_id
	else:
		return info.full_game_id
		
		
## Gets the Steam app ID of the full app, regardless of what is currently running
func get_fullgame_steam_app_id()-> int:
	if not Flags.STEAM:	return -1
	if info == null: return -1
	
	return info.full_game_id
		
	
## Starts up the Steam API. Returns false if it could not be initialized, in
## which case the game is also asked to shut down.
func initialize_steam()-> bool:
	var initialize_response: Dictionary = Steam.steamInitEx(get_steam_app_id(), true)
	print("Did Steam initialize?: %s " % initialize_response)

	if initialize_response['status'] > Steam.STEAM_API_INIT_RESULT_OK:
		print("Failed to initialize Steam, some things might fail: %s" % initialize_response)
		return false

	Steam.overlay_toggled.connect(_on_overlay_toggled)
	Steam.user_stats_received.connect(
		func(game_id: int, result: int, user_id: int): 
			print("game_id: %s, result: %s, user_id: %s" % [
				game_id, result, user_id
				])
			)
	Steam.requestUserStats(get_steam_app_id())
	
	# Clear achievements, if configured to do so
	if BuildConfig.Default.clear_achievements_at_start:
		Steam.resetAllStats(true)

	return true


## Checks that an app ID was actually configured before we hand it to Steam.
## The IDs in SteamIntegrationInfo default to -1, so a project that forgets to
## fill in the resource would otherwise call steamInitEx(-1).
func validate_app_id()-> bool:
	var app_id := get_steam_app_id()
	if app_id <= 0:
		push_error("No valid Steam app ID configured in %s (got %d)" % [
			SteamIntegrationInfo.DEFAULT_PATH, app_id])
		return false

	return true


## Checks that Steam Cloud is usable before the first save tries to sync, and
## records the answer in cloud_available.
##
## Steamworks exposes no call that says "Cloud is unconfigured for this app",
## so this infers it from the quota: an app whose Cloud byte/file quota has not
## been set in Steamworks reports a total quota of 0, and every fileWrite then
## fails as over-quota, which is the repeating warning this is meant to catch.
## The two isCloudEnabled* calls cover the other reasons writes get rejected,
## both of which are the player's choice rather than a configuration mistake.
##
## Returns false if Cloud is unusable for any of those reasons.
func validate_cloud()-> bool:
	cloud_available = false

	# Both toggles have to be on: the account-wide one in Steam's settings, and
	# the per-game one in the game's properties.
	if not Steam.isCloudEnabledForAccount():
		push_warning("Steam Cloud is disabled account-wide; saves will not sync")
		return false

	if not Steam.isCloudEnabledForApp():
		push_warning("Steam Cloud is disabled for app %d; saves will not sync" % get_steam_app_id())
		return false

	# getQuota() reports {total_bytes, available_bytes}. Missing keys mean the
	# Remote Storage interface was not there to answer, which GodotSteam also
	# logs on its own, so there is nothing to conclude about the quota itself.
	var quota:Dictionary = Steam.getQuota()
	if not quota.has("total_bytes"):
		push_error("Steam Cloud quota unavailable for app %d (got %s)" % [
			get_steam_app_id(), quota])
		return false

	var total_bytes:int = quota["total_bytes"]
	if total_bytes <= 0:
		push_error(("App %d has a Steam Cloud quota of %d bytes. Configure the " +
			"Cloud byte and file quotas in Steamworks, or saves will fail to upload.") % [
			get_steam_app_id(), total_bytes])
		return false

	print("Steam Cloud available: %d of %d bytes free" % [
		quota.get("available_bytes", -1), total_bytes])

	cloud_available = true
	return true


func is_cloud_available()-> bool:
	return cloud_available


## Compares the achievement names declared in the info resource against the ones
## actually configured in Steamworks for this app, reporting both directions.
## Returns false if anything the game can grant is missing from Steamworks.
##
## Only achievements can be checked this way: Steamworks can enumerate them, but
## it exposes no equivalent for user stats. getStatInt/getStatFloat return 0 for
## an unknown stat exactly as they do for one that is genuinely zero, so
## stat_names cannot be verified without writing to them.
func validate_achievements()-> bool:
	if info == null:
		return false

	var swachs = Steam.getNumAchievements()
	var configured:Array[String] = []
	for i in swachs:
		configured.append(Steam.getAchievementName(i))

	if configured.is_empty():
		push_warning("App %d has no achievements configured in Steamworks" % get_steam_app_id())

	var valid := true
	for ach_name in info.achievement_names:
		if ach_name not in configured:
			push_error("Achievement '%s' is declared in %s but is not configured in Steamworks" % [
				ach_name, SteamIntegrationInfo.DEFAULT_PATH])
			valid = false

	for ach_name in configured:
		if ach_name not in info.achievement_names:
			push_warning("Achievement '%s' is configured in Steamworks but is missing from %s" % [
				ach_name, SteamIntegrationInfo.DEFAULT_PATH])

	if not valid:
		print("* Steamworks Achievement verification failed *")
		print("* Achievements present in Steamworks: (%d)" % swachs)
		for ach_name in configured:
			print("\t" + ach_name)
	
	return valid


#endregion

func _on_overlay_toggled(active: bool, _user_initiated: bool, _app_id: int):
	if active:
		Pause.paused_externally.emit()
	
	
func mark_achievement_as_completed(ach_name:String)-> void:
	if not Flags.STEAM:
		return
	if info == null:
		return

	if ach_name not in info.achievement_names:
		push_error("Achievement %s not found" % ach_name)
		return
				
	#print("Marking ach '%s' as completed..." % ach_name)
	var success = Steam.setAchievement(ach_name)
	if not success:
		push_error("Failed to mark ach '%s' as completed" % ach_name)
	success = Steam.storeStats()
	if not success:
		push_error("Failed to store stats")
		
		
func open_store_page(store_id:Variant = null)-> void:
	if not Flags.STEAM:
		return
	if store_id == null:
		Steam.activateGameOverlayToStore(get_fullgame_steam_app_id())
	else:
		Steam.activateGameOverlayToStore(store_id)
		
		
func open_overlay(page_id:String)-> void:
	if not Flags.STEAM: return
	
	if Steam.isOverlayEnabled():
		Steam.activateGameOverlayToWebPage(page_id, 
		Steam.OverlayToWebPageMode.OVERLAY_TO_WEB_PAGE_MODE_DEFAULT)
	
		
func get_float_statistic(stat_name:String)-> float:
	if not Flags.STEAM:
		return NAN
	if info == null:
		return NAN

	if stat_name not in info.stat_names:
		push_error("Stat %s not found" % stat_name)
		return NAN
		
	return Steam.getStatFloat(stat_name)
		
	
func set_statistic(stat_name:String, new_value:Variant)-> void:
	if not Flags.STEAM:
		return
	if info == null:
		return

	if stat_name not in info.stat_names:
		push_error("Stat %s not found" % stat_name)
		return
		
	assert(not is_nan(new_value))
	if new_value is int:
		var success = Steam.setStatInt(stat_name, int(new_value))
		if not success:
			print("Failed to set stat %s to: %s" % [stat_name, new_value])
			return
	if new_value is float:
		var success = Steam.setStatFloat(stat_name, new_value)
		if not success:
			print("Failed to set stat %s to: %s" % [stat_name, new_value])
			return
			
	## Pass the value to Steam then fire it
	if not Steam.storeStats():
		print("Failed to store data on Steam, should be stored locally")
		return
	
	
func change_statistic(stat_name:String, change:Variant)-> void:
	if not Flags.STEAM:
		return
	if info == null:
		return

	if stat_name not in info.stat_names:
		push_error("Stat %s not found" % stat_name)
		return
		
	assert(not is_nan(change))
	
	if change is int:
		var old_value = Steam.getStatInt(stat_name)
		var new_value = old_value + change
		var success = Steam.setStatInt(stat_name, int(new_value))
		if not success:
			print("Failed to set stat %s to: %s" % [stat_name, new_value])
			return
	if change is float:
		var old_value = Steam.getStatFloat(stat_name)		
		var new_value = old_value + change
		if is_nan(old_value):
			new_value = change
		else:
			new_value = old_value + change
		var success = Steam.setStatFloat(stat_name, new_value)
		if not success:
			print("Failed to set stat %s to: %s" % [stat_name, new_value])
			return
		#else:
			#print("Set stat %s to: %s" % [stat_name, new_value])
			
	
	## Pass the value to Steam then fire it
	if not Steam.storeStats():
		print("Failed to store data on Steam, should be stored locally")
		return
	
	
func get_current_language()-> String:
	if not Flags.STEAM:
		return ""
	var steam_lang := Steam.getCurrentGameLanguage()
	# Translate the Steam string to the corresponding Godot string
	match steam_lang:
		"english":
			return "en"
		"spanish":
			return "es_ES"
	return ""


func upload_save(filepath:String)-> void:
	if not cloud_available:
		return

	if not FileAccess.file_exists(filepath):
		return

	var file := FileAccess.open(filepath, FileAccess.READ)
	if file == null:
		return

	# .tres is text, but we upload raw bytes
	var data := file.get_buffer(file.get_length())
	file.close()

	var cloud_filename := filepath.get_file()

	var success := Steam.fileWrite(cloud_filename, data)
	if not success:
		push_error("Failed to upload save to Steam Cloud: " + cloud_filename)


func download_save(filepath:String) -> bool:
	var cloud_filename := filepath.get_file()

	if not Steam.fileExists(cloud_filename):
		return false

	var size := Steam.getFileSize(cloud_filename)
	if size <= 0:
		return false

	var result := Steam.fileRead(cloud_filename, size)

	var bytes: PackedByteArray
	if result is Dictionary:
		if not result.has("data"):
			return false
		bytes = result["data"]

	if bytes.is_empty():
		return false

	var file := FileAccess.open(filepath, FileAccess.WRITE)
	if file == null:
		return false

	file.store_buffer(bytes)
	file.close()

	return true

	
func write_remote_file(filename, bytes)-> void:
	# validate_cloud() already said why, at startup; repeating it per save only
	# buries the one message that explains the problem.
	if not cloud_available:
		return

	var success = Steam.fileWrite(filename, bytes)
	if not success:
		push_warning("Couldn't write file %s (%d bytes) to remote cloud" % [filename, len(bytes)])


func read_remote_file(filename:String) -> PackedByteArray:
	if not cloud_available:
		return PackedByteArray()

	if not Steam.fileExists(filename):
		return PackedByteArray()

	var size := Steam.getFileSize(filename)
	if size <= 0:
		return PackedByteArray()

	var result := Steam.fileRead(filename, size)

	if result["ret"] > 0:
		return result["buf"]

	return PackedByteArray()
