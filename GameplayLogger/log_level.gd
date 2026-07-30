class_name LogLevel

enum Value { Debug = 0, Info = 1, Warning = 2, Error = 3 }

static func label(level:Value) -> String:
	match level:
		Value.Debug: return "DEBUG"
		Value.Info: return "INFO"
		Value.Warning: return "WARNING"
		Value.Error: return "ERROR"
	return "UNKNOWN"

static func from_label(text:String) -> Value:
	match text.to_upper():
		"DEBUG": return Value.Debug
		"INFO": return Value.Info
		"WARNING": return Value.Warning
		"ERROR": return Value.Error
	return Value.Debug

static func color(level:Value) -> Color:
	match level:
		Value.Debug: return Color(0.6, 0.6, 0.6)
		Value.Info: return Color(0.9, 0.9, 0.9)
		Value.Warning: return Color(1.0, 0.8, 0.1)
		Value.Error: return Color(1.0, 0.35, 0.35)
	return Color.WHITE
