@abstract
extends RefCounted
class_name BaseSaveMigration

## One change to the save file format, and the code that brings older saves up
## to it.
##
## A migration applies to saves stamped in
## [code][get_min_source_version(), get_target_version())[/code].


## Identifies this migration in [member BaseGameState.applied_migrations].
##
## Frozen once the migration ships: the string is already written into saves
## that exist on players' machines.
@abstract func get_id()-> String


## The release that changed the save format: the first build that cannot read a
## save older than itself. This migration applies to saves stamped below it.
@abstract func get_target_version()-> String


## The oldest save this migration can read. Anything older has to be brought up
## to this version by an earlier migration first.
##
## Empty means the target version of the migration before this one, which is
## the usual case: each migration picks up where the previous one left off.
func get_min_source_version()-> String:
	return ""


## Rewrites the save's raw text before ResourceLoader reads it, and the only
## stage that can fix moved script or resource paths: a .tres naming a path
## that no longer exists never becomes an object at all.
##
## Must be idempotent — it can run again on a save it already migrated.
func migrate_text(content:String)-> String:
	return content


## Updates a loaded state, for value changes rather than reference changes: a
## dictionary rekeyed, a default backfilled, a number rescaled.
func migrate_state(state:BaseGameState)-> void:
	pass
