extends BaseIntegrationController
class_name SteamIntegrationController

const STEAM_APP_ID := 3695440
const STEAM_APP_DEMO_ID := 3736220
	
 
func _ready()-> void:
	initialize()	
	
		
func initialize()-> void:	
	if Flags.STEAM:
		initialize_steam()
		

#region Steam

func get_steam_app_id()-> int:	
	if not Flags.STEAM:
		return -1
	if Flags.DEMO:
		return STEAM_APP_DEMO_ID
	else:
		return STEAM_APP_ID
		
func get_fullgame_steam_app_id()-> int:
	return STEAM_APP_ID
		
	
func initialize_steam()-> void:
	var initialize_response: Dictionary = Steam.steamInitEx(get_steam_app_id(), true)
	print("Did Steam initialize?: %s " % initialize_response)
	
	if initialize_response['status'] > Steam.STEAM_API_INIT_RESULT_OK:
		print("Failed to initialize Steam, shutting down: %s" % initialize_response)
		get_tree().quit()
	
	Steam.overlay_toggled.connect(_on_overlay_toggled)
	Steam.user_stats_received.connect(
		func(game_id: int, result: int, user_id: int): 
			print("game_id: %s, result: %s, user_id: %s" % [
				game_id, result, user_id
				])
			)
	Steam.requestUserStats(get_steam_app_id())
	
	#Clear achievements
	if BuildConfig.Default.clear_achievements_at_start:
		#for i in Steam.getNumAchievements():
			#var ach_name = Steam.getAchievementName(i)
			#Steam.clearAchievement(ach_name)	
		Steam.resetAllStats(true)


#endregion

func _on_overlay_toggled(active: bool, _user_initiated: bool, _app_id: int):
	if active:
		Pause.paused_externally.emit()
	
	
func mark_achievement_as_completed(ach_name:String)-> void:
	if not Flags.STEAM:
		return
	print("Marking ach '%s' as completed..." % ach_name)
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
	return Steam.getStatFloat(stat_name)
		
	
func set_statistic(stat_name:String, new_value:Variant)-> void:	
	if not Flags.STEAM:
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
	if not Steam.isCloudEnabledForAccount():
		return
		
	if not Steam.isCloudEnabledForAccount():
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
	var success = Steam.fileWrite(filename, bytes)
	if not success:
		push_warning("Couldn't write file %s (%d bytes) to remote cloud" % [filename, len(bytes)])
	

func read_remote_file(filename:String) -> PackedByteArray:
	if not Steam.fileExists(filename):
		return PackedByteArray()

	var size := Steam.getFileSize(filename)
	if size <= 0:
		return PackedByteArray()

	var result := Steam.fileRead(filename, size)

	if result["ret"] > 0:
		return result["buf"]

	return PackedByteArray()
