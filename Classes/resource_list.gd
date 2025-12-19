extends Resource
class_name ResourceList
## Allows one to make a list of resources from the editor, so that they
## can all be loaded at the same time or whatever.

@export var contents:Array[Resource] = []
