extends Node
class_name GameplayLogger

# Global minimum level. Any entry below this is discarded before even
# creating a LogEntry object. Per-sink filtering is an additional layer on top.
var global_min_level:LogLevel.Value = LogLevel.Value.Debug

var _sinks:Array[BaseLogSink] = []


func debug(message:String, tag:String = "", metadata:Dictionary = {}) -> void:
	_log(LogLevel.Value.Debug, message, tag, metadata)


func info(message:String, tag:String = "", metadata:Dictionary = {}) -> void:
	_log(LogLevel.Value.Info, message, tag, metadata)


func warning(message:String, tag:String = "", metadata:Dictionary = {}) -> void:
	_log(LogLevel.Value.Warning, message, tag, metadata)


func error(message:String, tag:String = "", metadata:Dictionary = {}) -> void:
	_log(LogLevel.Value.Error, message, tag, metadata)


# Usage:
#   --no-default-log-sinks   skip the sinks configured in BuildConfig.log_sinks
#   --log-console            add a console sink
#   --log-file               add a file sink (JSONL, under user://logs/)
func _ready()-> void:
	var args := OS.get_cmdline_user_args()

	if not "--no-default-log-sinks" in args:
		for config:BaseLogSinkConfig in BuildConfig.Default.log_sinks:
			add_sink(config.create_sink())

	if "--log-console" in args:
		add_sink(ConsoleLogSinkConfig.new().create_sink())

	if "--log-file" in args:
		add_sink(FileLogSinkConfig.new().create_sink())


# Returns a TaggedLogger that pre-fills the tag on every call.
# Usage:
#   var _log = Log.get_tagged("SaveSystem")
#   _log.info("Game saved", {slot: 2})
func get_tagged(tag:String) -> TaggedLogger:
	return TaggedLogger.new(self, tag)


func add_sink(sink:BaseLogSink) -> void:
	sink.start()
	_sinks.append(sink)


func remove_sink(sink:BaseLogSink) -> void:
	sink.stop()
	_sinks.erase(sink)


func _exit_tree() -> void:
	for sink in _sinks:
		sink.stop()
	_sinks.clear()


#region Private

func _log(level:LogLevel.Value, message:String, tag:String, metadata:Dictionary) -> void:
	if level < global_min_level:
		return
	_validate_metadata(metadata)
	var entry = LogEntry.new()
	entry.timestamp = Time.get_unix_time_from_system()
	entry.level = level
	entry.tag = tag
	entry.message = message
	entry.metadata = metadata
	for sink in _sinks:
		sink.write(entry)


func _validate_metadata(metadata:Dictionary) -> void:
	for key in metadata.keys():
		_check_value(str(key), metadata[key])


func _check_value(path:String, value:Variant) -> void:
	if value is bool or value is int or value is float or value is String:
		return
	if value is Array:
		for i in (value as Array).size():
			_check_value("%s[%d]" % [path, i], (value as Array)[i])
		return
	if value is Dictionary:
		for k in (value as Dictionary).keys():
			_check_value("%s.%s" % [path, str(k)], (value as Dictionary)[k])
		return
	push_warning(
		"Log: metadata key '%s' has non-primitive type %d. It may not serialize correctly to JSON." % [path, typeof(value)]
	)

#endregion Private
