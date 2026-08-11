# GraphFocus analysis (2026-08-05)

Review of `graph_focus.gd`, written while adding `Tests/test_graph_focus.gd`. The
component has no callers yet — the only usage anywhere is the example in its own
header comment — so nothing below is a live regression, and the two items that
change what callers get back (1 and 3) are free to fix now.

The test suite pins the *current* behaviour, including the broken bits, so any of
these fixes will need the matching test updated. The tests that would change are
named in each item.

## TL;DR

The scoring design (distance divided by alignment, inside a configurable cone) is
sound and produces the neighbour a player expects. The problems are all around the
edges: the lookup key is too strict for the input it documents, freed nodes are
never guarded against, and `get_nearest_to` searches a different set of elements
than `build_graph` builds from.

## Bugs — all fixed 2026-08-11

Every item below was fixed before the component got its first caller, and the
tests named in each one were updated to match. The section is kept as the record
of why the code looks the way it does. The **Improvements** section further down
is still open.

One thing did not survive contact with the engine. Item 2 wanted a guard against
a freed element being passed to `get_neighbor` as `from`; the `Node` type on that
parameter makes Godot reject the call at the argument boundary, before any guard
in the body could run. Widening the parameter to untyped would buy a silent
`null` in exchange for the type hint, which is a bad trade — a "previously freed"
error is far easier to diagnose than navigation quietly stopping. The dangerous
half of item 2, *returning* a freed node, is guarded.

### 1. `get_neighbor` only matches exact cardinal vectors

`graph_focus.gd:71`. Neighbours are stored under `Vector2.UP/DOWN/LEFT/RIGHT` and
looked up with a plain `neighbors.has(direction)`.

The usage documented in the header (`graph_focus.gd:28`) passes `direction`
straight through from input. That is only ever an exact cardinal for a d-pad or
for `ui_*` actions — anything coming off an analog stick, or any caller that
normalises a delta itself, gets `null` and navigation silently stops.

Fix: snap the incoming direction to the nearest cardinal inside `get_neighbor`
instead of making every caller do it. `Vector2.ZERO` should stay `null`.

Test: `test_a_diagonal_direction_finds_nothing` currently asserts the broken
behaviour and would become "a diagonal snaps to the dominant axis".

### 2. A freed element makes `get_nearest_to` hard-error

`graph_focus.gd:81`. `_elements` and `_graph` hold plain Node references that
outlive a rebuild. If an element is `queue_free`d and the graph is not rebuilt
before the next query, `el is Node2D` throws.

Verified on Godot 4.7: `is` against a previously freed instance raises
`Left operand of 'is' is a previously freed instance` and aborts the call — it
does **not** evaluate to `false`. `get_neighbor` has the quieter version of the
same problem: it can hand back a freed node for the caller to focus.

Fix: `is_instance_valid(el)` skip in both loops. Note this cannot be solved by
"just rebuild on every change" — an element can be freed between the rebuild and
the next input event.

### 3. `get_nearest_to` and `build_graph` disagree about what exists

`graph_focus.gd:80`. The nearest search runs over `_elements` — everything ever
passed to `build_graph` — while the graph itself is built only from the elements
that passed the visibility check.

So a caller that omits the check, or passes a different one, gets back an element
with no entry in the graph. The focus lands on something invisible and the very
next d-pad press returns `null`. The header example does pass the same check to
both calls, which is the only reason this works, and nothing enforces it.

Fix: search the graph's keys by default and treat the check as an extra filter on
top, rather than as the only filter.

Test: `test_the_search_covers_elements_that_were_left_out_of_the_graph` documents
the current behaviour and would invert.

### 4. Nodes with no position are treated inconsistently

`graph_focus.gd:126`. `_get_element_position` falls back to `Vector2.ZERO` for
anything that is neither `Node2D` nor `Control`, so such a node enters the graph
as a phantom neighbour sitting at the origin — pulling real elements towards it.
`get_nearest_to` meanwhile skips those nodes explicitly (`graph_focus.gd:81`).

Fix: filter them out in `build_graph` the same way, so the two agree.

### 5. `_elements = elements` aliases the caller's array

`graph_focus.gd:45`. The array is stored by reference, and the array a caller
passes is usually its live control list. Mutating it after the build changes what
`get_nearest_to` searches with no rebuild in between, and re-introduces the freed
node problem above.

Fix: `_elements = elements.duplicate()`.

## Improvements

### Positions are corners, not centres

`graph_focus.gd:121-126`. `Control.global_position` is the top-left of the
control's rect. For a row of buttons of differing heights, or a wide button beside
a narrow one, the geometry the graph reasons about is not the geometry the player
sees, and the alignment term of the score is skewed by half the size difference.

`get_global_rect().get_center()` is what intent calls for. `Node2D` has no
equivalent — its `global_position` is whatever the scene's origin is — so it stays
as-is.

Test: `test_node2d_elements_are_placed_by_their_global_position` and the grid
coordinates in most other tests assume corners, but every test places
zero-sized controls, so centres and corners coincide and nothing would break.

### `build_graph` does 4n² position lookups

`graph_focus.gd:58-64`. `_find_nearest_in_direction` walks every element and
re-reads every global position once per direction, and re-reads `from`'s position
on each of the four calls too.

Computing positions into a parallel array once and then scoring all four
directions in a single pass over the pairs brings it to n² with no repeated
transform reads. This only matters for a large upgrade tree rebuilt on every
purchase — which is exactly the case the header example describes.

While there: the `directions` array at `graph_focus.gd:56` is rebuilt on every
call and can be a `const`.

### No `clear()`

The only way to empty the graph is `build_graph([])`. A screen being closed has
nothing better to call.

### `max(dot, 0.01)` is defensive, not dead

`graph_focus.gd:113`. Worth noting since it reads like dead code: `dot` is already
known to be `>= direction_threshold` at that point, so the guard does nothing at
the default threshold of 0.3. It only earns its place if someone sets
`direction_threshold` to 0 to accept the entire forward half-plane, where a dot of
exactly 0 would divide by zero. Keep it.

## What the tests cover

`Tests/test_graph_focus.gd`, 35 tests in four regions:

- **build_graph** — neighbours in all four directions, per-element links, isolated
  elements, the visibility check skipping over a hidden element to reach the next
  one, rebuilding forgetting the old links, and elements left out for having no
  2D position or for having been freed (each with its warning asserted).
- **get_neighbor** — null for a null element, an element never added, an unbuilt
  graph, an empty direction; a freed neighbour is not handed back; and directions
  snapping to their dominant axis, with a perfect diagonal going horizontal.
- **choosing between candidates** — the `dist / dot` score: closest wins among
  aligned candidates, but an aligned element at 100px beats an off-axis one at
  67px; a perpendicular element is not a neighbour; a corner element is reachable
  both sideways and down at the default 0.3 threshold and not at 0.9; two elements
  on the same spot can never reach each other.
- **get_nearest_to** — nearest wins, the visibility check is honoured, `Node2D`
  and `Control` are both positioned, freed elements are skipped, elements outside
  the graph are never returned, and mutating the caller's array after the build
  changes nothing.

Run with:

```
godot --headless -s addons/gut/gut_cmdln.gd -gdir=res://GodotBase/Navigation -ginclude_subdirs -gexit
```

from the `bingomental/` directory. A newly added test file is not collected until
`godot --headless --import` has run — check the `Scripts` count in the summary.
