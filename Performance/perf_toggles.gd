extends Node
class_name BasePerformanceToggles
## Reversible switches for bisecting where a frame's time goes, driven from a
## panel or from the command line.
##
## Register this as the `PerfToggles` autoload -- as a project subclass, which
## adds its own toggles by overriding _register_project_toggles(). Do not
## override _ready: in Godot 4.7 _ready does not chain, so a subclass that
## defines one without calling super() silently loses the panel and every
## generic toggle.
##
## Toggles come in three tiers, and only the third needs any project setup:
##
##   1. Global      -- the tree, the engine. No node lookup at all.
##   2. Class-based -- every Light3D, every WorldEnvironment. Found by walking,
##                     so no configuration either.
##   3. Viewport    -- resolution, debug draw. These need to know WHICH
##                     viewport, which is what BaseGroups.PERF_TARGET is for.
##
## Read the numbers off the DebugInfo readout (PerfStats) while flipping these.
## Two habits worth keeping from the earlier investigations:
##
##  * Interleave with a baseline. Frame-time A/B on a busy scene has a noise
##    band wide enough to manufacture a convincing result from one comparison.
##    Flip back and forth, not once.
##  * If turning everything off changes nothing, the cost is in whatever you
##    held constant. That is the moment to invert the bisect rather than keep
##    subtracting -- a whole investigation here missed the lights because every
##    arm kept them alive by construction.

signal toggles_changed

const PANEL_SCENE:PackedScene = preload(
	"res://GodotBase/Performance/PerfTogglesPanel/perf_toggles_panel.tscn")

## Command line switch, e.g. `-- --perf=lights_off,scale_50`.
const PERF_ARG:String = "--perf"

## Where the fps cap lands when uncapping. Never 0: uncapped play on a scene
## that is already near saturation is a resource-exhaustion loop, and it has
## hard-frozen a machine here before.
const UNCAPPED_FPS:int = 240

## Frames to keep retrying the command line toggles while the scene loads.
## Autoloads are ready long before there is anything to act on.
const CLI_RETRY_FRAMES:int = 300

var toggles:Array[PerfToggle] = []
var by_id:Dictionary[String, PerfToggle] = {}

var _panel:CanvasLayer
var _pending_cli:PackedStringArray = PackedStringArray()
var _cli_frames_left:int = 0


func _ready()-> void:
	if not Flags.DEBUG:
		set_process(false)
		return

	# Pausing the game is itself a toggle, so this has to keep running while
	# paused -- otherwise the switch that pauses could never switch back.
	process_mode = Node.PROCESS_MODE_ALWAYS

	_register_global_toggles()
	_register_class_toggles()
	_register_viewport_toggles()
	_register_project_toggles()

	_panel = PANEL_SCENE.instantiate()
	add_child(_panel)

	_read_command_line()


## Override in the project subclass to add game-specific toggles. Slots 7-9 are
## reserved for these; 0-6 belong to GodotBase.
func _register_project_toggles()-> void:
	pass


## Override to point the "stop saving" toggle at the project's game state.
## Returning null simply leaves that toggle unregistered.
func _get_game_state()-> BaseGameState:
	return null


#region Registration

func register(id:String, label:String, apply:Callable, slot:int = -1,
		undo:Callable = Callable())-> PerfToggle:
	if by_id.has(id):
		push_warning("PerfToggles: '%s' registered twice, keeping the first" % id)
		return by_id[id]

	var toggle := PerfToggle.new(id, label, apply, slot, undo)
	toggles.append(toggle)
	by_id[id] = toggle
	return toggle


func set_active(toggle:PerfToggle, on:bool)-> void:
	if toggle == null: return

	if on:
		toggle.activate()
		if toggle.missing_targets:
			push_warning(("PerfToggles: '%s' found nothing to act on. " +
				"Treat any measurement taken with it as meaningless.") % toggle.id)
	else:
		toggle.deactivate()

	toggles_changed.emit()


func flip(toggle:PerfToggle)-> void:
	set_active(toggle, not toggle.active)


func flip_id(id:String)-> void:
	if not by_id.has(id):
		push_warning("PerfToggles: no toggle called '%s'" % id)
		return
	flip(by_id[id])


func flip_slot(slot:int)-> void:
	for toggle in toggles:
		if toggle.slot == slot:
			flip(toggle)
			return


## Turns everything off, so a measurement can start from a known state.
func reset_all()-> void:
	for toggle in toggles:
		toggle.deactivate()
	toggles_changed.emit()

#endregion


#region Targeting

## The viewport the toggles act on: whatever is marked with
## BaseGroups.PERF_TARGET, falling back to the root viewport.
func target_viewport()-> Viewport:
	var marked:Viewport = PerformanceStats.find_marked_viewport(get_tree())
	return marked if marked != null else get_viewport()


## Root of the 3D content inside the target viewport, for the toggles that walk
## it. The viewport itself, since everything hangs off it.
func target_root()-> Node:
	return target_viewport()


func _lights()-> Array[Node]:
	return Utils.get_all_subnodes_of_type(target_root(), "Light3D")


func _environments()-> Array[Node]:
	return Utils.get_all_subnodes_of_type(target_root(), "WorldEnvironment")

#endregion


#region Tier 1: global

func _register_global_toggles()-> void:
	register("pause", "pause game (rendering continues)",
		func(t:PerfToggle): t.change(get_tree(), "paused", true), 0)

	# The cleanest CPU-vs-GPU split available: pausing stops all script and
	# physics work while drawing exactly the same pixels. If the frame time
	# barely moves, no amount of script optimisation will help.

	register("uncap", "uncap fps (vsync off, capped at %d)" % UNCAPPED_FPS,
		_apply_uncap, -1, _undo_uncap)

	register("physics_30", "physics at 30 ticks",
		func(t:PerfToggle): t.change(Engine, "physics_ticks_per_second", 30))

	register("time_half", "time scale 0.5",
		func(t:PerfToggle): t.change(Engine, "time_scale", 0.5))

	var state:BaseGameState = _get_game_state()
	if state != null:
		register("saving_off", "stop saving (progress stops persisting)",
			func(t:PerfToggle):
				var current:BaseGameState = _get_game_state()
				if current != null: t.change(current, "saving_enabled", false))


## vsync and the fps cap are deliberately one toggle. Separately, "vsync off"
## with the default max_fps of 0 means genuinely unlimited, which is how a
## machine got hard-frozen here measuring this very game. Bundled, the
## dangerous combination cannot be selected.
func _apply_uncap(toggle:PerfToggle)-> void:
	toggle.change(Engine, "max_fps", UNCAPPED_FPS)
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)


func _undo_uncap(_toggle:PerfToggle)-> void:
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_ENABLED)

#endregion


#region Tier 2: class-based

func _register_class_toggles()-> void:
	register("lights_off", "all lights off",
		func(t:PerfToggle):
			for light in _lights():
				if (light as Light3D).visible: t.change(light, "visible", false),
		1)

	register("one_light", "one directional light only",
		_apply_one_light, 2)

	register("shadows_off", "shadows off",
		func(t:PerfToggle):
			for light in _lights():
				if (light as Light3D).shadow_enabled:
					t.change(light, "shadow_enabled", false),
		3)

	register("env_off", "world environment off",
		func(t:PerfToggle):
			for env in _environments():
				if (env as WorldEnvironment).environment != null:
					t.change(env, "environment", null))

	register("hide_content", "hide content (keep cameras and lights)",
		_apply_hide_content, 4)


## Keeps the first DirectionalLight3D so the scene stays legible, hides the
## rest. Between this and lights_off, "is it the light count or one specific
## light" takes two keypresses.
func _apply_one_light(toggle:PerfToggle)-> void:
	var kept:bool = false
	for light in _lights():
		if light is DirectionalLight3D and not kept:
			kept = true
			continue
		if (light as Light3D).visible: toggle.change(light, "visible", false)


## Hides the topmost visible Node3D that is neither a camera nor a light, and
## does not descend into what it hid.
##
## Only ever hides, never shows: a blind toggle would switch ON nodes that ship
## hidden and end up measuring a heavier scene than the one being asked about.
func _apply_hide_content(toggle:PerfToggle)-> void:
	var pending:Array[Node] = [target_root()]

	while not pending.is_empty():
		var node:Node = pending.pop_back()
		var node_3d:Node3D = node as Node3D

		if node_3d != null and not (node is Camera3D or node is Light3D):
			if node_3d.visible:
				toggle.change(node_3d, "visible", false)
			# Hidden either way -- nothing underneath is drawing.
			continue

		pending.append_array(node.get_children())

#endregion


#region Tier 3: viewport-scoped

func _register_viewport_toggles()-> void:
	for scale in [0.75, 0.5, 0.25]:
		var value:float = scale
		register("scale_%d" % int(value * 100), "3D render scale %.2f" % value,
			func(t:PerfToggle):
				t.change(target_viewport(), "scaling_3d_scale", value),
			5 if is_equal_approx(value, 0.5) else -1)

	register("fsr", "3D scaling mode FSR",
		func(t:PerfToggle):
			t.change(target_viewport(), "scaling_3d_mode",
				Viewport.SCALING_3D_MODE_FSR))

	register("msaa_off", "MSAA off",
		func(t:PerfToggle):
			t.change(target_viewport(), "msaa_3d", Viewport.MSAA_DISABLED))

	register("overdraw", "overdraw view", _apply_overdraw, 6)

	register("wireframe", "wireframe view",
		func(t:PerfToggle):
			t.change(target_viewport(), "debug_draw",
				Viewport.DEBUG_DRAW_WIREFRAME))

	register("unshaded", "unshaded view",
		func(t:PerfToggle):
			t.change(target_viewport(), "debug_draw",
				Viewport.DEBUG_DRAW_UNSHADED))

	register("shrink_2", "container shrink 2x", _apply_shrink)


## transparent_bg goes off with it, so the additive overdraw result is read
## against black instead of whatever is layered behind the viewport.
func _apply_overdraw(toggle:PerfToggle)-> void:
	var viewport:Viewport = target_viewport()
	toggle.change(viewport, "transparent_bg", false)
	toggle.change(viewport, "debug_draw", Viewport.DEBUG_DRAW_OVERDRAW)


func _apply_shrink(toggle:PerfToggle)-> void:
	var container := target_viewport().get_parent() as SubViewportContainer
	if container == null: return
	toggle.change(container, "stretch", true)
	toggle.change(container, "stretch_shrink", 2)

#endregion


#region Command line

## `godot --path . -- --perf=lights_off,scale_50`, for measuring a named
## combination without touching the keyboard.
func _read_command_line()-> void:
	var value:String = CommandLineManager.get_value(PERF_ARG)
	if value.is_empty(): return

	_pending_cli = PackedStringArray()
	for id in value.split(",", false):
		var trimmed:String = id.strip_edges()
		if trimmed.is_empty(): continue
		if not by_id.has(trimmed):
			push_warning("PerfToggles: --perf named '%s', which does not exist" % trimmed)
			continue
		_pending_cli.append(trimmed)

	# Applied over the following frames rather than now: most of these need a
	# loaded scene, and this runs before there is one.
	_cli_frames_left = CLI_RETRY_FRAMES


func _process(_delta:float)-> void:
	if _cli_frames_left <= 0: return
	_cli_frames_left -= 1

	# Keep retrying until each toggle actually finds something, or the window
	# runs out -- then say plainly which ones never landed.
	var all_landed:bool = true
	for id in _pending_cli:
		var toggle:PerfToggle = by_id[id]
		if toggle.active and not toggle.missing_targets: continue

		if toggle.active: toggle.deactivate()
		toggle.activate()
		if toggle.missing_targets: all_landed = false

	if all_landed or _cli_frames_left <= 0:
		_cli_frames_left = 0
		_report_cli()
		toggles_changed.emit()


func _report_cli()-> void:
	for id in _pending_cli:
		var toggle:PerfToggle = by_id[id]
		if toggle.missing_targets:
			push_warning(("PerfToggles: --perf toggle '%s' never found anything " +
				"to act on. Any measurement from this run is meaningless.") % id)
		else:
			print("PerfToggles: '%s' applied to %d objects" % [
				id, toggle.target_count()])

#endregion
