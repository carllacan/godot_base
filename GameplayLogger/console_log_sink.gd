class_name ConsoleLogSink
extends BaseLogSink

# Writes log entries to the Godot console.
# Warning and Error levels use push_warning / push_error so they appear
# with the correct icon in the Godot debugger output.

func write(entry:LogEntry) -> void:
	if entry.level < min_level:
		return
	var line = _format_line(entry)
	match entry.level:
		LogLevel.Value.Warning:
			push_warning(line)
		LogLevel.Value.Error:
			push_error(line)
		_:
			print(line)

func _format_line(entry:LogEntry) -> String:
	var dt = Time.get_datetime_dict_from_unix_time(int(entry.timestamp))
	var ts = "[%02d:%02d:%02d]" % [dt.hour, dt.minute, dt.second]
	var tag_part = ("[%s] " % entry.tag) if entry.tag != "" else ""
	var line = "%s [%s] %s%s" % [ts, LogLevel.label(entry.level), tag_part, entry.message]
	if not entry.metadata.is_empty():
		line += " " + JSON.stringify(entry.metadata)
	return line
