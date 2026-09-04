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


func _scan_directory(dir_path: String) -> Array[Resource]:
	var dir := DirAccess.open(dir_path)
	if dir == null:
		return []

	var results: Array[Resource] = []

	dir.list_dir_begin()
	var file := dir.get_next()

	while file != "":
		var is_dir := dir.current_is_dir()
		var full_path := dir_path.path_join(file)
				
		if full_path != get_path():
			if is_dir:
				if include_subdirectories and not file.begins_with("."):
					results.append_array(_scan_directory(full_path))
			else:
				var actual_path = full_path.trim_suffix(".remap").trim_suffix(".import")

				if actual_path.get_extension() in target_extensions:
					var worth_loading := true
					if not target_scripts.is_empty():
						var peeked := _peek_script_class(actual_path)
						# An inconclusive peek (binary .res, or no script_class in the
						# header) falls through to loading it, same as before this
						# check existed.
						if not peeked.is_empty():
							worth_loading = peeked in _target_class_names()

					if worth_loading:
						var res := load(actual_path)

						if target_scripts.is_empty():
							results.append(res)
						else:
							if res != null and res.get_script() in target_scripts:
								results.append(res)

		file = dir.get_next()

	dir.list_dir_end()

	return results


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
