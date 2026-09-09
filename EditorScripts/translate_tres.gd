@tool
## Collects translatable strings that live inside .tres resources and merges them
## with the .pot the editor generates from scenes and scripts.
##
## Godot's built-in POT generation only scans the files listed in
## Project Settings > Localization > POT Generation, and it does not look at the
## String properties of custom resources. Any text authored in a .tres (item
## names, descriptions, tooltips, ...) would therefore never reach the
## translators. This script walks every .tres under res:// (skipping addons/,
## which holds third party resources), pulls out every non-empty String it can
## reach from a property (including strings nested inside Arrays, Dictionaries
## and sub-resources embedded in the same file), writes them to a temporary
## .pot, and merges that with the editor-generated .pot into a single template.
##
## Each extracted string gets a "#:" reference comment naming the resource path
## and the trail of properties, indices and keys followed to reach it, e.g.
## "#: res://Foo/bar.tres:display_name", "#: res://Foo/bar.tres:lines[2]" or
## "#: res://Foo/bar.tres:reward.lines[2]". Duplicated strings are collapsed
## into one entry that carries all of its references. All msgstr entries are
## left empty: this produces a template, never a translation.
##
## Usage:
##   1. In Project Settings > Localization > POT Generation, list the scenes and
##      scripts holding translatable text and press "Generate POT", saving it to
##      the path in the "godot_pot" setting below.
##   2. Open this file in the script editor and run it with
##      File > Run (Ctrl+Shift+X). It is an EditorScript, so it only runs from
##      the editor and is never part of the exported game.
##   3. The merged template is written to the "merged_pot" setting's path. Feed
##      that file to the translation tool (Poedit, msgmerge, ...) to create or
##      update the .po files, and add the resulting translations in
##      Project Settings > Localization > Translations.
##
## The settings live under "translation/tres_extraction/" in Project > Project
## Settings, and appear there once this script has been run once in the current
## editor session (or right away, with the tres_translation plugin enabled):
##
##   godot_pot, tres_pot, merged_pot
##       The three .pot paths described above.
##   excluded_dirs
##       Folder names never walked into, addons/ by default.
##   included_scripts
##       Script paths. While it is empty every .tres and every sub-resource in
##       it is read; otherwise only those whose script is one of them, or
##       derives from one.
##   required_group_pattern
##       While it is empty every property is read; otherwise only those sitting
##       in an @export_group or @export_subgroup whose name matches it.
##   required_name_pattern, excluded_name_pattern
##       Properties whose name fails the first or matches the second are
##       skipped. Either one empty is that filter off.
##   excluded_value_pattern
##       Strings matching it are skipped whatever property they came from, so a
##       project marking its placeholders "##" can set "^##" and keep them out
##       of the template.
##
## The patterns are regular expressions, searched for anywhere in the name or
## string: "^Text$" is how a whole-name match is asked for. A project that
## leaves every setting at its default behaves exactly as it did when the paths
## were hardcoded and nothing was filtered, and keeps project.godot free of them.
##
## Re-run it after adding or editing text anywhere; it overwrites the tres and
## merged .pot files from scratch every time. If the project is not set up yet
## (missing locales folder, empty POT generation list, missing generated .pot)
## the script aborts with a warning explaining what to fix instead of writing a
## partial template.
extends EditorScript
class_name TranslateTresFiles

## Prefix of the project settings this script reads.
const SETTINGS_PREFIX := "translation/tres_extraction/"

## Project setting holding the files the editor scans when generating the
## Godot-side .pot.
const POT_FILES_SETTING := "internationalization/locale/translations_pot_files"

## The settings this script registers, in the order they appear in the
## Project Settings list. "hint_string" doubles as the file filter for the
## paths and is unused for the folder list. A static var rather than a const
## because PackedStringArray() is not a constant expression.
static var SETTINGS := [
	{
		"key": "godot_pot",
		"type": TYPE_STRING,
		"hint": PROPERTY_HINT_FILE,
		"hint_string": "*.pot",
		"default": "res://locales/auto_template.pot",
	},
	{
		"key": "tres_pot",
		"type": TYPE_STRING,
		"hint": PROPERTY_HINT_FILE,
		"hint_string": "*.pot",
		"default": "res://locales/tres_template.pot",
	},
	{
		"key": "merged_pot",
		"type": TYPE_STRING,
		"hint": PROPERTY_HINT_FILE,
		"hint_string": "*.pot",
		"default": "res://locales/complete_template.pot",
	},
	{
		# Third party code shipped in addons/ carries its own strings, which are
		# not ours to translate.
		"key": "excluded_dirs",
		"type": TYPE_PACKED_STRING_ARRAY,
		"hint": PROPERTY_HINT_NONE,
		"hint_string": "",
		"default": PackedStringArray(["addons"]),
	},
	{
		"key": "required_group_pattern",
		"type": TYPE_STRING,
		"hint": PROPERTY_HINT_NONE,
		"hint_string": "",
		"default": "",
	},
	{
		"key": "required_name_pattern",
		"type": TYPE_STRING,
		"hint": PROPERTY_HINT_NONE,
		"hint_string": "",
		"default": "",
	},
	{
		"key": "excluded_name_pattern",
		"type": TYPE_STRING,
		"hint": PROPERTY_HINT_NONE,
		"hint_string": "",
		"default": "",
	},
	{
		"key": "excluded_value_pattern",
		"type": TYPE_STRING,
		"hint": PROPERTY_HINT_NONE,
		"hint_string": "",
		"default": "",
	},
	{
		# The hint an "@export_file("*.gd") var x: PackedStringArray" gets, which
		# gives every element of the array its own file picker.
		"key": "included_scripts",
		"type": TYPE_PACKED_STRING_ARRAY,
		"hint": PROPERTY_HINT_TYPE_STRING,
		"hint_string": "%d/%d:*.gd" % [TYPE_STRING, PROPERTY_HINT_FILE],
		"default": PackedStringArray(),
	},
]

var godot_pot: String      # Godot-generated .pot
var tres_pot: String       # Temp .pot for .tres strings
var merged_pot: String     # Final merged .pot
var excluded_dirs: PackedStringArray  # Folder names skipped while walking res://
var required_group_pattern: String    # Only groups/subgroups matching it are extracted
var required_name_pattern: String     # Only properties matching it are extracted
var excluded_name_pattern: String     # Properties matching it are never extracted
var excluded_value_pattern: String    # Strings matching it are never extracted
var included_scripts: PackedStringArray  # Only resources using these scripts are read

# The four patterns above, compiled. Null when the setting they come from is
# empty, which is what turns that filter off.
var _required_group_regex: RegEx
var _required_name_regex: RegEx
var _excluded_name_regex: RegEx
var _excluded_value_regex: RegEx

func _run():
	if not load_settings():
		return

	# Without this the run still "succeeds", writing a merged .pot missing every
	# string that lives outside a .tres.
	if not check_setup():
		return

	var tres_entries = extract_all_tres_strings("res://")
	if not generate_pot_file(tres_entries, tres_pot):
		return
	if not merge_pot_files(godot_pot, tres_pot, merged_pot):
		return
	print("✅ Strings extracted and merged into: %s" % merged_pot)


# --- Declare the settings so Project Settings shows them, typed and revertable ---
# Called by the TresTranslationSettings editor plugin at editor startup, and
# again by load_settings() so the script still works in a project that does not
# have the plugin enabled.
#
# Nothing is saved here. set_initial_value() marks the defaults as defaults, and
# Godot only writes a setting to project.godot once it differs from its default,
# so a project that leaves them all alone keeps a project.godot free of them and
# the editor persists whichever ones the user does change.
static func register_settings() -> void:
	for setting in SETTINGS:
		var setting_name: String = SETTINGS_PREFIX + setting["key"]
		if not ProjectSettings.has_setting(setting_name):
			ProjectSettings.set_setting(setting_name, setting["default"])
		# Re-applied every time: neither the property info nor the initial value
		# lives in project.godot, so without this the setting comes back as an
		# untyped raw value with no revert arrow after an editor restart.
		ProjectSettings.set_initial_value(setting_name, setting["default"])
		ProjectSettings.set_as_basic(setting_name, true)
		ProjectSettings.add_property_info({
			"name": setting_name,
			"type": setting["type"],
			"hint": setting["hint"],
			"hint_string": setting["hint_string"],
		})


# --- Read the settings into the fields above ---
# Returns false if one of the pattern settings does not compile. Carrying on
# with that filter off would quietly export everything it was meant to hold
# back, so a typo in a pattern stops the run instead.
func load_settings() -> bool:
	register_settings()
	godot_pot = get_setting_value("godot_pot")
	tres_pot = get_setting_value("tres_pot")
	merged_pot = get_setting_value("merged_pot")
	excluded_dirs = get_setting_value("excluded_dirs")
	required_group_pattern = get_setting_value("required_group_pattern")
	required_name_pattern = get_setting_value("required_name_pattern")
	excluded_name_pattern = get_setting_value("excluded_name_pattern")
	excluded_value_pattern = get_setting_value("excluded_value_pattern")
	included_scripts = get_setting_value("included_scripts")

	_required_group_regex = _compile_pattern("required_group_pattern", required_group_pattern)
	_required_name_regex = _compile_pattern("required_name_pattern", required_name_pattern)
	_excluded_name_regex = _compile_pattern("excluded_name_pattern", excluded_name_pattern)
	_excluded_value_regex = _compile_pattern("excluded_value_pattern", excluded_value_pattern)
	return ((required_group_pattern.is_empty() or _required_group_regex != null)
		and (required_name_pattern.is_empty() or _required_name_regex != null)
		and (excluded_name_pattern.is_empty() or _excluded_name_regex != null)
		and (excluded_value_pattern.is_empty() or _excluded_value_regex != null))


# --- Read one of the settings declared in SETTINGS ---
# ProjectSettings.get_setting() answers null for a setting that is not
# registered, and that null then fails to assign to the typed field it was read
# into, stopping the run on an error naming neither the setting nor the reason.
# Reading through the default declared here instead means an unregistered
# setting behaves as one left untouched, which is what an editor session that
# has not picked up a newly added setting yet needs to get through a run.
static func get_setting_value(key: String) -> Variant:
	for setting in SETTINGS:
		if setting["key"] == key:
			return ProjectSettings.get_setting(SETTINGS_PREFIX + key, setting["default"])
	push_error("'%s' is not one of this script's settings" % key)
	return null


# --- Compile one of the pattern settings ---
# Returns null both for an empty setting (the filter is off) and for one that
# does not compile; load_settings() tells the two apart.
func _compile_pattern(key: String, pattern: String) -> RegEx:
	if pattern.is_empty():
		return null
	var regex := RegEx.new()
	if regex.compile(pattern) != OK:
		push_error("'%s%s' is not a valid regular expression: %s" % [
			SETTINGS_PREFIX, key, pattern])
		return null
	return regex


# --- Verify the project is set up for translation before doing any work ---
# Returns false (after explaining what is missing) if it is not.
func check_setup()-> bool:
	var locales_dir := godot_pot.get_base_dir()
	if not DirAccess.dir_exists_absolute(locales_dir):
		var err := DirAccess.make_dir_recursive_absolute(locales_dir)
		if err != OK:
			push_error("Could not create %s (error %d)" % [locales_dir, err])
			return false
		print("Created missing folder: %s" % locales_dir)

	var pot_files:PackedStringArray = ProjectSettings.get_setting(POT_FILES_SETTING, PackedStringArray())
	if pot_files.is_empty():
		push_warning(
			"POT generation is not configured: '%s' is empty. " % POT_FILES_SETTING
			+ "Open Project > Project Settings > Localization > POT Generation, "
			+ "add the scenes and scripts holding translatable text, then generate "
			+ "the .pot into '%s'." % godot_pot)
		return false

	if not FileAccess.file_exists(godot_pot):
		push_warning(
			"'%s' does not exist yet, so only .tres strings would be collected. " % godot_pot
			+ "Open Project > Project Settings > Localization > POT Generation and "
			+ "press 'Generate POT', saving it to that exact path.")
		return false

	return true

# --- Recursively extract all string properties from .tres files ---
# Returns a Dictionary: key = string, value = array of comment lines
func extract_all_tres_strings(root_path: String) -> Dictionary:
	var result := {}
	_scan_dir(root_path, result)
	return result

# get_files() and get_directories() return their entries sorted, while
# list_dir_begin()/get_next() return them in filesystem order, which changes
# when a folder is modified. Both the order of the entries and the order of the
# "#:" comment lines within one entry follow this walk, so an unsorted one makes
# each regenerated .pot differ from the last one wherever the filesystem
# happened to reshuffle, for no change in the strings themselves.
func _scan_dir(current_path: String, result: Dictionary) -> void:
	var dir = DirAccess.open(current_path)
	if dir == null:
		push_error("Cannot open folder: %s" % current_path)
		return
	for file_name in dir.get_files():
		if file_name.ends_with(".tres"):
			var path := current_path.path_join(file_name)
			var res = ResourceLoader.load(path)
			if res and _resource_is_included(res):
				_extract_resource_strings(path, res, result)
	for dir_name in dir.get_directories():
		if not dir_name in excluded_dirs:
			_scan_dir(current_path.path_join(dir_name), result)


# --- Pull the translatable strings out of one loaded resource ---
func _extract_resource_strings(path: String, res: Resource, result: Dictionary) -> void:
	_extract_object_strings(path, "", res, result, [res])


# --- Walk one object's properties, recording every string they lead to ---
# `reference` is the trail of property names, indices and keys followed to reach
# `obj` from the resource saved at `path`, empty for that resource itself. It is
# what the "#:" comment of every string found below this point is built from.
func _extract_object_strings(path: String, reference: String, obj: Object,
		result: Dictionary, seen: Array) -> void:
	# Groups and subgroups are entries of the property list rather than fields of
	# the properties they hold: each one applies to the properties that follow it
	# until the next entry of its kind. A category entry opens the section of the
	# next script up the inheritance chain, where neither applies any more.
	var group := ""
	var subgroup := ""

	for prop in obj.get_property_list():
		if prop.usage & PROPERTY_USAGE_CATEGORY:
			group = ""
			subgroup = ""
			continue
		if prop.usage & PROPERTY_USAGE_GROUP:
			group = prop.name
			subgroup = ""
			continue
		if prop.usage & PROPERTY_USAGE_SUBGROUP:
			subgroup = prop.name
			continue
		if prop.usage & PROPERTY_USAGE_EDITOR == 0:
			continue
		if prop.name.begins_with("_"):
			continue
		if prop.name in ["resource_path", "resource_name", "metadata/_custom_type_script"]:
			continue
		if not _property_is_included(prop.name, group, subgroup):
			continue

		var child_reference: String = (prop.name if reference.is_empty()
			else "%s.%s" % [reference, prop.name])
		_extract_value(path, child_reference, obj.get(prop.name), result, seen)


# --- Record every string one value holds, whatever shape it comes in ---
# Arrays, Dictionaries and sub-resources are walked into rather than read, so a
# string sits in the .pot no matter how deep in a property it is nested. Only
# the values of a Dictionary are looked at: its keys identify entries, they are
# not text shown to the player.
func _extract_value(path: String, reference: String, value: Variant,
		result: Dictionary, seen: Array) -> void:
	match typeof(value):
		TYPE_STRING:
			var text: String = value
			if not _string_is_included(text):
				return
			if not result.has(text):
				result[text] = []
			result[text].append("#: %s:%s" % [path, reference])
		TYPE_ARRAY:
			var array: Array = value
			for i in array.size():
				_extract_value(path, "%s[%d]" % [reference, i], array[i], result, seen)
		TYPE_DICTIONARY:
			var dict: Dictionary = value
			for key in dict:
				_extract_value(path, "%s[%s]" % [reference, _dict_key_label(key)],
					dict[key], result, seen)
		TYPE_OBJECT:
			_extract_sub_resource_strings(path, reference, value, result, seen)


# --- Walk into a sub-resource, if it is one this run should read ---
# Only resources embedded in the file being read are followed. One saved in its
# own .tres is left alone: _scan_dir() reaches it on its own, and following it
# from here would repeat its strings under every resource pointing at it, with
# references naming those resources instead of the file the text lives in.
#
# `seen` holds the resources already walked, and is never emptied: a resource
# used by two properties of the same file is read under the first of them. That
# both keeps a cycle from sending the walk around forever and keeps one string
# from collecting a reference per path leading to it.
func _extract_sub_resource_strings(path: String, reference: String, value: Variant,
		result: Dictionary, seen: Array) -> void:
	if not (value is Resource):
		return
	var res: Resource = value
	var is_embedded := (res.resource_path.is_empty()
		or res.resource_path.begins_with(path + "::"))
	if not is_embedded or not _resource_is_included(res) or seen.has(res):
		return
	seen.append(res)
	_extract_object_strings(path, reference, res, result, seen)


# --- Decide whether a resource is one the "included_scripts" setting asks for ---
# A resource whose script derives from a listed one counts as included, so
# listing a base class covers every resource written against it.
func _resource_is_included(res: Resource) -> bool:
	if included_scripts.is_empty():
		return true
	var script: Script = res.get_script()
	while script != null:
		if script.resource_path in included_scripts:
			return true
		script = script.get_base_script()
	return false


# --- Decide whether one property's strings should reach the .pot ---
# `group` and `subgroup` are the ones the property sits in, empty when it sits
# in none. The patterns are searched for anywhere in the name, so "^Text$" is
# how a whole-name match is asked for.
func _property_is_included(prop_name: String, group: String, subgroup: String) -> bool:
	if _required_group_regex != null:
		var group_matches := (not group.is_empty()
			and _required_group_regex.search(group) != null)
		var subgroup_matches := (not subgroup.is_empty()
			and _required_group_regex.search(subgroup) != null)
		if not (group_matches or subgroup_matches):
			return false
	if _required_name_regex != null and _required_name_regex.search(prop_name) == null:
		return false
	if _excluded_name_regex != null and _excluded_name_regex.search(prop_name) != null:
		return false
	return true


# --- Decide whether one string found in a property should reach the .pot ---
# An empty string holds no text to translate. "excluded_value_pattern" holds
# back the rest, and is searched for anywhere in the string: a project marking
# its placeholders "##" sets it to "^##" to keep them out of the template.
func _string_is_included(text: String) -> bool:
	if text.is_empty():
		return false
	if _excluded_value_regex != null and _excluded_value_regex.search(text) != null:
		return false
	return true


# --- Name a Dictionary key for the "#:" reference comment of its value ---
# str() on a Resource ends in its object id, which is different on every run:
# using it would make each regenerated .pot differ from the last one on those
# lines alone, for no change in the strings themselves.
func _dict_key_label(key: Variant) -> String:
	if key is Resource:
		var res: Resource = key
		if not res.resource_path.is_empty():
			return res.resource_path
		if not res.resource_name.is_empty():
			return res.resource_name
		# A built-in resource with neither: its class is all that identifies it,
		# and a vague reference beats one that churns.
		return res.get_class()
	return str(key)


# --- Generate a .pot file from Dictionary with comments ---
func generate_pot_file(entries: Dictionary, pot_path: String)-> bool:
	var f = FileAccess.open(pot_path, FileAccess.WRITE)
	if f == null:
		push_error("Cannot write .pot file '%s': error %d" % [
			pot_path, FileAccess.get_open_error()])
		return false
	for msgid in entries.keys():
		# Write all comment lines
		for comment in entries[msgid]:
			f.store_line(comment)
		_store_po_string(f, "msgid", msgid)
		f.store_line('msgstr ""')
		f.store_line("")
	f.close()
	return true


# --- Write a keyword and its string as a .pot entry ---
# A string spanning several lines is written the way gettext tools (and Godot's
# own POT generator) write it: an empty first line, then one line per newline
# terminated chunk. Writing the newline raw instead would end the quoted string
# mid-entry and produce a .pot no translation tool can read.
func _store_po_string(f: FileAccess, keyword: String, text: String) -> void:
	var chunks := text.split("\n")
	if chunks.size() == 1:
		f.store_line('%s "%s"' % [keyword, _po_escape(text)])
		return

	f.store_line('%s ""' % keyword)
	for i in chunks.size():
		var chunk: String = chunks[i]
		if i < chunks.size() - 1:
			# The newline split() consumed, kept as part of the message.
			chunk += "\n"
		elif chunk == "":
			# Text ending in a newline: the last chunk is empty and the newline
			# already went out with the previous one.
			continue
		f.store_line('"%s"' % _po_escape(chunk))


# --- Escape a string so it survives inside the quotes of a .pot entry ---
# Backslashes are escaped first: doing it last would escape the backslashes that
# the other replacements introduce, turning "\n" into a literal backslash-n.
func _po_escape(text: String) -> String:
	return (text
		.replace("\\", "\\\\")
		.replace('"', '\\"')
		.replace("\n", "\\n")
		.replace("\t", "\\t")
		.replace("\r", "\\r"))

				
func merge_pot_files(godot_pot: String, tres_pot: String, merged_pot: String)-> bool:
	var entries := {}

	# load both pots
	if not _load_pot_into_dict(godot_pot, entries):
		return false
	if not _load_pot_into_dict(tres_pot, entries):
		return false

	# ensure output directory exists
	var out_dir := merged_pot.get_base_dir()
	if not DirAccess.dir_exists_absolute(out_dir):
		DirAccess.make_dir_recursive_absolute(out_dir)

	# write merged file
	var f_out := FileAccess.open(merged_pot, FileAccess.WRITE)
	if f_out == null:
		push_error("Cannot write merged pot: %s" % merged_pot)
		return false

	# minimal header
	f_out.store_line('# Merged POT file')
	f_out.store_line('msgid ""')
	f_out.store_line('msgstr ""')
	f_out.store_line('')

	# write entries
	for key in entries.keys():
		var entry: Dictionary = entries[key]
		for c in entry["comments"]:
			f_out.store_line(c)
		for l in entry["msgctxt"]:
			f_out.store_line(l)
		for l in entry["msgid"]:
			f_out.store_line(l)
		# A plural message needs one msgstr per plural form. Two are enough for a
		# template: the translation tool expands them to however many forms the
		# target language has.
		if entry["msgid_plural"].is_empty():
			f_out.store_line('msgstr ""')
		else:
			for l in entry["msgid_plural"]:
				f_out.store_line(l)
			f_out.store_line('msgstr[0] ""')
			f_out.store_line('msgstr[1] ""')
		f_out.store_line("")

	f_out.close()
	print("✅ Merged POT written to: %s" % merged_pot)
	return true


# --- Read a .pot into `entries`, keyed by the identity of each message ---
# That identity is the msgctxt plus the msgid: gettext treats "to improve" with
# context "[price] to improve [a stamp's deadtime]" and "to improve" with
# context "[price] to improve [a stamp's mark bonus]" as two separate messages,
# and collapsing them would leave one of the two untranslated in game.
#
# Only the keys of a message are kept. Every msgstr is dropped and rewritten
# empty, because the output is a template.
func _load_pot_into_dict(path: String, entries: Dictionary) -> bool:
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		push_error("Cannot open '%s': error %d" % [path, FileAccess.get_open_error()])
		return false
	var lines = f.get_as_text().split("\n")
	f.close()

	# The lines of the entry being read, gathered and then split into fields once
	# the entry ends.
	var block: Array = []
	var after_msgstr := false

	for raw_line in lines:
		# Trailing \r, so a file with CRLF endings does not leave one inside
		# every string.
		var line := raw_line.rstrip("\r")
		if line.strip_edges() == "":
			_store_pot_entry(entries, block)
			block = []
			after_msgstr = false
			continue
		# Entries are separated by a blank line, but start a new one anyway if a
		# file skips it: anything that can open an entry, seen once the previous
		# entry has reached its msgstr, belongs to the next one.
		if after_msgstr and (line.begins_with("#")
				or line.begins_with("msgctxt ") or line.begins_with("msgid ")):
			_store_pot_entry(entries, block)
			block = []
			after_msgstr = false
		if line.begins_with("msgstr"):
			after_msgstr = true
		block.append(line)

	# The last entry of a file need not be followed by a blank line.
	_store_pot_entry(entries, block)
	return true


func _store_pot_entry(entries: Dictionary, block: Array) -> void:
	var comments: Array = []
	var msgctxt: Array = []
	var msgid: Array = []
	var msgid_plural: Array = []
	# Which keyword the following "..." lines continue, if any. A long string is
	# split over several lines in a .pot, and each of msgctxt/msgid/msgid_plural
	# can be split that way.
	var continues := ""

	for line in block:
		if line.begins_with("#:"):
			comments.append(line)
		elif line.begins_with("#"):
			# Other comments (translator notes, flags, the file header) are not
			# ours to carry over.
			pass
		elif line.begins_with("msgctxt "):
			msgctxt = [line]
			continues = "msgctxt"
		elif line.begins_with("msgid_plural "):
			msgid_plural = [line]
			continues = "msgid_plural"
		elif line.begins_with("msgid "):
			msgid = [line]
			continues = "msgid"
		elif line.begins_with("msgstr"):
			# Both "msgstr " and the "msgstr[0]" of a plural message: the keys of
			# this entry are complete.
			continues = ""
		elif line.begins_with("\""):
			match continues:
				"msgctxt":
					msgctxt.append(line)
				"msgid":
					msgid.append(line)
				"msgid_plural":
					msgid_plural.append(line)

	if msgid.is_empty():
		return
	# The metadata header of a .pot is the entry with an empty msgid and no
	# context. merge_pot_files() writes its own, so drop it.
	if msgctxt.is_empty() and msgid.size() == 1 and msgid[0].strip_edges() == 'msgid ""':
		return

	# A msgctxt continuation line always starts with a quote and a msgid line
	# never does, so joining them with a newline cannot make two different
	# messages share a key.
	var key := "\n".join(msgctxt) + "\n" + "\n".join(msgid)
	if not entries.has(key):
		entries[key] = {
			"comments": [],
			"msgctxt": msgctxt,
			"msgid": msgid,
			"msgid_plural": msgid_plural,
		}
	elif entries[key]["msgid_plural"].is_empty():
		# The same message can be written both with and without a plural form.
		# Keep the plural, so translators get every form they need to fill in.
		entries[key]["msgid_plural"] = msgid_plural
	for c in comments:
		if not c in entries[key]["comments"]:
			entries[key]["comments"].append(c)
