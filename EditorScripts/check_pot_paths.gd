@tool
extends EditorScript
class_name CheckPotPaths


func _run() -> void:
	var project_settings_path := "res://project.godot"
	var file := FileAccess.open(project_settings_path, FileAccess.READ)
	if not file:
		push_error("Could not open project.godot")
		return

	var content := file.get_as_text()
	file.close()

	# Find the pot files line
	var pot_key := "locale/translations_pot_files=PackedStringArray("
	var start := content.find(pot_key)
	if start == -1:
		print("No locale/translations_pot_files found in project.godot")
		return

	var line_start := start + pot_key.length()
	var line_end := content.find(")", line_start)
	var raw := content.substr(line_start, line_end - line_start)

	# Parse the quoted strings
	var paths: PackedStringArray = []
	var pos := 0
	while pos < raw.length():
		var q_open := raw.find('"', pos)
		if q_open == -1:
			break
		var q_close := raw.find('"', q_open + 1)
		if q_close == -1:
			break
		paths.append(raw.substr(q_open + 1, q_close - q_open - 1))
		pos = q_close + 1

	print("Checking %d paths in locale/translations_pot_files..." % paths.size())
	print("---")

	var missing: PackedStringArray = []
	for path in paths:
		if not FileAccess.file_exists(path):
			missing.append(path)
			print("MISSING: %s" % path)

	print("---")
	if missing.is_empty():
		print("All %d paths exist." % paths.size())
	else:
		print("%d missing path(s) out of %d." % [missing.size(), paths.size()])
