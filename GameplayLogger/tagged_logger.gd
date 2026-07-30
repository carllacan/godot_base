class_name TaggedLogger
extends RefCounted

# A thin wrapper around Logger that pre-fills the tag on every call.
# Create via the Log autoload: Log.get_tagged("MySystem")

var _logger:Node
var _tag:String


func _init(logger:Node, tag:String) -> void:
	_logger = logger
	_tag = tag


func debug(message:String, metadata:Dictionary = {}) -> void:
	_logger.debug(message, _tag, metadata)


func info(message:String, metadata:Dictionary = {}) -> void:
	_logger.info(message, _tag, metadata)


func warning(message:String, metadata:Dictionary = {}) -> void:
	_logger.warning(message, _tag, metadata)


func error(message:String, metadata:Dictionary = {}) -> void:
	_logger.error(message, _tag, metadata)
