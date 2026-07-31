extends Node
class_name CommandLineManager

static var _args:PackedStringArray
static var _is_parsed:bool = false


## Whether a bare switch (no value) is present, e.g. "--no-default-log-sinks".
static func has_flag(name:String)-> bool:
	_ensure_parsed()
	return name in _args


## The value given to a `--switch=<value>` or `--switch <value>` command line
## argument. Empty when the switch is absent or given no value.
static func get_value(switch:String)-> String:
	_ensure_parsed()

	for i in _args.size():
		var arg:String = _args[i]

		if arg.begins_with(switch + "="):
			return arg.trim_prefix(switch + "=").strip_edges()

		if arg == switch and i + 1 < _args.size():
			var next:String = _args[i + 1].strip_edges()
			return "" if next.begins_with("--") else next

	return ""


## All arguments after the `--` separator, for positional (non-switch) use.
static func get_args()-> PackedStringArray:
	_ensure_parsed()
	return _args


static func _ensure_parsed()-> void:
	if _is_parsed: return
	_args = OS.get_cmdline_user_args()
	_is_parsed = true
