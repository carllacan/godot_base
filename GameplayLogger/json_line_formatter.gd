class_name JsonLineFormatter
extends BaseLogFormatter

# Output: one JSON object per line (JSON Lines / ndjson format).
# Always includes: timestamp, level, tag, message.
# Includes metadata key only when non-empty.

func format(entry:LogEntry) -> String:
	var data:Dictionary = {
		"timestamp": entry.timestamp,
		"level": LogLevel.label(entry.level),
		"tag": entry.tag,
		"message": entry.message,
	}
	if not entry.metadata.is_empty():
		data["metadata"] = entry.metadata
	return JSON.stringify(data)
