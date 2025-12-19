@tool
extends EditorScript
class_name TranslateTresFiles

const GODOT_POT := "res://locales/auto_template.pot"   # Godot-generated .pot
const TRES_POT := "res://locales/tres_template.pot"     # Temp .pot for .tres strings
const MERGED_POT := "res://locales/complete_template.pot" # Final merged .pot

func _run():
	var tres_entries = extract_all_tres_strings("res://")
	generate_pot_file(tres_entries, TRES_POT)
	merge_pot_files(GODOT_POT, TRES_POT, MERGED_POT)
	print("✅ Strings extracted and merged into: %s" % MERGED_POT)

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
func generate_pot_file(entries: Dictionary, pot_path: String):
	var f = FileAccess.open(pot_path, FileAccess.WRITE)
	if f == null:
		push_error("Cannot write .pot file: %s" % FileAccess.get_open_error())
		return
	for msgid in entries.keys():
		# Write all comment lines
		for comment in entries[msgid]:
			f.store_line(comment)
		f.store_line('msgid "%s"' % msgid.replace('"', '\\"'))
		f.store_line('msgstr ""\n')
	f.close()

# --- Merge two .pot files using msgcat (deduplicates automatically) ---
#func merge_pot_files(godot_pot: String, tres_pot: String, merged_pot: String):
	#var args = [
		#ProjectSettings.globalize_path(godot_pot), 
		#ProjectSettings.globalize_path(tres_pot), 
		#"--use-first",  "-o",  
		#ProjectSettings.globalize_path(merged_pot)
		#]
	#var output = []
	#var err = OS.execute("msgcat", args, output, true) # blocking execution
	#if err != 0:
		#print("⚠️ msgcat not found or failed. Using tres_pot only as fallback.")
		#print("Output: " )
		#for e in output: print(e)
		## fallback: just copy tres_pot
		#var tres_pot_file = FileAccess.open(tres_pot, FileAccess.READ)
		#if tres_pot_file != null:
			#var contents = tres_pot_file.get_as_text()
			#tres_pot_file.close()
			#var merged_pot_file = FileAccess.open(merged_pot, FileAccess.WRITE)
			#if merged_pot_file != null:
				#merged_pot_file.store_string(contents)
				#merged_pot_file.close()


	# helper to load pot into dictionary
func load_pot(path: String):
	var entries := {}
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		push_error("Cannot open: %s" % path)
		return
	var lines = f.get_as_text().split("\n")
	f.close()

	var current_comments = []
	var current_msgid = null
	for line in lines:
		if line.begins_with("#:"):
			current_comments.append(line)
		elif line.begins_with("msgid "):
			current_msgid = line
			if not entries.has(current_msgid):
				entries[current_msgid] = {"comments": [], "msgstr": 'msgstr ""'}
			entries[current_msgid]["comments"] += current_comments
			current_comments.clear()
		elif line.begins_with("msgstr "):
			# ignore, we always keep empty msgstr
			pass
		elif line.strip_edges() == "":
			current_comments.clear()
	return entries
				
				
func merge_pot_files(godot_pot: String, tres_pot: String, merged_pot: String):
	var entries := {}

	# load both pots
	_load_pot_into_dict(godot_pot, entries)
	_load_pot_into_dict(tres_pot, entries)

	# ensure output directory exists
	var out_dir := merged_pot.get_base_dir()
	if not DirAccess.dir_exists_absolute(out_dir):
		DirAccess.make_dir_recursive_absolute(out_dir)

	# write merged file
	var f_out := FileAccess.open(merged_pot, FileAccess.WRITE)
	if f_out == null:
		push_error("Cannot write merged pot: %s" % merged_pot)
		return

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


func _load_pot_into_dict(path: String, entries: Dictionary) -> void:
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		push_error("Cannot open: %s" % path)
		return
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
