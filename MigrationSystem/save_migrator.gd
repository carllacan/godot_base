extends RefCounted
class_name SaveMigrator

## Brings save files written by older builds up to the shape the running build
## expects.
##
## Migrations run in two stages. migrate_file() rewrites the save's raw text
## before it is loaded, which is the only way to fix moved script or resource
## paths. migrate_state() updates the loaded object. Neither stage writes the
## version stamp: it advances when the migrated state is saved, so a run that
## dies partway through migrates again from the same starting point next time.

## Version a save counts as when it has never been stamped.
const UNVERSIONED:String = "0.0.0"

## Suffix given to the copy taken before a save is rewritten.
const BACKUP_SUFFIX:String = ".bak"

static var _identifier:BaseMigrationIdentifier
static var _property_regexes:Dictionary[String, RegEx] = {}


## The project's migration identifier. Every project using GodotBase declares a
## MigrationIdentifier extending BaseMigrationIdentifier, even if it has no
## migrations to return.
static func get_identifier()-> BaseMigrationIdentifier:
	if _identifier == null:
		_identifier = MigrationIdentifier.new()

	return _identifier


## Whether [param stamp] was written by a development build.
##
## Development builds carry a placeholder version in build_info.json, so their
## saves are stamped with something that names no release. Migrating those would
## run every migration ever written against a save that already has the current
## shape. Which build is running does not matter: an old save is migrated
## whoever loads it.
static func is_development_version(stamp:String)-> bool:
	var version:String = normalize_version(stamp)

	return version.is_empty() or version == UNVERSIONED


#region Planning

## What the save at [param filepath] needs.
static func get_plan(filepath:String)-> MigrationPlan:
	return plan_for_version(read_save_version(filepath),
		get_identifier().get_ordered_migrations())


## Which of [param ordered] apply to a save stamped [param source_version].
##
## Selects every migration the save predates, then checks they chain: the first
## one has to accept the save's own version, and each one after it has to accept
## the version the previous one produced. A hole means a save would reach a
## migration that does not claim to read it, so the plan is refused instead.
##
## A range above the last migration is not a hole. Most releases change nothing
## about the save format.
##
## A save written by a development build is left alone, whatever build is
## reading it.
static func plan_for_version(source_version:String,
	ordered:Array[BaseSaveMigration])-> MigrationPlan:

	var plan := MigrationPlan.new()
	plan.source_version = source_version

	# Left alone rather than refused: a development save is the normal case in
	# the editor, and refusing would report an error on every load.
	if is_development_version(source_version):
		return plan

	var save_version:String = normalize_version(source_version)

	# The version the save has been brought up to so far.
	var reached:String = save_version
	var previous_target:String = UNVERSIONED

	for migration:BaseSaveMigration in ordered:
		var target:String = normalize_version(migration.get_target_version())
		if target.is_empty():
			plan.refused = true
			plan.reason = "migration '%s' has an unreadable target version '%s'" % [
				migration.get_id(), migration.get_target_version()]
			return plan

		var min_source:String = normalize_version(migration.get_min_source_version())
		if min_source.is_empty():
			min_source = previous_target
		previous_target = target

		# The save was written by a build that already had this change.
		if compare_versions(save_version, target) >= 0:
			continue

		if compare_versions(reached, min_source) < 0:
			plan.refused = true
			plan.reason = "nothing brings a %s save up to %s, which '%s' needs" % [
				reached, min_source, migration.get_id()]
			return plan

		plan.migrations.append(migration)
		reached = target

	return plan

#endregion Planning


#region Migrating

## Applies the text stage to the save at [param filepath], after copying it
## aside. Leaves the version stamp alone.
static func migrate_file(filepath:String, plan:MigrationPlan)-> Error:
	if not plan.is_needed():
		return OK

	var content:String = _read_text(filepath)
	if content.is_empty():
		push_error("SaveMigrator: could not read '%s'" % filepath)
		return ERR_FILE_CANT_READ

	var result:Error = _back_up(filepath, plan)
	if result != OK:
		return result

	var migrated:String = content
	for migration:BaseSaveMigration in plan.migrations:
		migrated = migration.migrate_text(migrated)

	if migrated == content:
		return OK

	var file := FileAccess.open(filepath, FileAccess.WRITE)
	if file == null:
		push_error("SaveMigrator: could not write '%s'" % filepath)
		return ERR_FILE_CANT_WRITE

	file.store_string(migrated)
	file.close()

	print("SaveMigrator: migrated '%s' from %s (%s)" % [
		filepath, plan.source_version, ", ".join(plan.get_migration_ids())])

	return OK


## Applies the object stage to [param state] and records what ran.
static func migrate_state(state:BaseGameState, plan:MigrationPlan)-> void:
	if not plan.is_needed():
		return

	if state.original_version.is_empty():
		state.original_version = plan.source_version

	for migration:BaseSaveMigration in plan.migrations:
		migration.migrate_state(state)
		state.applied_migrations.append(migration.get_id())


## Copies the save aside before it is rewritten, once per version it was found
## at: a migration that runs again must not overwrite the untouched original.
static func _back_up(filepath:String, plan:MigrationPlan)-> Error:
	var backup_path:String = "%s.%s%s" % [
		filepath, normalize_version(plan.source_version), BACKUP_SUFFIX]

	if FileAccess.file_exists(backup_path):
		return OK

	var source := FileAccess.open(filepath, FileAccess.READ)
	if source == null:
		push_error("SaveMigrator: could not read '%s' to back it up" % filepath)
		return ERR_FILE_CANT_READ

	var content:PackedByteArray = source.get_buffer(source.get_length())
	source.close()

	var backup := FileAccess.open(backup_path, FileAccess.WRITE)
	if backup == null:
		push_error("SaveMigrator: could not write backup '%s'" % backup_path)
		return ERR_FILE_CANT_WRITE

	backup.store_buffer(content)
	backup.close()

	print("SaveMigrator: backed up '%s' to '%s'" % [filepath, backup_path])

	return OK

#endregion Migrating


#region Versions

## The version stamp of the save at [param filepath].
static func read_save_version(filepath:String)-> String:
	return read_version_from_text(_read_text(filepath))


## The version stamp in a save's raw text.
static func read_version_from_text(content:String)-> String:
	var version = read_property_from_text(content, "version")

	return version if version is String else ""


## Reads one property straight out of a text resource, without loading it.
##
## A save whose format has moved on cannot be loaded at all, so anything that
## has to know something about a file before migrating it has to read the text.
## Only single-line values are readable this way, which covers the stamps
## (`version`, `timestamp_unix`) and not dictionaries or arrays.
##
## Quoted values come back as String and bare numbers as float; a property that
## is not there, or whose value spans lines, gives null.
static func read_property_from_text(content:String, property_name:String)-> Variant:
	# Anchored to the start of a line, so reading `version` does not match
	# `original_version`.
	if not _property_regexes.has(property_name):
		var regex := RegEx.new()
		regex.compile("(?m)^%s\\s*=\\s*(.*)$" % property_name)
		_property_regexes[property_name] = regex

	var found:RegExMatch = _property_regexes[property_name].search(content)
	if found == null:
		return null

	var value:String = found.get_string(1).strip_edges()

	if value.length() >= 2 and value.begins_with('"') and value.ends_with('"'):
		return value.substr(1, value.length() - 2)

	if value.is_valid_float():
		return value.to_float()

	return null


## The comparable part of a version stamp: "0.6.8_steam (a3f21c)" gives "0.6.8".
## Empty when what is left is not a dotted number, which is what a development
## build's "0.0.0-dummy" produces.
static func normalize_version(stamp:String)-> String:
	var version:String = stamp.strip_edges().split(" ")[0].split("_")[0]
	if version.is_empty():
		return ""

	for part:String in version.split("."):
		if not part.is_valid_int():
			return ""

	return version


## Compares two version stamps. -1 if [param a] is older, 1 if newer, 0 if they
## are the same. Missing trailing components count as zero, so "1.2" and "1.2.0"
## are equal.
static func compare_versions(a:String, b:String)-> int:
	var parts_a:PackedInt32Array = _version_parts(a)
	var parts_b:PackedInt32Array = _version_parts(b)

	for i:int in maxi(parts_a.size(), parts_b.size()):
		var value_a:int = parts_a[i] if i < parts_a.size() else 0
		var value_b:int = parts_b[i] if i < parts_b.size() else 0

		if value_a != value_b:
			return -1 if value_a < value_b else 1

	return 0


static func _version_parts(stamp:String)-> PackedInt32Array:
	var parts := PackedInt32Array()
	var version:String = normalize_version(stamp)

	if version.is_empty():
		return parts

	for part:String in version.split("."):
		parts.append(part.to_int())

	return parts


static func _read_text(filepath:String)-> String:
	var file := FileAccess.open(filepath, FileAccess.READ)
	if file == null:
		return ""

	var content:String = file.get_as_text()
	file.close()

	return content

#endregion Versions
