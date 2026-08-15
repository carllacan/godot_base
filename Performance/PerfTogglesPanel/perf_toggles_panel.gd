extends CanvasLayer
## Hold-to-show list of the registered performance toggles, on the right of the
## screen, with the numbered shortcuts that flip them.
##
## The modifier hold is polled rather than bound to an input action, because a
## modifiers-only action does not work: InputMap stores such an event happily
## but nothing ever matches it, and the nearest workable binding (Shift with
## Ctrl+Alt) only fires when Shift happens to be pressed last and gives no
## usable release signal. Polling is order-independent and hides on release for
## free. Verified on 4.7; the numbered actions below are ordinary actions and
## work normally.

## Held together to show the panel.
const HOLD_KEYS:Array[Key] = [KEY_CTRL, KEY_ALT, KEY_SHIFT]
## Actions that flip a toggle, looked up by slot number. Guarded with
## InputMap.has_action, so a project that has not defined them still gets the
## panel -- and the --perf switch -- rather than an error.
const TOGGLE_ACTION:String = "debug_perf_toggle_%d"

var _owner_toggles:BasePerformanceToggles
var _list:VBoxContainer
var _rows:Array[Label] = []


func _ready()-> void:
	if not Flags.DEBUG:
		set_process(false)
		set_process_unhandled_key_input(false)
		return

	# Pausing is one of the toggles, so this must keep running while paused or
	# the panel could never be used to unpause.
	process_mode = Node.PROCESS_MODE_ALWAYS

	_owner_toggles = get_parent() as BasePerformanceToggles
	_list = %ToggleList

	# Deliberately NOT in BaseGroups.DEBUG_ELEMENTS: that group's controller
	# writes `visible` on every member, which would fight hold-to-show.
	visible = false

	if _owner_toggles != null:
		_owner_toggles.toggles_changed.connect(_refresh)
		_build_rows()

	_ignore_mouse(self)


func _build_rows()-> void:
	for toggle in _owner_toggles.toggles:
		var row := Label.new()
		_list.add_child(row)
		_rows.append(row)
	_refresh()


func _refresh()-> void:
	if _owner_toggles == null: return

	for i in _rows.size():
		if i >= _owner_toggles.toggles.size(): break
		var toggle:PerfToggle = _owner_toggles.toggles[i]

		# Every toggle is listed; only some have a shortcut. An unlisted toggle
		# would be undiscoverable, since the panel is the documentation.
		var shortcut:String = "[%d]" % toggle.slot if toggle.slot >= 0 else "   "
		var mark:String = "x" if toggle.active else " "

		var suffix:String = ""
		if toggle.active:
			suffix = "  (%d)" % toggle.target_count()
			if toggle.missing_targets: suffix = "  (NOTHING TO ACT ON)"

		_rows[i].text = "%s (%s) %s%s" % [shortcut, mark, toggle.label, suffix]


func _process(_delta:float)-> void:
	var held:bool = true
	for key in HOLD_KEYS:
		if not Input.is_key_pressed(key):
			held = false
			break

	if held == visible: return
	visible = held
	if held: _refresh()


func _unhandled_key_input(event:InputEvent)-> void:
	if not visible or _owner_toggles == null: return
	if not (event is InputEventKey and event.pressed and not event.echo): return

	for slot in 10:
		var action:String = TOGGLE_ACTION % slot
		if not InputMap.has_action(action): continue
		if event.is_action_pressed(action):
			_owner_toggles.flip_slot(slot)
			get_viewport().set_input_as_handled()
			return


func _ignore_mouse(node:Node)-> void:
	if node is Control:
		(node as Control).mouse_filter = Control.MOUSE_FILTER_IGNORE
	for child in node.get_children():
		_ignore_mouse(child)
