extends RefCounted
class_name MigrationPlan

## What SaveMigrator worked out about one save file: which migrations it needs,
## or why it must not be touched.


## The version the save was stamped with, before any migration ran.
var source_version:String = ""

## The migrations to run, in the order they run.
var migrations:Array[BaseSaveMigration] = []

## Whether the save must be left alone. A refused plan is not the same as an
## empty one: an empty plan means the save is already current.
var refused:bool = false

## Why the plan was refused.
var reason:String = ""


func is_needed()-> bool:
	return not refused and not migrations.is_empty()


## The ids of the migrations to run, for logging.
func get_migration_ids()-> PackedStringArray:
	var ids := PackedStringArray()

	for migration:BaseSaveMigration in migrations:
		ids.append(migration.get_id())

	return ids
