class_name BaseLogSinkConfig
extends Resource

# Plain-data description of a sink, editable/saveable via BuildConfig.log_sinks.
# Builds the actual (stateful, non-Resource) sink on demand.

@export var min_level:LogLevel.Value = LogLevel.Value.Debug


func create_sink() -> BaseLogSink:
	return null
