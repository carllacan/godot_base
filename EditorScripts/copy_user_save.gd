@tool
extends EditorScript
class_name CopyUserSave


func _run() -> void:
	# Replicate the Flags.DEMO logic directly — Flags.DEMO shortcuts to false
	# in editor, ignoring force_demo, which would give the wrong path.
	var is_demo := BuildConfig.Default.force_flag(
			OS.has_feature("demo"), BuildConfig.Default.force_demo)
	var source_virtual: String
	if is_demo:
		source_virtual = "user://".path_join("demo").path_join(GameState.DEFAULT_FILENAME)
	else:
		source_virtual = "user://".path_join(GameState.DEFAULT_FILENAME)
	var source_path := ProjectSettings.globalize_path(source_virtual)

	if not FileAccess.file_exists(source_path):
		push_error("Save file not found at: %s" % source_path)
		return

	var dest_virtual := "res://Data/GameRuns/user_save.tres"
	var dest_path := ProjectSettings.globalize_path(dest_virtual)

	var source_file := FileAccess.open(source_path, FileAccess.READ)
	if not source_file:
		push_error("Could not open source file: %s" % source_path)
		return
	var content := source_file.get_buffer(source_file.get_length())
	source_file.close()

	var dest_file := FileAccess.open(dest_path, FileAccess.WRITE)
	if not dest_file:
		push_error("Could not open destination file: %s" % dest_path)
		return
	dest_file.store_buffer(content)
	dest_file.close()

	print("Copied %s -> %s" % [source_virtual, dest_virtual])
