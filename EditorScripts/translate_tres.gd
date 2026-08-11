@tool
## Collects translatable strings that live inside .tres resources and merges them
## with the .pot the editor generates from scenes and scripts.
##
## Godot's built-in POT generation only scans the files listed in
## Project Settings > Localization > POT Generation, and it does not look at the
## String properties of custom resources. Any text authored in a .tres (item
## names, descriptions, tooltips, ...) would therefore never reach the
## translators. This script walks every .tres under res://, pulls out every
## non-empty String property (including strings inside Array and Dictionary
## properties), writes them to a temporary .pot, and merges that with the
## editor-generated .pot into a single template.
##
## Each extracted string gets a "#:" reference comment pointing at the resource
## path and property it came from, e.g. "#: res://Foo/bar.tres:display_name" or
## "#: res://Foo/bar.tres:lines[2]". Duplicated strings are collapsed into one
## entry that carries all of its references. All msgstr entries are left empty:
## this produces a template, never a translation.
##
## Usage:
##   1. In Project Settings > Localization > POT Generation, list the scenes and
##      scripts holding translatable text and press "Generate POT", saving it to
##      GODOT_POT ("res://locales/auto_template.pot").
##   2. Open this file in the script editor and run it with
##      File > Run (Ctrl+Shift+X). It is an EditorScript, so it only runs from
##      the editor and is never part of the exported game.
##   3. The merged template is written to MERGED_POT
##      ("res://locales/complete_template.pot"). Feed that file to the
##      translation tool (Poedit, msgmerge, ...) to create or update the .po
##      files, and add the resulting translations in
##      Project Settings > Localization > Translations.
##
## Re-run it after adding or editing text anywhere; it overwrites TRES_POT and
## MERGED_POT from scratch every time. If the project is not set up yet (missing
## locales folder, empty POT generation list, missing GODOT_POT) the script
## aborts with a warning explaining what to fix instead of writing a partial
## template.
extends EditorScript
class_name TranslateTresFiles

const GODOT_POT := "res://locales/auto_template.pot"   # Godot-generated .pot
const TRES_POT := "res://locales/tres_template.pot"     # Temp .pot for .tres strings
const MERGED_POT := "res://locales/complete_template.pot" # Final merged .pot

## Project setting holding the files the editor scans when generating GODOT_POT.
const POT_FILES_SETTING := "internationalization/locale/translations_pot_files"

func _run():
	# Without this the run still "succeeds", writing a merged .pot missing every
	# string that lives outside a .tres.
	if not check_setup():
		return

	var tres_entries = extract_all_tres_strings("res://")
	if not generate_pot_file(tres_entries, TRES_POT):
		return
	if not merge_pot_files(GODOT_POT, TRES_POT, MERGED_POT):
		return
	print("✅ Strings extracted and merged into: %s" % MERGED_POT)


# --- Verify the project is set up for translation before doing any work ---
# Returns false (after explaining what is missing) if it is not.
func check_setup()-> bool:
	var locales_dir := GODOT_POT.get_base_dir()
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
			+ "the .pot into '%s'." % GODOT_POT)
		return false

	if not FileAccess.file_exists(GODOT_POT):
		push_warning(
			"'%s' does not exist yet, so only .tres strings would be collected. " % GODOT_POT
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

func _scan_dir(current_path: String, result: Dictionary) -> void:
	var dir = DirAccess.open(current_path)
	if dir == null:
		push_error("Cannot open folder: %s" % current_path)
		return
	dir.list_dir_begin()
	var file_name = dir.get_next()
	while file_name != "":
		var path = current_path.path_join(file_name)
		if file_name.ends_with(".tres"):
			var res = ResourceLoader.load(path)
			if res:
				for prop in res.get_property_list():
					if prop.usage & PROPERTY_USAGE_EDITOR == 0:
						continue
					if prop.name.begins_with("_"):
						continue
					if prop.name in ["resource_path", "resource_name", "metadata/_custom_type_script"]:
						continue
						
					# Take a look at the propertie's value, so we know what to save
					var value = res.get(prop.name)
					
					# Save String properties
					if prop.type == TYPE_STRING:
						if value != "":
							if not result.has(value):
								result[value] = []
							# Add comment: resource path and property name
							result[value].append("#: %s:%s" % [path, prop.name])
							#print(prop.name)
							
					# Save Array[String]Properties
					elif prop.type == TYPE_ARRAY and typeof(value) == TYPE_ARRAY:
						for i in range(value.size()):
							var item = value[i]
							if typeof(item) == TYPE_STRING and item != "":
								if not result.has(item):
									result[item] = []
								# Add comment: resource path, property name, and array index
								result[item].append("#: %s:%s[%d]" % [path, prop.name, i])
								#print("%s[%d]" % [prop.name, i])
								
								#if not result.has(item):
									#result[item] = {"comments": [], "context": path}
								#result[item]["comments"].append("#: %s:%s[%d]" % [path, prop.name, i])
								
					elif prop.type == TYPE_DICTIONARY and typeof(value) == TYPE_DICTIONARY:
						for key in value.keys():
							var item = value[key]
							if typeof(item) == TYPE_STRING and item != "":
								if not result.has(item):
									result[item] = []
								result[item].append("#: %s:%s[%s]" % [path, prop.name, str(key)])
								#print("%s[%s]" % [prop.name, str(key)])

		elif dir.current_is_dir():
			_scan_dir(path, result)
		file_name = dir.get_next()
	dir.list_dir_end()
	

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
		f.store_line('msgid "%s"' % msgid.replace('"', '\\"'))
		f.store_line('msgstr ""\n')
	f.close()
	return true

				
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
	for msgid in entries.keys():
		for c in entries[msgid]["comments"]:
			f_out.store_line(c)
		f_out.store_line(msgid)
		f_out.store_line(entries[msgid]["msgstr"])
		f_out.store_line("")

	f_out.close()
	print("✅ Merged POT written to: %s" % merged_pot)
	return true


func _load_pot_into_dict(path: String, entries: Dictionary) -> bool:
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		push_error("Cannot open '%s': error %d" % [path, FileAccess.get_open_error()])
		return false
	var lines = f.get_as_text().split("\n")
	f.close()

	var current_comments: Array = []
	var current_msgid: String = ""
	var collecting_msgid := false
	var collecting_msgstr := false

	for line in lines:
		if line.begins_with("#:"):
			current_comments.append(line)
		elif line.begins_with("msgid "):
			# start new msgid block
			current_msgid = line.substr(6).strip_edges()
			collecting_msgid = true
			collecting_msgstr = false
		elif line.begins_with("msgstr "):
			# finish msgid, store it
			collecting_msgid = false
			collecting_msgstr = true
			var msgid_key = "msgid " + current_msgid
			if not entries.has(msgid_key):
				entries[msgid_key] = {"comments": [], "msgstr": 'msgstr ""'}
			entries[msgid_key]["comments"] += current_comments
			current_comments.clear()
		elif collecting_msgid and line.begins_with("\""):
			# continuation of msgid
			current_msgid += "\n" + line
		elif collecting_msgstr and line.begins_with("\""):
			# continuation of msgstr → ignored (we keep empty msgstrs)
			pass
		elif line.strip_edges() == "":
			# reset
			collecting_msgid = false
			collecting_msgstr = false
			current_comments.clear()

	return true
