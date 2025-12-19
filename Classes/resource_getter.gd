extends Resource
class_name ResourceGetter

## Load only files with this extensions
@export var target_extensions: Array [String] = ["tres", "res"]
## Load only files with this script (will load the entire file!)
## Lave empty to load files with any script
@export var target_scripts: Array[Script]
## Include subdirectories
@export var include_subdirectories: bool = false


func get_all() -> Array[Resource]:
	var dir_path := get_resource_directory()
	if dir_path.is_empty():
		return []
	return _scan_directory(dir_path)


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
				if file.get_extension() in target_extensions:				
					var res := load(full_path)
						
						
					if target_scripts.is_empty():
						results.append(res)
					else:
						if res != null and res.get_script() in target_scripts:
							results.append(res)

		file = dir.get_next()

	dir.list_dir_end()

	return results



func get_resource_directory() -> String:
	var path := get_path()
	if path.is_empty():
		return ""
	return path.get_base_dir()
