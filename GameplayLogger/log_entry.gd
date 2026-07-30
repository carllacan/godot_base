class_name LogEntry
extends RefCounted

var timestamp:float = 0.0
var level:LogLevel.Value = LogLevel.Value.Info
var tag:String = ""
var message:String = ""
var metadata:Dictionary = {}
