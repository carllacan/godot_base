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

var _stats:Node
var _until_update:float = 0.0
## One value label per pipeline compilation category, built at runtime.
var _compile_rows:Dictionary[String, Label] = {}


func _ready()-> void:
	if Engine.is_editor_hint(): return

	CURRENT = self
	add_to_group(BaseGroups.DEBUG_ELEMENTS)
	visible = Debug.show_debug_elements

	# A readout is worth most exactly when the game is paused -- pausing is the
	# cleanest test of whether a frame costs what it costs on the CPU or the
	# GPU, and a menu being open is no reason to stop reporting.
	process_mode = Node.PROCESS_MODE_ALWAYS

	# Resolved by path rather than by name so that projects which do not
	# register the autoload keep working -- they simply get no perf rows.
	_stats = get_node_or_null("/root/PerfStats")
	%PerfGrid.visible = _stats != null

	if _stats != null: _build_compile_rows()

	# Nothing here is interactive, and a readout that swallows clicks makes the
	# game under it untestable wherever the panel happens to sit.
	_ignore_mouse(self)

	initialize_values()


## One row per compilation category. Built here rather than in the scene so the
## rows always match PIPELINE_MONITORS, and stacked vertically because inline
## they make the panel wider than the game.
func _build_compile_rows()-> void:
	var insert_at:int = %CompilesValue.get_index() + 1

	for key in PerformanceStats.PIPELINE_MONITORS:
		var header := Label.new()
		header.text = "    %s" % key
		var value := Label.new()

		%PerfGrid.add_child(header)
		%PerfGrid.add_child(value)
		%PerfGrid.move_child(header, insert_at)
		%PerfGrid.move_child(value, insert_at + 1)
		insert_at += 2

		_compile_rows[key] = value


func _ignore_mouse(node:Node)-> void:
	if node is Control:
		(node as Control).mouse_filter = Control.MOUSE_FILTER_IGNORE
	for child in node.get_children():
		_ignore_mouse(child)


func initialize_values()-> void:
	%VersionValue.text = Dist.info.version


func update_values()-> void:
	if _stats == null:
		%FpsValue.text = "%2.2f" % Engine.get_frames_per_second()
		return

	# Engine.get_frames_per_second() is only refreshed once a second, so it lags
	# every change you make while watching it. This is derived from the frame
	# time instead and moves immediately.
	%FpsValue.text = "%2.2f" % (1000.0 / maxf(_stats.frame_ms, 0.01))
	%FrameValue.text = "%.2f ms" % _stats.frame_ms

	# Shown either way, but flagged while they still include scene loading and
	# shader compilation -- which is when they look worst and mean least.
	var settling:String = "" if _stats.is_settled() else "  (starting up)"
	%PercentileValue.text = "%.2f / %.2f / %.2f ms%s" % [
		_stats.p50(), _stats.p95(), _stats.p99(), settling]
	%WorstPeakValue.text = "%.2f / %.2f ms" % [_stats.worst_ms, _stats.peak_ms]
	%HitchesValue.text = "%d" % _stats.hitches
	%DrawsValue.text = "%d" % _stats.monitor("draw_calls")
	%TargetValue.text = _stats.target_name()

	# "no reading yet" has to look different from "cost nothing to draw".
	if _stats.has_render_time():
		%RenderTimeValue.text = "%.2f / %.2f ms" % [
			_stats.render_time_cpu_ms(), _stats.render_time_gpu_ms()]
	else:
		%RenderTimeValue.text = "waiting for first reading"

	var compiles:Dictionary = _stats.pipeline_compilations()
	var total:int = 0
	for key in compiles:
		total += compiles[key]
		if _compile_rows.has(key):
			_compile_rows[key].text = "%d" % compiles[key]
	%CompilesValue.text = "%d" % total


func _physics_process(delta: float) -> void:
	if not visible: return

	_until_update -= delta
	if _until_update > 0.0: return
	_until_update = UPDATE_PERIOD_S

	update_values()
