extends Node
class_name PerformanceStats
## Collects frame-time and renderer statistics for performance diagnosis.
##
## Registered as the `PerfStats` autoload. This class only *collects* -- the
## readout lives in DebugInfo, which reads from here, so a scripted run can
## gather numbers with no HUD on screen at all.
##
## Two measurements are deliberately absent:
##
##  * `TIME_PROCESS` / `TIME_PHYSICS_PROCESS`. They are not a usable "script
##    time" figure and reading them as one is misleading. The CPU-vs-GPU split
##    people actually want is `render_time_cpu_ms` / `render_time_gpu_ms`.
##  * A plain fps average. It hides exactly the failure mode worth finding: a
##    120 ms stall twice a second barely moves a mean. Use the percentiles.

const DEBUG_INFO_SCENE:PackedScene = preload(
	"res://GodotBase/Scenes/DebugInfo/debug_info.tscn")

## A frame this long is a visible stutter even if the average looks fine.
const HITCH_MS:float = 33.0
## Window the peak-hold `worst_ms` meter covers.
const WORST_WINDOW_S:float = 2.0
## Frames kept for percentiles. At 60 fps this is a ~33 second window.
const CAPACITY:int = 2000
## Smoothing for the human-readable frame-time readout, per second of decay.
const SMOOTHING:float = 6.0
## Startup is over once the pipeline compilation counters stop moving. This is
## deliberately detected rather than assumed: measured over three runs of one
## unchanging scene, the first representative frame arrived at frame 4 twice
## and frame 5 once, and a game that compiles real shaders takes far longer
## (bingomental spends ~347 ms compiling on its third frame). Any fixed frame
## count would be wrong on some machine, driver or scene.
const SETTLE_QUIET_FRAMES:int = 30
## ...but a game that keeps compiling shaders during play would never go quiet,
## so stop waiting eventually and measure anyway.
const SETTLE_MAX_FRAMES:int = 600
## Frames to allow a newly enabled measurement before concluding that a viewport
## reading 0.00 genuinely costs nothing, rather than not being live yet.
## Measured: the first real reading lands on the 3rd frame after enabling, both
## at startup and when enabled 40 frames in.
const RENDER_TIME_SETTLE_FRAMES:int = 10
## How often to look for a marked target while falling back to the root
## viewport. The marked viewport usually does not exist yet when this first
## looks, so the search has to keep going -- but not every frame.
const TARGET_RECHECK_FRAMES:int = 30
## How often to check custom monitors for a getter whose object has been freed.
## Cheap, but there is no reason to do it every frame: a dead monitor costs
## nothing until something reads it.
const MONITOR_PRUNE_FRAMES:int = 30

## Monitors worth a per-frame snapshot, as label -> Performance.Monitor.
const MONITORS:Dictionary[String, int] = {
	"draw_calls": Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME,
	"primitives": Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME,
	"objects": Performance.RENDER_TOTAL_OBJECTS_IN_FRAME,
	"video_mem": Performance.RENDER_VIDEO_MEM_USED,
	"texture_mem": Performance.RENDER_TEXTURE_MEM_USED,
	"buffer_mem": Performance.RENDER_BUFFER_MEM_USED,
	"orphan_nodes": Performance.OBJECT_ORPHAN_NODE_COUNT,
	"nodes": Performance.OBJECT_NODE_COUNT,
}

## Shader/pipeline compilation counters. A hitch that lines up with one of
## these going up is a compile stall, not a fill-rate problem -- which is the
## difference between "optimise the scene" and "warm the shaders".
const PIPELINE_MONITORS:Dictionary[String, int] = {
	"canvas": Performance.PIPELINE_COMPILATIONS_CANVAS,
	"mesh": Performance.PIPELINE_COMPILATIONS_MESH,
	"surface": Performance.PIPELINE_COMPILATIONS_SURFACE,
	"draw": Performance.PIPELINE_COMPILATIONS_DRAW,
	"specialization": Performance.PIPELINE_COMPILATIONS_SPECIALIZATION,
}

signal monitor_added(monitor_name:String)
signal monitor_removed(monitor_name:String)

## Smoothed frame time, for a readout a human can actually read.
var frame_ms:float = 16.0
## Longest frame in the last WORST_WINDOW_S seconds.
var worst_ms:float = 0.0
## Longest frame since the last reset().
var peak_ms:float = 0.0
## Frames over HITCH_MS since the last reset().
var hitches:int = 0

## The viewport being measured. Resolved from BaseGroups.PERF_TARGET, falling
## back to the root viewport.
var target_viewport:Viewport

## Monitors registered through add_custom_monitor(), as name -> getter.
##
## The getter is kept because Performance will not hand a registered callable
## back, and spotting a monitor whose object has been freed means looking at it.
var custom_monitors:Dictionary[String, Callable] = {}
## Owners declared at registration, as name -> instance id. Only the getters
## Callable.is_valid() cannot see through need one, so most monitors are absent
## from here -- check has() before reading.
##
## Ids rather than the objects themselves: a Dictionary holds a strong reference,
## so a RefCounted owner parked in one would be kept alive by the very registry
## meant to notice it dying, and would never be pruned.
var custom_monitor_owner_ids:Dictionary[String, int] = {}

var _samples:PackedFloat32Array = PackedFloat32Array()
var _write:int = 0
var _count:int = 0

var _sorted:PackedFloat32Array = PackedFloat32Array()
var _sorted_at_frame:int = -1

var _worst_left:float = 0.0
var _frames:int = 0

var _measured_rid:RID
var _pipeline_prev:Dictionary[String, int] = {}
var _pipeline_delta:Dictionary[String, int] = {}

var _warned_multiple_targets:bool = false

## True while measuring the root viewport only because nothing is marked.
var _using_fallback:bool = true
var _recheck_in:int = 0

var _prune_in:int = MONITOR_PRUNE_FRAMES

## Set once nothing has compiled for SETTLE_QUIET_FRAMES: startup is over.
var _settled:bool = false
var _quiet_frames:int = 0

## Set once the render-time measurement has produced a real reading.
var _render_time_live:bool = false
var _render_time_frames:int = 0


func _ready()-> void:
	if not Flags.DEBUG:
		set_process(false)
		return

	_samples.resize(CAPACITY)
	process_mode = Node.PROCESS_MODE_ALWAYS

	for key in PIPELINE_MONITORS:
		_pipeline_prev[key] = 0
		_pipeline_delta[key] = 0

	_resolve_target()

	# One frame, so a DebugInfo placed in the main scene has had a chance to
	# register itself before this decides whether to add one.
	await get_tree().process_frame
	_add_debug_info_if_absent()


func _add_debug_info_if_absent()-> void:
	if not GodotBase.settings.perf_auto_add_debug_info: return
	if is_instance_valid(DebugInfo.CURRENT): return
	add_child(DEBUG_INFO_SCENE.instantiate())


## Registers a monitor, readable through get_value() and shown as a row by
## DebugInfo.
##
## Re-registering a name replaces the getter rather than being ignored. The
## registration is global and outlives whatever node made it, so a scene rebuild
## arrives here with a fresh getter for a name whose old getter is holding a
## freed object. Keeping the old one is how you get a monitor that prints an
## engine error on every read for the rest of the session.
##
## Pass monitor_owner only for a getter whose death Callable.is_valid() cannot
## see -- see _prune_dead_monitors(). A getter that captures self, or a bound
## method, is already covered and needs nothing.
func add_custom_monitor(monitor_name:String, getter:Callable, arguments:Array = [],
		type:Performance.MonitorType = Performance.MonitorType.MONITOR_TYPE_QUANTITY,
		monitor_owner:Object = null
		)-> void:
	if not Flags.DEBUG: return

	# Performance is process-global while custom_monitors belongs to this
	# instance, so the engine -- not the dictionary -- is what decides whether a
	# name is already taken. Adding a duplicate is an engine error, not a no-op.
	if Performance.has_custom_monitor(monitor_name):
		Performance.remove_custom_monitor(monitor_name)
		custom_monitor_owner_ids.erase(monitor_name)

	Performance.add_custom_monitor(monitor_name, getter, arguments, type)

	var is_new:bool = not custom_monitors.has(monitor_name)
	custom_monitors[monitor_name] = getter

	if monitor_owner != null:
		custom_monitor_owner_ids[monitor_name] = monitor_owner.get_instance_id()

	if is_new: monitor_added.emit(monitor_name)


## Unregisters a monitor and drops its readout row. Worth calling from the
## _exit_tree() of whatever owns the getter, though _prune_dead_monitors()
## catches most of the ones that do not.
func remove_custom_monitor(monitor_name:String)-> void:
	if not custom_monitors.has(monitor_name): return

	custom_monitors.erase(monitor_name)
	custom_monitor_owner_ids.erase(monitor_name)

	if Performance.has_custom_monitor(monitor_name):
		Performance.remove_custom_monitor(monitor_name)

	monitor_removed.emit(monitor_name)


## Current value of a custom monitor, or null when there is no such monitor or
## its getter has died since the last prune.
func get_value(monitor_name:String)-> Variant:
	if not custom_monitors.has(monitor_name): return null
	# Pruning is periodic, so a getter can die between sweeps. Reading a dead one
	# prints an engine error and returns null anyway -- this just skips the noise.
	if not custom_monitors[monitor_name].is_valid(): return null

	return Performance.get_custom_monitor(monitor_name)


## Drops monitors whose getter no longer has a live object behind it.
##
## Callable.is_valid() catches a lambda that captured self, and a bound method --
## which is what a monitor registered from a node looks like. It cannot catch a
## lambda that captured only a local: that callable's object is the GDScript
## itself, which never dies. A getter like `func(): return thing.count()` over a
## local `thing` is invisible to it, and has to declare a monitor_owner at
## registration or be removed by hand.
func _prune_dead_monitors()-> void:
	_prune_in = MONITOR_PRUNE_FRAMES

	var dead:Array[String] = []
	for monitor_name in custom_monitors:
		if _is_monitor_dead(monitor_name):
			dead.append(monitor_name)

	# Collected first: remove_custom_monitor() erases from the dictionary being
	# iterated here, and emits a signal whose handlers may touch it as well.
	for monitor_name in dead:
		remove_custom_monitor(monitor_name)


func _is_monitor_dead(monitor_name:String)-> bool:
	if not custom_monitors[monitor_name].is_valid():
		return true

	# Most monitors declare no owner, and reading a key a Dictionary does not
	# have is an error that aborts the caller rather than returning null.
	if custom_monitor_owner_ids.has(monitor_name):
		var monitor_owner = instance_from_id(custom_monitor_owner_ids[monitor_name])
		if not is_instance_valid(monitor_owner):
			return true

	return false


func _exit_tree()-> void:
	_stop_measuring()


func _process(delta:float)-> void:
	_frames += 1
	_resolve_target()

	var this_ms:float = delta * 1000.0
	frame_ms = lerpf(frame_ms, this_ms, minf(delta * SMOOTHING, 1.0))

	_record(this_ms)

	if this_ms > HITCH_MS: hitches += 1
	peak_ms = maxf(peak_ms, this_ms)

	# Peak-hold: latch the longest frame and restart the window each time a new
	# peak arrives, so this reads as "the longest frame in the last
	# WORST_WINDOW_S seconds" and nothing subtler.
	_worst_left -= delta
	if this_ms > worst_ms or _worst_left <= 0.0:
		worst_ms = this_ms
		_worst_left = WORST_WINDOW_S

	_update_pipeline_deltas()
	_update_render_time_liveness()
	if not _settled: _update_settling()

	_prune_in -= 1
	if _prune_in <= 0: _prune_dead_monitors()


func _record(ms:float)-> void:
	_samples[_write] = ms
	_write = (_write + 1) % CAPACITY
	_count = mini(_count + 1, CAPACITY)
	# The sorted view is cached per drawn frame, which is only safe while the
	# data behind it is unchanged. Recording twice within one frame is what a
	# test does, and without this the second read would be stale.
	_sorted_at_frame = -1


## Clears the accumulating counters. Worth calling once gameplay has actually
## started: startup cost otherwise pins peak_ms and hitches and hides
## everything that happens afterwards.
func reset()-> void:
	_write = 0
	_count = 0
	_sorted_at_frame = -1
	peak_ms = 0.0
	worst_ms = 0.0
	hitches = 0
	_worst_left = 0.0


## Whether engine startup is over and the samples describe the running game
## rather than the loading of it. Until this is true the numbers are still
## worth showing -- they just carry scene loading and shader compilation, and
## get cleared the moment it does turn true.
func is_settled()-> bool:
	return _settled


## Whether the render-time figures are real readings. False means "not yet
## known", not "zero": the measurement takes a couple of frames to come up, and
## reporting its initial 0.00 as a measurement would read as a viewport that
## costs nothing to draw.
func has_render_time()-> bool:
	return _render_time_live


## Startup is over when nothing has compiled for a while. Driven by the
## pipeline counters rather than a frame count, because how long compilation
## takes depends on the scene, the driver and the machine.
func _update_settling()-> void:
	var compiled:bool = false
	for count in _pipeline_delta.values():
		if count > 0:
			compiled = true
			break

	_quiet_frames = 0 if compiled else _quiet_frames + 1

	if _quiet_frames < SETTLE_QUIET_FRAMES and _frames < SETTLE_MAX_FRAMES:
		return

	_settled = true
	# Everything measured so far was the game loading. Throw it away rather
	# than let it sit in the percentiles for the next 2000 frames.
	reset()


## The measurement reports 0.0 until it has been running a couple of frames.
## Rather than assume how many, watch for the first real reading -- and give up
## after a while, since a viewport that draws nothing reads 0.00 forever and
## that is a true answer rather than a pending one.
func _update_render_time_liveness()-> void:
	if _render_time_live: return
	if not _measured_rid.is_valid(): return

	_render_time_frames += 1
	var cpu:float = RenderingServer.viewport_get_measured_render_time_cpu(_measured_rid)
	var gpu:float = RenderingServer.viewport_get_measured_render_time_gpu(_measured_rid)

	if cpu > 0.0 or gpu > 0.0 or _render_time_frames > RENDER_TIME_SETTLE_FRAMES:
		_render_time_live = true


## Frame time in ms at the given percentile, 0-100. p50 is the median frame;
## p99 is the worst 1%, which is where stutter shows up. Nearest-rank.
func percentile(p:float)-> float:
	if _count == 0: return 0.0
	var sorted:PackedFloat32Array = _sorted_samples()
	var rank:int = int(ceil(clampf(p, 0.0, 100.0) / 100.0 * sorted.size())) - 1
	return sorted[clampi(rank, 0, sorted.size() - 1)]


func p50()-> float: return percentile(50.0)
func p95()-> float: return percentile(95.0)
func p99()-> float: return percentile(99.0)


## Longest recorded frame still inside the sample window. Unlike peak_ms this
## ages out, so it describes the recent past rather than the whole session.
func max_ms()-> float:
	if _count == 0: return 0.0
	var sorted:PackedFloat32Array = _sorted_samples()
	return sorted[sorted.size() - 1]


func sample_count()-> int:
	return _count


func _sorted_samples()-> PackedFloat32Array:
	var frame:int = Engine.get_frames_drawn()
	if _sorted_at_frame == frame: return _sorted
	_sorted = _samples.slice(0, _count)
	_sorted.sort()
	_sorted_at_frame = frame
	return _sorted


## Current value of each monitor in MONITORS. Builds a dictionary, so read a
## single value with monitor() rather than indexing into this one.
func monitors()-> Dictionary:
	var out:Dictionary = {}
	for key in MONITORS:
		out[key] = Performance.get_monitor(MONITORS[key])
	return out


## One monitor by its MONITORS key, without querying or allocating the rest.
func monitor(key:String)-> float:
	if not MONITORS.has(key):
		push_warning("PerfStats: no monitor called '%s'" % key)
		return 0.0
	return Performance.get_monitor(MONITORS[key])


## Cumulative pipeline compilation counts.
func pipeline_compilations()-> Dictionary:
	var out:Dictionary = {}
	for key in PIPELINE_MONITORS:
		out[key] = int(Performance.get_monitor(PIPELINE_MONITORS[key]))
	return out


## Pipeline compilations that happened in the last frame. Non-zero here during
## play means a shader compiled mid-game, which is a stall you can see.
func pipeline_compilations_delta()-> Dictionary:
	return _pipeline_delta.duplicate()


func _update_pipeline_deltas()-> void:
	for key in PIPELINE_MONITORS:
		var now:int = int(Performance.get_monitor(PIPELINE_MONITORS[key]))
		_pipeline_delta[key] = maxi(0, now - _pipeline_prev[key])
		_pipeline_prev[key] = now


## CPU time the renderer spent on the target viewport, in ms. Small next to the
## GPU figure means the frame is GPU-bound and no amount of script work will
## help; large means the opposite. Check has_render_time() first -- 0.0 here
## means "no reading yet" as well as "cost nothing".
func render_time_cpu_ms()-> float:
	if not _measured_rid.is_valid() or not _render_time_live: return 0.0
	return RenderingServer.viewport_get_measured_render_time_cpu(_measured_rid)


## GPU time for the target viewport, in ms. Reported a frame or two behind the
## current frame, which is inherent to how the GPU is timed.
func render_time_gpu_ms()-> float:
	if not _measured_rid.is_valid() or not _render_time_live: return 0.0
	return RenderingServer.viewport_get_measured_render_time_gpu(_measured_rid)


## Name of the viewport being measured, for display.
func target_name()-> String:
	if not is_instance_valid(target_viewport): return "none"
	if target_viewport == get_viewport(): return "root"
	return target_viewport.name


## The game scene is torn down and rebuilt often enough (prestige resets, scene
## changes) that the target is re-resolved rather than held onto.
##
## The fallback deliberately does not latch. Autoloads are ready before the main
## scene, so the first look at the group always comes up empty and lands on the
## root viewport; if that stuck, a project that marks a SubViewport would
## silently be measuring the wrong thing forever.
func _resolve_target()-> void:
	if is_instance_valid(target_viewport) and not _using_fallback: return

	# Still hoping for a marked viewport to appear. Cheap, but no reason to do
	# it every single frame.
	if is_instance_valid(target_viewport):
		_recheck_in -= 1
		if _recheck_in > 0: return
	_recheck_in = TARGET_RECHECK_FRAMES

	var found:Viewport = _find_marked_viewport()
	_using_fallback = found == null
	_set_target(found if found != null else get_viewport())


## The viewport marked with BaseGroups.PERF_TARGET, or null when nothing is
## marked. Static so the toggles resolve the same viewport the stats measure,
## without either having to depend on the other being registered.
static func find_marked_viewport(tree:SceneTree)-> Viewport:
	for node in tree.get_nodes_in_group(BaseGroups.PERF_TARGET):
		var viewport:Viewport = node as Viewport
		if viewport == null: viewport = node.get_viewport()
		if viewport != null: return viewport
	return null


func _find_marked_viewport()-> Viewport:
	var marked:Array[Node] = get_tree().get_nodes_in_group(BaseGroups.PERF_TARGET)

	if marked.size() > 1 and not _warned_multiple_targets:
		_warned_multiple_targets = true
		push_warning(("PerfStats: %d nodes in the '%s' group, expected one. " +
			"Measuring the first, which may not be the one you meant.") % [
			marked.size(), BaseGroups.PERF_TARGET])

	return find_marked_viewport(get_tree())


func _set_target(viewport:Viewport)-> void:
	if viewport == target_viewport: return
	_stop_measuring()
	target_viewport = viewport
	if not is_instance_valid(viewport): return

	_measured_rid = viewport.get_viewport_rid()
	RenderingServer.viewport_set_measure_render_time(_measured_rid, true)

	# A newly enabled measurement needs its own couple of frames before it
	# reports anything, whether or not the old one was already live.
	_render_time_live = false
	_render_time_frames = 0


func _stop_measuring()-> void:
	if not _measured_rid.is_valid(): return
	# RID.is_valid() only says the RID is not null -- it does not say the
	# viewport behind it still exists. On teardown the viewport is often freed
	# first, leaving this RID dangling, and the server rejects it. There is
	# nothing to switch off in that case: the measurement died with the
	# viewport.
	if is_instance_valid(target_viewport):
		RenderingServer.viewport_set_measure_render_time(_measured_rid, false)
	_measured_rid = RID()
