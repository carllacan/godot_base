class_name FileLogSinkConfig
extends BaseLogSinkConfig

@export var log_dir:String = "user://logs/"
@export var format:FileLogSink.Format = FileLogSink.Format.PlainText
@export var rotation_enabled:bool = true
@export var max_file_size_kb:int = 10240


func create_sink() -> BaseLogSink:
	var sink := FileLogSink.new()
	sink.min_level = min_level
	sink.log_dir = log_dir
	sink.format = format
	sink.rotation_enabled = rotation_enabled
	sink.max_file_size_kb = max_file_size_kb
	return sink
