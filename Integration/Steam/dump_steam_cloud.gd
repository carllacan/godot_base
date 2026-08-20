# Lists every file this account has in Steam Cloud for one of the app IDs in
# steam_integration_info.tres, and (unless DOWNLOAD is off) writes each one to
# user://cloud_dump/<app_id>/ so it can be inspected or diffed against the live
# save.
#
# This talks to Steam directly instead of going through SteamIntegrationController:
# Flags.STEAM is false in the editor, so the controller would refuse to do
# anything. That is also the point of the script — it reports what Steam holds,
# not what the game believes it uploaded.
#
# Requires the Steam client to be running and logged into an account that owns
# the app. The editor will show up as playing the game while this runs.
@tool
extends EditorScript
class_name DumpSteamCloud


enum App {FULL_GAME, DEMO, PLAYTEST}

## Which app's cloud to read. Steam binds a process to one app ID, so switching
## this needs an editor restart to take effect (the script says so if it sees a
## stale binding).
const APP:App = App.FULL_GAME

## Set to false to only list what is up there, without writing anything locally.
const DOWNLOAD:bool = true

const DUMP_DIR = "user://cloud_dump"


func _run()-> void:
	var info:SteamIntegrationInfo = _load_info()
	if info == null:
		return

	var app_id:int = _get_app_id(info)
	if app_id <= 0:
		print_rich("[color=red][ERROR] No app ID configured for %s in %s[/color]" % [
			App.find_key(APP), SteamIntegrationInfo.DEFAULT_PATH])
		return

	if not _initialize(app_id):
		return

	_report_cloud_settings(app_id)
	_dump_files(app_id)

	# Leaves the editor process unbound again, so a later run can pick a
	# different app ID without a restart. Steam does not always honour that, so
	# _initialize() checks rather than trusting it.
	Steam.steamShutdown()


func _load_info()-> SteamIntegrationInfo:
	var path:String = SteamIntegrationInfo.DEFAULT_PATH
	if not ResourceLoader.exists(path):
		print_rich("[color=red][ERROR] Integration info not found at %s[/color]" % path)
		return null

	var info = load(path)
	if info == null:
		print_rich("[color=red][ERROR] Could not load integration info at %s[/color]" % path)
	return info


func _get_app_id(info:SteamIntegrationInfo)-> int:
	match APP:
		App.FULL_GAME: return info.full_game_id
		App.DEMO: return info.demo_id
		App.PLAYTEST: return info.playtest_id
	return -1


## Brings up the Steam API for [param app_id] and confirms it actually bound to
## that app. steamInitEx() reports success and records the requested ID even
## when the process is already bound to a different one, so the answer that
## counts comes from getAppID(), which reads what SteamAPI is really using.
func _initialize(app_id:int)-> bool:
	if not Steam.isSteamRunning():
		print_rich("[color=red][ERROR] The Steam client is not running[/color]")
		return false

	var result:Dictionary = Steam.steamInitEx(app_id, false)
	if result["status"] > Steam.STEAM_API_INIT_RESULT_OK:
		print_rich("[color=red][ERROR] Could not initialize Steam for app %d: %s[/color]" % [
			app_id, result])
		return false

	var bound_id:int = Steam.getAppID()
	if bound_id != app_id:
		print_rich(("[color=red][ERROR] Steam is bound to app %d, not %d. " +
			"Restart the editor before dumping a different app's cloud.[/color]") % [
			bound_id, app_id])
		return false

	print("Steam initialized for app %d as %s" % [app_id, Steam.getPersonaName()])
	return true


## Prints the three things that decide whether the game can write at all: the
## two Cloud toggles and the quota. A file list is misleading without them —
## an empty listing means something different when Cloud is switched off.
func _report_cloud_settings(app_id:int)-> void:
	print("Cloud enabled for account: %s" % Steam.isCloudEnabledForAccount())
	print("Cloud enabled for app %d: %s" % [app_id, Steam.isCloudEnabledForApp()])

	var quota:Dictionary = Steam.getQuota()
	var total:int = quota.get("total_bytes", 0)
	var available:int = quota.get("available_bytes", 0)
	if total <= 0:
		print_rich(("[color=red][ERROR] Cloud quota for app %d is %d bytes. " +
			"Set the byte and file quotas in Steamworks.[/color]") % [app_id, total])
	else:
		print("Quota: %s of %s bytes used (%s free)" % [
			total - available, total, available])


func _dump_files(app_id:int)-> void:
	var count:int = Steam.getFileCount()
	print("\n%d file(s) in the cloud for app %d:" % [count, app_id])
	if count == 0:
		return

	var dump_dir:String = DUMP_DIR.path_join(str(app_id))
	if DOWNLOAD and not _ensure_dir(dump_dir):
		return

	var downloaded := 0
	for i in count:
		var entry:Dictionary = Steam.getFileNameAndSize(i)
		var fname:String = entry.get("name", "")
		var size:int = entry.get("size", 0)

		print("\n  %s" % fname)
		print("    size: %d bytes" % size)
		print("    modified: %s" % Time.get_datetime_string_from_unix_time(
			Steam.getFileTimestamp(fname), true))
		print("    persisted: %s" % Steam.filePersisted(fname))
		print("    syncs to: %s" % _platform_names(Steam.getSyncPlatforms(fname)))

		if DOWNLOAD and _download(fname, size, dump_dir):
			downloaded += 1

	if DOWNLOAD:
		print("\nDownloaded %d of %d file(s) to %s" % [
			downloaded, count, ProjectSettings.globalize_path(dump_dir)])


## Reads one cloud file and writes it under [param dump_dir]. Cloud file names
## can contain slashes, so the destination may need directories of its own.
func _download(fname:String, size:int, dump_dir:String)-> bool:
	if size <= 0:
		print_rich("[color=yellow]    [WARNING] Empty file, not downloaded[/color]")
		return false

	var result:Dictionary = Steam.fileRead(fname, size)
	if not result.get("ret", false):
		print_rich("[color=red]    [ERROR] Could not read %s from the cloud[/color]" % fname)
		return false

	var target:String = dump_dir.path_join(fname)
	if not _ensure_dir(target.get_base_dir()):
		return false

	var file := FileAccess.open(target, FileAccess.WRITE)
	if file == null:
		print_rich("[color=red]    [ERROR] Could not write %s (error %d)[/color]" % [
			target, FileAccess.get_open_error()])
		return false

	file.store_buffer(result["buf"])
	file.close()

	print("    saved to: %s" % ProjectSettings.globalize_path(target))
	return true


## Creates [param dir] if it is not there yet, reporting failures the same way
## for both callers. A directory that already exists is not a failure.
func _ensure_dir(dir:String)-> bool:
	var result:Error = DirAccess.make_dir_recursive_absolute(dir)
	if result != OK:
		print_rich("[color=red][ERROR] Could not create %s (error %d)[/color]" % [dir, result])
		return false

	return true


func _platform_names(platforms:int)-> String:
	if platforms == Steam.REMOTE_STORAGE_PLATFORM_NONE:
		return "nothing"
	if (platforms & Steam.REMOTE_STORAGE_PLATFORM_ALL) == Steam.REMOTE_STORAGE_PLATFORM_ALL:
		return "all platforms"

	var flags:Dictionary = {
		"windows": Steam.REMOTE_STORAGE_PLATFORM_WINDOWS,
		"osx": Steam.REMOTE_STORAGE_PLATFORM_OSX,
		"ps3": Steam.REMOTE_STORAGE_PLATFORM_PS3,
		"linux": Steam.REMOTE_STORAGE_PLATFORM_LINUX,
		"switch": Steam.REMOTE_STORAGE_PLATFORM_SWITCH,
		"android": Steam.REMOTE_STORAGE_PLATFORM_ANDROID,
		"ios": Steam.REMOTE_STORAGE_PLATFORM_IOS,
	}

	var names:Array[String] = []
	for flag_name in flags:
		if platforms & int(flags[flag_name]):
			names.append(flag_name)

	return ", ".join(names) if not names.is_empty() else str(platforms)
