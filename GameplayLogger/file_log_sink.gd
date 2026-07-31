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
var _file:FileAccess = null
var _started:bool = false
var _ever_started:bool = false


# Call start() after configuring the sink, before adding it to the Logger.
func start() -> void:
	if _started:
		push_warning("FileLogSink: start() called more than once, ignoring.")
		return
	_started = true
	_ever_started = true
	# Fresh every time so the sink can be restarted: a Thread that has been
	# waited on is spent, and a Semaphore keeps whatever count it was left with.
	_queue_mutex = Mutex.new()
	_file_mutex = Mutex.new()
	_semaphore = Semaphore.new()
	_thread = Thread.new()
	_stop = false
	_current_file_index = 0
	if format == Format.PlainText:
		_formatter = PlainTextFormatter.new()
	else:
		_formatter = JsonLineFormatter.new()
	_setup_log_target()
	_thread.start(_writer_loop)


func write(entry:LogEntry) -> void:
	if not _started:
		# Logging after stop() is ordinary at shutdown: whoever logs last has no
		# say in the order things are torn down. Only a sink that was never
		# started is a wiring mistake worth complaining about.
		if not _ever_started:
			push_error("FileLogSink: write() called before start(). Call start() first.")
		return
	if entry.level < min_level:
		return

	_queue_mutex.lock()
	_queue.append(entry)
	_queue_mutex.unlock()
	_semaphore.post()

	# Error-level entries have to be on disk before whatever crash might follow,
	# so don't wait for the writer thread to get round to them. Going through the
	# queue rather than past it is what keeps them in order with everything
	# logged before them.
	if entry.level == LogLevel.Value.Error:
		flush()


# Writes out everything queued so far and pushes it to the OS. Blocks until the
# writer thread has finished with any batch it already holds, so that on return
# every entry logged before the call is on disk, in order.
func flush() -> void:
	if not _started:
		return
	var batch:Array[LogEntry] = _take_queued()
	_file_mutex.lock()
	for entry in batch:
		_write_entry_to_file(entry)
	_flush_file()
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
	_write_batch(_take_queued())
	_file_mutex.lock()
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
		# Seconds included: files are opened truncating, so two runs sharing a
		# folder name means the second erases the first. Short back-to-back runs
		# are exactly what a batch of autoplayer runs looks like.
		var dt = Time.get_datetime_dict_from_system()
		_session_folder = "%04d-%02d-%02d_%02d-%02d-%02d_log" % [
			dt.year, dt.month, dt.day, dt.hour, dt.minute, dt.second,
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


func _current_file_path() -> String:
	var ext = ".log" if format == Format.PlainText else ".jsonl"
	if rotation_enabled:
		var fname = "%s%d%s" % [_session_folder, _current_file_index, ext]
		return ProjectSettings.globalize_path(
			log_dir.path_join(_session_folder).path_join(fname)
		)
	var filename = "game" + ext
	return ProjectSettings.globalize_path(log_dir.path_join(filename))


# Must be called while _file_mutex is held.
func _write_entry_to_file(entry:LogEntry) -> void:
	if _file == null:
		return
	_file.store_string(_formatter.format(entry) + "\n")
	# get_position() is the byte offset written so far, so the limit is real
	# kilobytes rather than a character count that undercounts anything
	# non-ASCII. Checked per entry because a batch runs to thousands of them and
	# checking once at the end of one overshoots by the whole batch; this only
	# reads a cursor, the flush is the part that costs. Closing the old file on
	# the way out flushes it.
	if rotation_enabled and _file.get_position() >= max_file_size_kb * 1024:
		_current_file_index += 1
		_open_file()


# Must be called while _file_mutex is held. One flush per batch rather than per
# entry: this is a syscall, and anything blocked on _file_mutex (an error being
# written synchronously, a stop()) waits for the whole batch of them.
func _flush_file() -> void:
	if _file != null:
		_file.flush()


func _write_batch(batch:Array[LogEntry]) -> void:
	if batch.is_empty():
		return
	_file_mutex.lock()
	for entry in batch:
		_write_entry_to_file(entry)
	_flush_file()
	_file_mutex.unlock()


func _take_queued() -> Array[LogEntry]:
	_queue_mutex.lock()
	var batch:Array[LogEntry] = _queue.duplicate()
	_queue.clear()
	_queue_mutex.unlock()
	return batch


func _has_queued() -> bool:
	_queue_mutex.lock()
	var queued:bool = not _queue.is_empty()
	_queue_mutex.unlock()
	return queued


func _is_stopping() -> bool:
	_queue_mutex.lock()
	var stopping:bool = _stop
	_queue_mutex.unlock()
	return stopping


func _writer_loop() -> void:
	while true:
		_write_batch(_take_queued())

		if _is_stopping():
			break

		# write() posts once per entry, but one wakeup drains the whole queue and
		# flush() can empty it without posting at all, so nearly every post left
		# here refers to an entry already on disk. Dropping them is what keeps
		# this from spinning through one empty iteration per entry logged.
		while _semaphore.try_wait():
			pass

		# Only sleep if nothing turned up while we were dropping those — a post
		# we discarded may have belonged to an entry queued since the batch.
		# _stop is set before its post, so re-reading it here catches a stop()
		# whose wakeup went the same way.
		if _has_queued() or _is_stopping():
			continue
		_semaphore.wait()

#endregion Private
