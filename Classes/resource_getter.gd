@tool
extends Resource
class_name ResourceGetter

## Load only files with this extensions
@export var target_extensions: Array [String] = ["tres", "res"]
## Load only files with this script. Checked against a text resource's
## script_class header first, so a non-matching file is never loaded at all --
## see _peek_script_class(). Leave empty to load files with any script.
@export var target_scripts: Array[Script]
## Include subdirectories
@export var include_subdirectories: bool = false
## Regexp checked against each subdirectory's name when include_subdirectories
## is on. A folder whose name matches is skipped entirely, along with
## everything under it. Leave empty to scan every subdirectory.
@export var excluded_folders_pattern: String = ""
@export_group("Debug")
@export var verbose:bool = false


var cached_resources:Array[Resource] = []

func p(msg:String)-> void:
	if not verbose: return
	print(msg)
	
	
func get_all() -> Array[Resource]:
	if cached_resources.is_empty():
		var dir_path := get_resource_directory()
		if dir_path.is_empty():
			return []
		cached_resources = _scan_directory(dir_path)
	
	p("Loaded %d resources from %s" % [len(cached_resources), get_resource_directory()])
	return cached_resources


## Lists res:// contents through ResourceLoader rather than DirAccess: the
## latter's res:// listing is only reliable in the editor and can disagree
## with it in packed/exported builds (godot-proposals #13122), which let a
## stray resource slip into an export-only scan here before.
func _scan_directory(dir_path: String) -> Array[Resource]:
	var results: Array[Resource] = []

	for entry:String in ResourceLoader.list_directory(dir_path):
		var is_dir := entry.ends_with("/")
		var file := entry.trim_suffix("/")
		var full_path := dir_path.path_join(file)

		if full_path == get_path():
			continue

		if is_dir:
			if include_subdirectories and not file.begins_with(".") \
			and not _is_excluded_folder(file):
				results.append_array(_scan_directory(full_path))
		else:
			if full_path.get_extension() in target_extensions:
				var worth_loading := true
				if not target_scripts.is_empty():
					var peeked := _peek_script_class(full_path)
					# An inconclusive peek (binary .res, or no script_class in the
					# header) falls through to loading it, same as before this
					# check existed.
					if not peeked.is_empty():
						worth_loading = peeked in _target_class_names()

				if worth_loading:
					var res := load(full_path)

					if target_scripts.is_empty():
						results.append(res)
					else:
						if res != null and res.get_script() in target_scripts:
							results.append(res)

	return results


func _is_excluded_folder(folder_name:String)-> bool:
	if excluded_folders_pattern.is_empty():
		return false

	var regex := RegEx.new()
	regex.compile(excluded_folders_pattern)
	return regex.search(folder_name) != null


func _target_class_names()-> Array[String]:
	var names:Array[String] = []
	for s:Script in target_scripts:
		var n := s.get_global_name()
		if not n.is_empty():
			names.append(n)
	return names


## Reads just a text resource's header line to learn its script_class, without
## loading the resource (and, transitively, running any of its own static
## initializers -- which is exactly what let a stray non-target resource, like
## a save file dropped next to a content resource, wedge itself into a
## get_all() scan that was already in progress). Returns "" if the file is not
## a text resource, or its header carries no script_class.
static func _peek_script_class(path:String)-> String:
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		return ""
	var header := f.get_line()
	f.close()

	var regex := RegEx.new()
	regex.compile("script_class=\"([^\"]+)\"")
	var m := regex.search(header)
	if m == null:
		return ""
	return m.get_string(1)


func get_resource_directory() -> String:
	var path := get_path()
	if path.is_empty():
		return ""
	return path.get_base_dir()
