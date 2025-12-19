extends Node
class_name Dist
const DIST_FILE_PATH = "res://dist/dist_info.json"

static var version:String = "--" : get = get_version

static var _info:DistInfo # cached
static var info:DistInfo : get = get_dist_info


static func get_dist_info()-> DistInfo:	
	# Return cached info, if any
	if _info != null:
		return _info	
		
	# Create default info
	var di = DistInfo.new()
		
	# Try to load JSON file
	var json_file := FileAccess.open(DIST_FILE_PATH, FileAccess.READ)
	
	# if no file could be loaded, just return default info
	if json_file == null: 
		return null
		
	# Parse JSON
	var json_str = json_file.get_as_text()
	var dist_info_dict = JSON.parse_string(json_str)
	
	# Extract existing info
	if "version" in dist_info_dict.keys():
		di.version = dist_info_dict["version"]
	if "commit" in dist_info_dict.keys():
		di.commit = dist_info_dict["commit"]
		
	_info = di
	
	return di
	
	
static func get_version_num()-> String:	
	var di = get_dist_info()
	
	var v_num
	if di == null:
		v_num = "undef"
	else:
		v_num = di.version
		
	return v_num
	
	
static func get_version()-> String:
		
	var flags = [get_version_num()]
	
	if Flags.ITCHIO:
		flags.append("itchio")
	if Flags.STEAM:
		flags.append("steam")
	if Flags.DEMO:
		flags.append("demo")
		
	var v = "_".join(flags)
	
	var di = get_dist_info()
	if di.commit != "" and di.commit != "--":
		v += " (%s)" % di.commit.substr(0, 6)
		
	return v


class DistInfo:
	var version:String = ""
	var commit:String = ""
