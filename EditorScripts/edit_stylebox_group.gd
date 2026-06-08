@tool
extends EditorScript

@export_dir var folder_path : String = "res://Themes/TabButton//"
@export var copy_all_normal_properties : bool = true
@export var autocreate_missing_styles : bool = true

@export_group("BG Colors")
@export_subgroup("Offsets")
@export var use_offsets : bool = true
@export_range(-1.0, 1.0, 0.01) var highlight_bg_offset : float = 0.1
@export_range(-1.0, 1.0, 0.01) var pressed_bg_offset : float = -0.1
@export_range(-1.0, 1.0, 0.01) var disabled_bg_offset : float = -0.3

@export_subgroup("Direct Colors")
@export var highlight_bg_color : Color
@export var pressed_bg_color : Color
@export var disabled_bg_color : Color


@export_group("Border Colors")
@export_subgroup("Offsets")
@export var border_use_offsets : bool = false
@export_range(-1.0, 1.0, 0.01) var highlight_border_offset : float = 0.1
@export_range(-1.0, 1.0, 0.01) var pressed_border_offset : float = -0.1
@export_range(-1.0, 1.0, 0.01) var disabled_border_offset : float = -0.3

@export_subgroup("Direct Colors")
@export var highlight_border_color : Color = Color.WHITE.darkened(0.1)
@export var pressed_border_color : Color = Color.WHITE.darkened(0.1)
@export var disabled_border_color : Color = Color.WHITE.darkened(0.1)


func run(paths:Array) -> void:
	if paths.is_empty():
		push_error("No paths selected.")
		return
	var selected:String = paths[0]
	folder_path = selected if DirAccess.open(selected) != null else selected.get_base_dir()
	_run()


func _run():

	if folder_path.is_empty():
		push_error("Folder path not set.")
		return

	var dir := DirAccess.open(folder_path)
	if dir == null:
		push_error("Could not open folder: " + folder_path)
		return

	var styleboxes := {
		"normal": null,
		"highlight": null,
		"pressed": null,
		"disabled": null
	}

	var normal_file := ""

	dir.list_dir_begin()

	while true:
		var file := dir.get_next()

		if file == "":
			break

		if dir.current_is_dir():
			continue

		if not file.ends_with(".tres") and not file.ends_with(".res"):
			continue

		for key in styleboxes.keys():

			if file.begins_with(key):

				var path := folder_path.path_join(file)
				var res := ResourceLoader.load(path)

				if res == null:
					push_warning("Could not load: " + path)
					continue

				if not res is StyleBoxFlat:
					push_warning("Not StyleBoxFlat: " + path)
					continue

				styleboxes[key] = res

				if key == "normal":
					normal_file = file

	dir.list_dir_end()

	var normal_sb : StyleBoxFlat = styleboxes["normal"]

	if normal_sb == null:
		push_warning("Normal StyleBoxFlat not found.")
		return


	# Determine filename suffix
	var suffix := normal_file.substr("normal".length())

	# Auto-create missing styleboxes
	if autocreate_missing_styles:

		for key in styleboxes.keys():

			if styleboxes[key] != null:
				continue

			var new_sb := normal_sb.duplicate(true)

			var filename = key + suffix
			var path := folder_path.path_join(filename)

			ResourceSaver.save(new_sb, path)

			styleboxes[key] = new_sb

			print("Created missing StyleBox: ", filename)


	for key in styleboxes.keys():

		var sb : StyleBoxFlat = styleboxes[key]

		if sb == null:
			push_warning("Missing StyleBoxFlat starting with: " + key)
			continue

		if copy_all_normal_properties and key != "normal":
			_copy_stylebox_properties(normal_sb, sb)

		sb.bg_color = _get_bg_color(key, normal_sb.bg_color)
		sb.border_color = _get_border_color(key, normal_sb.border_color)

		ResourceSaver.save(sb, sb.resource_path)

	EditorInterface.get_resource_filesystem().scan()

	print("StyleBox update complete.")



func _get_bg_color(state : String, base_color : Color) -> Color:

	match state:

		"normal":
			return base_color

		"highlight":
			if use_offsets:
				return _apply_offset(base_color, highlight_bg_offset)
			return highlight_bg_color

		"pressed":
			if use_offsets:
				return _apply_offset(base_color, pressed_bg_offset)
			return pressed_bg_color

		"disabled":
			if use_offsets:
				return _apply_offset(base_color, disabled_bg_offset)
			return disabled_bg_color

	return base_color



func _get_border_color(state : String, base_color : Color) -> Color:

	match state:

		"normal":
			return base_color

		"highlight":
			if border_use_offsets:
				return _apply_offset(base_color, highlight_border_offset)
			return highlight_border_color

		"pressed":
			if border_use_offsets:
				return _apply_offset(base_color, pressed_border_offset)
			return pressed_border_color

		"disabled":
			if border_use_offsets:
				return _apply_offset(base_color, disabled_border_offset)
			return disabled_border_color

	return base_color



func _apply_offset(color : Color, offset : float) -> Color:

	if offset > 0:
		return color.lightened(offset)

	if offset < 0:
		return color.darkened(-offset)

	return color



func _copy_stylebox_properties(from: StyleBoxFlat, to: StyleBoxFlat):

	for prop in from.get_property_list():

		if not (prop.usage & PROPERTY_USAGE_STORAGE):
			continue

		var name = prop.name

		if name in ["bg_color", "border_color"]:
			continue

		to.set(name, from.get(name))
