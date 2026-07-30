class_name BaseLogSink
extends RefCounted

# Only entries at or above this level are written by this sink.
var min_level:LogLevel.Value = LogLevel.Value.Debug

func write(_entry:LogEntry) -> void:
	pass

func flush() -> void:
	pass
	
	
func start() -> void:
	pass


func stop() -> void:
	pass
