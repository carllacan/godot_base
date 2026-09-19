@abstract
extends RefCounted
class_name BaseMigrationIdentifier

## Tells the migration system which migrations a project ships.
##
## Every project using GodotBase declares a [code]MigrationIdentifier[/code]
## extending this class, which SaveMigrator instantiates by name. A project with
## no migrations still needs one, returning an empty array.


## Every migration this project ships. Order does not matter:
## get_ordered_migrations() sorts them.
@abstract func get_migrations()-> Array[BaseSaveMigration]


## The migrations in the order they have to run: ascending target version, then
## ascending min source version so that two migrations sharing a target keep
## their relative order.
func get_ordered_migrations()-> Array[BaseSaveMigration]:
	var ordered:Array[BaseSaveMigration] = get_migrations().duplicate()
	ordered.sort_custom(_runs_before)
	return ordered


func _runs_before(a:BaseSaveMigration, b:BaseSaveMigration)-> bool:
	var by_target:int = SaveMigrator.compare_versions(
		a.get_target_version(), b.get_target_version())

	if by_target != 0:
		return by_target < 0

	return SaveMigrator.compare_versions(
		a.get_min_source_version(), b.get_min_source_version()) < 0
