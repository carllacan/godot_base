extends SceneTree
## Prints every autoplayer on disk, one res:// path per line, and quits.
##
##   godot --headless --path . --script res://GodotBase/Autoplayers/list_autoplayers.gd
##   godot --headless --path . --script res://GodotBase/Autoplayers/list_autoplayers.gd -- res://Players
##
## Meant for a harness picking a cohort to run. Nothing is printed around the
## list: whoever asked for it knows what they asked for, and a caller reading
## stdout can tell the paths from the engine's own output by the res:// they
## start with.
##
## A script rather than a switch on the game, because a switch would have to
## stop the game from booting on its way out, and nothing about starting a game
## should have to know that listing autoplayers is a thing that happens.
##
## Not --quiet: that silences print() along with everything else, so the list
## comes out empty.
##
## Note that --script replaces the main loop, so the autoloads never come up.
## That rules out loading these resources to see what they are — every player
## class reaches an autoload sooner or later, and compiling one here fails. So
## the files are read rather than loaded: the class each names, checked against
## the project's own list of what descends from what.

## Where the autoplayers that ship with a project live, and what this scans when
## given no directory of its own.
##
## A player assigned to the build config as an inline subresource has no file
## here, so it is not something this can find. Give a player its own .tres if a
## harness should be able to see it.
const AUTOPLAYERS_DIR:String = "res://Data/Dev/Autoplayers/"

## The class a resource has to descend from to count as an autoplayer.
const AUTOPLAYER_BASE:String = "BaseAutoplayer"


func _init()-> void:
	var args:PackedStringArray = CommandLineManager.get_args()
	var dir_path:String = args[0] if args.size() > 0 else AUTOPLAYERS_DIR

	_print_autoplayers(dir_path)
	quit()


## Sorted, so two runs against the same project list them in the same order.
func _print_autoplayers(dir_path:String)-> void:
	var dir:DirAccess = DirAccess.open(dir_path)
	if dir == null:
		push_error("No autoplayer directory at %s" % dir_path)
		return

	var bases:Dictionary = _class_bases()

	var filenames:PackedStringArray = dir.get_files()
	filenames.sort()

	for filename in filenames:
		if not filename.ends_with(".tres"): continue

		var path:String = dir_path.path_join(filename)
		if _is_autoplayer(path, bases):
			print(path)


## Whether the resource at a path is built on AUTOPLAYER_BASE, going by the
## class it names and the chain that class sits in.
func _is_autoplayer(path:String, bases:Dictionary)-> bool:
	var script_class:String = _script_class_of(path)

	# Walk up until the base is reached or the chain leaves the classes the
	# project declares, which is where the built-in types begin.
	while not script_class.is_empty():
		if script_class == AUTOPLAYER_BASE: return true
		script_class = bases.get(script_class, "")

	return false


## The class named in a text resource's header, or empty when it names none.
## A .tres holds it as `script_class="Something"` on the first line, which is
## only written for scripts that declare a class_name.
func _script_class_of(path:String)-> String:
	var file:FileAccess = FileAccess.open(path, FileAccess.READ)
	if file == null: return ""

	var header:String = file.get_line()

	var pattern:RegEx = RegEx.create_from_string("script_class=\"([^\"]+)\"")
	var found:RegExMatch = pattern.search(header)

	return found.get_string(1) if found != null else ""


## Every class the project declares, mapped to the one it extends.
func _class_bases()-> Dictionary:
	var bases:Dictionary = {}

	for entry:Dictionary in ProjectSettings.get_global_class_list():
		bases[String(entry["class"])] = String(entry["base"])

	return bases
