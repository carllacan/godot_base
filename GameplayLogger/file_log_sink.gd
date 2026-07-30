class_name FileLogSink
extends BaseLogSink

enum Format { PlainText, Json }

# Configuration — set via FileLogSinkConfig.create_sink(), before start().
var log_dir:String = "user://logs/"
var format:Format = Format.PlainText
var rotation_enabled:bool = true
var max_file_size_kb:int = 10240

var _formatter:BaseLogFormatter
var _thread:Thread
var _queue_mutex:Mutex
var _file_mutex:Mutex
var _semaphore:Semaphore
var _queue:Array[LogEntry] = []
var _stop:bool = false
var _session_folder:String = ""
var _current_file_index:int = 0
var _current_file_size:int = 0
var _file:FileAccess = null
var _started:bool = false


func _init() -> void:
	_queue_mutex = Mutex.new()
	_file_mutex = Mutex.new()
	_semaphore = Semaphore.new()
	_thread = Thread.new()


# Call start() after configuring the sink, before adding it to the Logger.
func start() -> void:
	if _started:
		push_warning("FileLogSink: start() called more than once, ignoring.")
		return
	_started = true
	if format == Format.PlainText:
		_formatter = PlainTextFormatter.new()
	else:
		_formatter = JsonLineFormatter.new()
	_setup_log_target()
	_thread.start(_writer_loop)


func write(entry:LogEntry) -> void:
	if not _started:
		push_error("FileLogSink: write() called before start(). Call start() first.")
		return
	if entry.level < min_level:
		return
	# Error-level entries bypass the queue and are written synchronously so
	# that they survive a crash that might follow immediately.
	if entry.level == LogLevel.Value.Error:
		_write_sync(entry)
		return
	_queue_mutex.lock()
	_queue.append(entry)
	_queue_mutex.unlock()
	_semaphore.post()


func flush() -> void:
	if not _started:
		return
	_queue_mutex.lock()
	var batch:Array[LogEntry] = _queue.duplicate()
	_queue.clear()
	_queue_mutex.unlock()
	if batch.is_empty():
		return
	_file_mutex.lock()
	for entry in batch:
		_write_entry_to_file(entry)
	_file_mutex.unlock()


# Flushes remaining queue, joins the writer thread, and closes the file.
# Called automatically by Logger._exit_tree().
func stop() -> void:
	if not _started:
		return
	_queue_mutex.lock()
	_stop = true
	_queue_mutex.unlock()
	_semaphore.post()  # Wake thread so it can see _stop and exit.
	_thread.wait_to_finish()
	# Safety drain: if anything is left in the queue after the thread exits,
	# write it directly. In practice this should be empty.
	_file_mutex.lock()
	for entry in _queue:
		_write_entry_to_file(entry)
	_queue.clear()
	if _file:
		_file.close()
		_file = null
	_file_mutex.unlock()
	_started = false


# Returns the absolute filesystem path of the active session folder
# (or log_dir itself when rotation is disabled).
func get_session_path() -> String:
	if rotation_enabled and _session_folder != "":
		return ProjectSettings.globalize_path(log_dir.path_join(_session_folder))
	return ProjectSettings.globalize_path(log_dir)


#region Private

func _setup_log_target() -> void:
	var abs_dir = ProjectSettings.globalize_path(log_dir)
	if not DirAccess.dir_exists_absolute(abs_dir):
		DirAccess.make_dir_recursive_absolute(abs_dir)

	if rotation_enabled:
		var dt = Time.get_datetime_dict_from_system()
		_session_folder = "%04d-%02d-%02d_%02d-%02d_log" % [
			dt.year, dt.month, dt.day, dt.hour, dt.minute,
		]
		var session_abs = abs_dir.path_join(_session_folder)
		if not DirAccess.dir_exists_absolute(session_abs):
			DirAccess.make_dir_recursive_absolute(session_abs)

	# No mutex needed here — thread hasn't started yet.
	_open_file()


# Must be called while _file_mutex is held, or before the thread starts.
func _open_file() -> void:
	if _file:
		_file.close()
		_file = null
	var path = _current_file_path()
	_file = FileAccess.open(path, FileAccess.WRITE)
	if _file == null:
		push_error("FileLogSink: failed to open log file '%s' (error %d)" % [
			path, FileAccess.get_open_error(),
		])
	_current_file_size = 0


func _current_file_path() -> String:
	var ext = ".log" if format == Format.PlainText else ".jsonl"
	if rotation_enabled:
		var fname = "%s%d%s" % [_session_folder, _current_file_index, ext]
		return ProjectSettings.globalize_path(
			log_dir.path_join(_session_folder).path_join(fname)
		)
	var filename = "game" + ext
	return ProjectSettings.globalize_path(log_dir.path_join(filename))


func _write_sync(entry:LogEntry) -> void:
	_file_mutex.lock()
	_write_entry_to_file(entry)
	_file_mutex.unlock()


# Must be called while _file_mutex is held.
func _write_entry_to_file(entry:LogEntry) -> void:
	if _file == null:
		return
	var line = _formatter.format(entry) + "\n"
	_file.store_string(line)
	_file.flush()
	_current_file_size += line.length()
	if rotation_enabled and _current_file_size >= max_file_size_kb * 1024:
		_current_file_index += 1
		_open_file()


func _writer_loop() -> void:
	while true:
		_semaphore.wait()

		_queue_mutex.lock()
		var batch:Array[LogEntry] = _queue.duplicate()
		_queue.clear()
		var should_stop = _stop
		_queue_mutex.unlock()

		if not batch.is_empty():
			_file_mutex.lock()
			for entry in batch:
				_write_entry_to_file(entry)
			_file_mutex.unlock()

		if should_stop:
			break

#endregion Private
