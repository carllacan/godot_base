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
#   --log-sinks=<json>       add the sinks described by a JSON array
#
# One switch configures every sink, rather than one switch per property. The
# main caller is a harness building the string in code, where that is the easy
# shape; typed by hand it needs quoting:
#
#   godot -- --no-default-log-sinks --log-sinks='[
#     {"type":"file","log_dir":"/tmp/run3","format":"json","rotation_enabled":false},
#     {"type":"console","min_level":"warning"}]'
#
# "type" picks the config class; every other key is an exported property on it,
# so the two stay in step with nothing to keep in sync here. Properties holding
# an enum also take its name, because a bare 1 in a command line reads as
# nothing at all.
#
# Anything wrong with the string is an error and no sink, never a quiet fallback
# to the defaults: a run that was told to log somewhere and silently did not is
# worse than one that refuses to start.
func _ready()-> void:
	if not CommandLineManager.has_flag("--no-default-log-sinks"):
		for config:BaseLogSinkConfig in BuildConfig.Default.log_sinks:
			add_sink(config.create_sink())

	for config in _parse_cmdline_sinks():
		add_sink(config.create_sink())

	for path in get_log_paths():
		print("Logging to '%s'" % path)


# Whether anything is listening. Every log call is a no-op while this is false,
# so callers that pay to build their metadata should skip that work entirely:
#
#   if not Log.is_enabled(): return
#
# Sinks are all attached in _ready(), so this answers the same from then on.
func is_enabled() -> bool:
	return not _sinks.is_empty()


# Absolute paths every file sink is writing under. Empty when nothing is going
# to disk.
func get_log_paths() -> Array[String]:
	var paths:Array[String] = []
	for sink in _sinks:
		if sink is FileLogSink:
			paths.append((sink as FileLogSink).get_session_path())
	return paths


# Pushes out whatever the sinks have buffered. They already flush on their own,
# so this is only for right before something that might not come back.
func flush() -> void:
	for sink in _sinks:
		sink.flush()


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


#region Command line

const LOG_SINKS_ARG:String = "--log-sinks"


# The sink configs described by LOG_SINKS_ARG, or an empty array when the switch
# is absent or its value cannot be used.
func _parse_cmdline_sinks() -> Array[BaseLogSinkConfig]:
	var configs:Array[BaseLogSinkConfig] = []

	var json:String = CommandLineManager.get_value(LOG_SINKS_ARG)
	if json.is_empty():
		return configs

	var parsed:Variant = JSON.parse_string(json)
	if parsed == null:
		push_error("%s is not valid JSON: %s" % [LOG_SINKS_ARG, json])
		return configs

	if parsed is not Array:
		push_error("%s takes an array of sinks, got %s" % [
			LOG_SINKS_ARG, type_string(typeof(parsed))])
		return configs

	for entry:Variant in parsed as Array:
		if entry is not Dictionary:
			push_error("%s: every sink must be an object, got %s" % [
				LOG_SINKS_ARG, type_string(typeof(entry))])
			return []

		var config:BaseLogSinkConfig = _build_sink_config(entry)
		if config == null:
			# One unusable sink invalidates the lot: a run that logs to half the
			# places it was asked to is not the run anyone wanted.
			return []

		configs.append(config)

	return configs


# One sink config from its JSON object, or null when the object cannot be used.
func _build_sink_config(entry:Dictionary) -> BaseLogSinkConfig:
	if not entry.has("type"):
		push_error("%s: sink has no \"type\": %s" % [LOG_SINKS_ARG, entry])
		return null

	var type:String = str(entry["type"]).to_lower()
	var config:BaseLogSinkConfig

	match type:
		"file": config = FileLogSinkConfig.new()
		"console": config = ConsoleLogSinkConfig.new()
		_:
			push_error("%s: unknown sink type \"%s\" (known: file, console)" % [
				LOG_SINKS_ARG, type])
			return null

	var properties:Dictionary = _exported_properties(config)

	for key:String in entry.keys():
		if key == "type": continue

		if not properties.has(key):
			push_error("%s: %s sinks have no \"%s\" (they have: %s)" % [
				LOG_SINKS_ARG, type, key, ", ".join(properties.keys())])
			return null

		var value:Variant = _coerce(key, entry[key], properties[key])
		if value == null:
			return null

		config.set(key, value)

	return config


# The name -> declared Variant.Type of everything a sink config exports, which
# is what a JSON object is allowed to name.
func _exported_properties(config:BaseLogSinkConfig) -> Dictionary:
	var properties:Dictionary = {}

	for _info:Dictionary in config.get_property_list():
		if not (_info["usage"] & PROPERTY_USAGE_SCRIPT_VARIABLE): continue
		properties[_info["name"]] = _info["type"]

	return properties


# A JSON value as the property's declared type, or null when it cannot be one.
# JSON has no integers and no enums, so both need a hand: every number arrives
# as a float, and enums are worth naming rather than numbering.
func _coerce(key:String, value:Variant, type:Variant.Type) -> Variant:
	if type == TYPE_INT and value is String:
		var named:Variant = _enum_value(key, value)
		if named == null:
			push_error("%s: \"%s\" is not a value of %s" % [
				LOG_SINKS_ARG, value, key])
		return named

	if type == TYPE_INT and value is float:
		return int(value)

	if type == TYPE_FLOAT and (value is float or value is int):
		return float(value)

	if typeof(value) == type:
		return value

	push_error("%s: %s takes %s, got %s" % [
		LOG_SINKS_ARG, key, type_string(type), type_string(typeof(value))])
	return null


# The int behind the name of an enum-typed property, or null if there is none.
func _enum_value(key:String, value:String) -> Variant:
	match key:
		"min_level":
			match value.to_lower():
				"debug": return LogLevel.Value.Debug
				"info": return LogLevel.Value.Info
				"warning": return LogLevel.Value.Warning
				"error": return LogLevel.Value.Error
		"format":
			match value.to_lower():
				"text", "plaintext", "plain_text": return FileLogSink.Format.PlainText
				"json", "jsonl": return FileLogSink.Format.Json

	return null

#endregion Command line


#region Private

func _log(level:LogLevel.Value, message:String, tag:String, metadata:Dictionary) -> void:
	# Nothing is listening, so skip the entry and the metadata walk both. Callers
	# still pay to build the dictionary they passed in: the ones where that costs
	# anything should be guarding on is_enabled() themselves.
	if _sinks.is_empty():
		return
	if level < global_min_level:
		return
	_validate_metadata(metadata)
	var entry = LogEntry.new()
	entry.timestamp = Time.get_unix_time_from_system()
	entry.level = level
	entry.tag = tag
	entry.message = message
	# Deep copy: a sink may serialize this on its own thread well after the call
	# returns, and callers pass live game state (CardState.numbers, say) that
	# would otherwise keep changing underneath it.
	entry.metadata = metadata.duplicate(true)
	for sink in _sinks:
		sink.write(entry)


func _validate_metadata(metadata:Dictionary) -> void:
	for key in metadata.keys():
		_check_value(str(key), metadata[key])


func _check_value(path:String, value:Variant) -> void:
	# null included: JSON.stringify writes it as null, which is what a missing
	# value should look like in the log anyway.
	if value == null or value is bool or value is int or value is float or value is String:
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
