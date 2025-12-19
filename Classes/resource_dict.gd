extends Resource
class_name ResourceDict
## Allows one to make a dictionary of resources from the editor, so that they
## can all be loaded at the same time or whatever.

@export var contents:Dictionary[Variant, Resource] = {}
