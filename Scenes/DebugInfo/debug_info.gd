extends CanvasLayer
class_name DebugInfo
## On-screen readout of build version and, when the PerfStats autoload is
## registered, frame-time and renderer statistics.
##
## Visibility is driven by Debug.show_debug_elements through the
## BaseGroups.DEBUG_ELEMENTS group.

## So PerfStats can tell whether the project already instantiated one of these
## rather than adding a second.
static var CURRENT:DebugInfo

## Refreshing at full frame rate makes the numbers flicker too fast to read,
## and puts a percentile sort plus a pile of label formatting on every frame of
## the thing being measured. Ten times a second reads better and costs less.
const UPDATE_PERIOD_S:float = 0.1
## Compile rows and custom monitors share one row dictionary, so the compile
## keys are namespaced -- otherwise a monitor named "mesh" or "draw" would
## quietly take over a compilation row.
const COMPILE_ROW_PREFIX:String = "compiles/"

var _until_update:float = 0.0

var header_labels:Dictionary[String, Label] = {}
var value_labels:Dictionary[String, Label] = {}


func _ready()-> void:
	if Engine.is_editor_hint(): return

	CURRENT = self
	add_to_group(BaseGroups.DEBUG_ELEMENTS)
	visible = Debug.show_debug_elements

	# A readout is worth most exactly when the game is paused -- pausing is the
	# cleanest test of whether a frame costs what it costs on the CPU or the
	# GPU, and a menu being open is no reason to stop reporting.
	process_mode = Node.PROCESS_MODE_ALWAYS
	
	_build_compile_rows()
	_build_custom_monitor_rows()

	# Nothing here is interactive, and a readout that swallows clicks makes the
	# game under it untestable wherever the panel happens to sit.
	_ignore_mouse(self)

	PerfStats.monitor_added.connect(_insert_entry)
	PerfStats.monitor_removed.connect(_remove_entry)

	initialize_values()


## One row per compilation category. Built here rather than in the scene so the
## rows always match PIPELINE_MONITORS, and stacked vertically because inline
## they make the panel wider than the game.
func _build_compile_rows()-> void:
	var insert_at:int = %CompilesValue.get_index() + 1

	for key in PerformanceStats.PIPELINE_MONITORS:
		_insert_entry(COMPILE_ROW_PREFIX + key, insert_at, "    %s" % key)
		insert_at += 2
		
		
func _build_custom_monitor_rows()-> void:
	for m in PerfStats.custom_monitors:
		_insert_entry(m)
		
		
func _insert_entry(data_name:String, insert_at:int = -1,
				header_text:String = "")-> void:
	var header := Label.new()
	if header_text == "":
		header.text = data_name
	else:
		header.text = header_text

	var value := Label.new()

	# _ignore_mouse() runs once at _ready() and cannot reach rows a monitor adds
	# later, so these carry the same rule themselves.
	header.mouse_filter = Control.MOUSE_FILTER_IGNORE
	value.mouse_filter = Control.MOUSE_FILTER_IGNORE

	%PerfGrid.add_child(header)
	%PerfGrid.add_child(value)
	if insert_at >= 0:
		%PerfGrid.move_child(header, insert_at)
		%PerfGrid.move_child(value, insert_at + 1)
	
	header_labels[data_name] = header
	value_labels[data_name] = value


## Drops a row again. Custom monitors come and go with the scenes that register
## them, and a row left behind would sit there showing its last reading forever.
func _remove_entry(data_name:String)-> void:
	if not value_labels.has(data_name): return

	header_labels[data_name].queue_free()
	value_labels[data_name].queue_free()
	header_labels.erase(data_name)
	value_labels.erase(data_name)


func _ignore_mouse(node:Node)-> void:
	if node is Control:
		(node as Control).mouse_filter = Control.MOUSE_FILTER_IGNORE
	for child in node.get_children():
		_ignore_mouse(child)


func initialize_values()-> void:
	%VersionValue.text = Dist.info.version


func update_values()-> void:
	# Engine.get_frames_per_second() is only refreshed once a second, so it lags
	# every change you make while watching it. This is derived from the frame
	# time instead and moves immediately.
	%FpsValue.text = "%2.2f" % (1000.0 / maxf(PerfStats.frame_ms, 0.01))
	%FrameValue.text = "%.2f ms" % PerfStats.frame_ms

	# Shown either way, but flagged while they still include scene loading and
	# shader compilation -- which is when they look worst and mean least.
	var settling:String = "" if PerfStats.is_settled() else "  (starting up)"
	%PercentileValue.text = "%.2f / %.2f / %.2f ms%s" % [
		PerfStats.p50(), PerfStats.p95(), PerfStats.p99(), settling]
	%WorstPeakValue.text = "%.2f / %.2f ms" % [PerfStats.worst_ms, PerfStats.peak_ms]
	%HitchesValue.text = "%d" % PerfStats.hitches
	%DrawsValue.text = "%d" % PerfStats.monitor("draw_calls")
	%TargetValue.text = PerfStats.target_name()

	# "no reading yet" has to look different from "cost nothing to draw".
	if PerfStats.has_render_time():
		%RenderTimeValue.text = "%.2f / %.2f ms" % [
			PerfStats.render_time_cpu_ms(), PerfStats.render_time_gpu_ms()]
	else:
		%RenderTimeValue.text = "waiting for first reading"

	# Update Pipeline compilations
	var compiles:Dictionary = PerfStats.pipeline_compilations()
	var total:int = 0
	for key in compiles:
		total += compiles[key]
		var row:String = COMPILE_ROW_PREFIX + key
		if value_labels.has(row):
			value_labels[row].text = "%d" % compiles[key]
	%CompilesValue.text = "%d" % total

	# Custom monitors. get_value() returns null for a monitor whose getter has
	# died since the last prune, which is a row about to be removed rather than a
	# reading of zero.
	for m in PerfStats.custom_monitors:
		if not value_labels.has(m): continue
		var value:Variant = PerfStats.get_value(m)
		value_labels[m].text = "--" if value == null else "%2.2f" % value


func _physics_process(delta: float) -> void:
	if not visible: return

	_until_update -= delta
	if _until_update > 0.0: return
	_until_update = UPDATE_PERIOD_S

	update_values()
