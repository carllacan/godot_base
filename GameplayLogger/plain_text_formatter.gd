class_name PlainTextFormatter
extends BaseLogFormatter

# Output: [YYYY-MM-DD HH:MM:SS] [LEVEL] [TAG] Message\t{"key": value}
# Tab separates message from metadata JSON so the parser can split unambiguously.
# If metadata is empty, the tab and JSON are omitted.

func format(entry:LogEntry) -> String:
	var dt = Time.get_datetime_dict_from_unix_time(int(entry.timestamp))
	var ts = "[%04d-%02d-%02d %02d:%02d:%02d]" % [
		dt.year, dt.month, dt.day,
		dt.hour, dt.minute, dt.second,
	]
	var line = "%s [%s] [%s] %s" % [ts, LogLevel.label(entry.level), entry.tag, entry.message]
	if not entry.metadata.is_empty():
		line += "\t" + JSON.stringify(entry.metadata)
	return line
