extends Node
class_name BaseGroups


const DEBUG_ELEMENTS = "debug_elements"
const MUSIC_PLAYERS = "music_players"
const SFX_PLAYERS = "sfx_players"

## Marks the viewport the performance tooling should measure and act on.
## Only needed when the interesting rendering happens in a SubViewport -- with
## nothing in this group the tooling falls back to the root viewport. A node
## that is not itself a Viewport is taken to mean the viewport it belongs to.
const PERF_TARGET = "perf_target"
