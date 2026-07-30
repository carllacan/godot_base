class_name ConsoleLogSinkConfig
extends BaseLogSinkConfig


func create_sink() -> BaseLogSink:
	var sink := ConsoleLogSink.new()
	sink.min_level = min_level
	return sink
