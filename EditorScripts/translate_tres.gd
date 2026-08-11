@tool
## Collects translatable strings that live inside .tres resources and merges them
## with the .pot the editor generates from scenes and scripts.
##
## Godot's built-in POT generation only scans the files listed in
## Project Settings > Localization > POT Generation, and it does not look at the
## String properties of custom resources. Any text authored in a .tres (item
## names, descriptions, tooltips, ...) would therefore never reach the
## translators. This script walks every .tres under res:// (skipping addons/,
## which holds third party resources), pulls out every
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

## Folder names skipped while walking res://. Third party code shipped in
## addons/ carries its own strings, which are not ours to translate.
const EXCLUDED_DIRS := ["addons"]

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
								result[item].append("#: %s:%s[%s]" % [path, prop.name, _dict_key_label(key)])

		elif dir.current_is_dir():
			if not file_name in EXCLUDED_DIRS:
				_scan_dir(path, result)
		file_name = dir.get_next()
	dir.list_dir_end()


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
