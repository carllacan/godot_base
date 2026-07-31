# Autoplayers

Scripted players that play the game on their own, so a run can be watched or left
going without a human at the controls. They exist to catch bugs: a player that
only does what a real player could do will walk into the same broken states you
would, but for hours and without getting bored.

Everything here is game-agnostic. The game supplies the strategies and whatever
they need to know about cards, shops or enemies; this folder supplies the
lifecycle, the pacing hooks and the pointer.

## The pieces

| | |
|---|---|
| `BaseAutoplayer` | A `Resource`. Holds one strategy: what to do, and when to stop. |
| `AutoplayerManager` | Autoload. Loads the player, ticks it while a game is up, and closes the game when it finishes. |
| `AutoplayerCursor` | A fake pointer drawn on top of everything, so the run can be followed by eye. Decoration only. |

## Turning it on

Assign a player resource to the build config's `autoplayer` field, or point at
one from the command line, which overrides the build config:

```sh
godot -- --autoplayer=res://Data/Dev/Autoplayers/greedy.tres
godot -- --autoplayer /home/me/players/patient.tres
godot -- --autoplayer=none    # play by hand for once
```

The switch goes after the `--` that separates user arguments, and takes a
`res://` path or an absolute one, written either with `=` or as two arguments. A
path that cannot be loaded is reported as an error rather than ignored: a run
launched to play itself and then quietly sitting idle is worse than a loud
failure.

To leave one running headless:

```sh
godot --headless --path . --max-fps 60 -- --straight-to-playing --autoplayer=<path>
```

`--max-fps` matters. Uncapped headless play will happily eat the machine.

To run several at once, give each one its own save directory:

```sh
godot --headless --path . --max-fps 60 -- --straight-to-playing \
  --autoplayer=<path> --save-dir=/tmp/run-a
```

Without `--save-dir` every copy reads and writes the same `user://save.tres`,
so they trample each other and take your own save down with them. It takes a
path relative to `user://` or an absolute one; `--save-file` renames the file
the same way. Both are declared on `BaseGameState`, which reads them where it
resolves a save path rather than having them applied to it from outside.

Do not use `--time-scale` to make a batch finish sooner. The drum is a physics
simulation, so a faster clock plays a different game, and whatever the run was
measuring stops being true of the real one.

## Listing them

To find out what there is to run, without running any of it:

```sh
godot --headless --path . --script res://GodotBase/Autoplayers/list_autoplayers.gd
godot --headless --path . --script res://GodotBase/Autoplayers/list_autoplayers.gd -- res://Players
```

Prints one `res://` path per line and quits. Without a directory it scans
`AUTOPLAYERS_DIR` (`res://Data/Dev/Autoplayers/`). There is no header and there
are no delimiters — a script reading this can keep the lines starting with
`res://` and ignore whatever else the engine printed on its way up.

Not `--quiet`: it silences `print()` along with everything else, so the list
comes out empty.

A script rather than a switch on the game. A switch would run inside a booting
game and have to stop it finishing the job, since `quit()` only lands at the end
of the frame — and nothing about starting a game should have to know that
listing autoplayers is a thing that happens.

The catch is that `--script` replaces the main loop, so the autoloads never come
up, and every player class reaches one sooner or later. That rules out loading
these resources to find out what they are. So `list_autoplayers.gd` reads them
instead: the class each `.tres` names in its header, checked against
`ProjectSettings.get_global_class_list()` to see whether it descends from
`BaseAutoplayer`. Binary `.res` players would need loading and are skipped.

A player assigned to the build config as an inline subresource has no file on
disk, so it will not be listed. Give a player its own `.tres` if a harness
should be able to find it.

A player assigned to the build config as an inline subresource has no file on
disk, so it will not be listed. Give a player its own `.tres` if a harness
should be able to find it.

## What they log

A player records what it does in the gameplay log under the `Autoplayer` tag:
`Autoplayer started` when `initialize()` runs, `Autoplayer finished` with the
ending reason, and whatever the strategy adds through `log_event()`. Every entry
carries `time_played`, since the log's own timestamps are wall-clock and say
nothing about how far into the run something happened.

That is what lets a log say who was at the controls and how the run ended,
without whoever reads it afterwards having to be told from outside.

Set `log_decisions = false` on the player for a run whose log should hold
gameplay and nothing else. It is separate from `verbose`, which governs the
`p()` narration on stdout.

Gameplay events do **not** go through here — they are logged by the game
itself, with or without a player at the controls, and nothing in that path knows
the autoplay system exists.

## Lifecycle

The manager owns it, and calls the player's hooks in this order:

1. **`initialize()`** — once, the first time a game scene comes up. Connect to
   signals here. A `Resource` never receives `_ready`, and the player outlives
   the game scene, so connecting anywhere else stacks duplicate connections.
2. **`act(delta)`** — every frame while a game is running.
3. **`get_ending_reason()`** — after every `act()`. See below.
4. **`on_save_loaded()`** — every time a save is loaded, including the reload
   that follows a prestige-style reset. Restart per-run bookkeeping here, and
   drop every reference into the old scene: it is on its way out.
5. **`on_finished()`** — once, when the player stops.

Between a save load and the next `game_started`, and while the main menu is up,
the player is not ticked at all. That is what spares strategies from
null-checking the current game everywhere.

## Writing a player

```gdscript
extends BaseAutoplayer
class_name Dawdler

@export var reaction_time_s:float = 0.5

var _time_since_action:float = 0


func act(delta:float)-> void:
	super.act(delta)

	_time_since_action += delta
	if _time_since_action < reaction_time_s: return
	_time_since_action = 0

	do_one_thing()
```

Two rules are worth holding to, because breaking either costs you the reason the
system exists:

**The player may only do what a player could do.** Reach for the real widget and
press it; where that is impractical, call the same backend method the widget
calls, having checked the same preconditions. A player that awards itself money
tests nothing.

**One action at a time, at a human pace.** A player that empties the shop in a
single frame is unwatchable, and unwatchable runs do not catch UI bugs.

Games with more than one strategy will want a middle class of their own,
subclassing `BaseAutoplayer`, to hold what all of that game's players have in
common. Anything that knows the game's nouns belongs there, never here.

## Ending conditions

`max_time_played` stops the player after that many seconds of play. Zero plays
forever. It measures `total_time_played`, which counts across save loads, rather
than `time_played`, which resets on every one of them — a player that prestiges
would otherwise keep resetting its own clock and never reach the end.

Add conditions of your own by overriding `get_ending_reason()`, which returns a
reason to report or an empty string to carry on. Report the base class's reasons
first, so a time limit still ends a player its own conditions would keep going:

```gdscript
func get_ending_reason()-> String:
	var reason:String = super.get_ending_reason()
	if not reason.is_empty(): return reason

	if max_floors_cleared > 0 and floors_cleared() >= max_floors_cleared:
		return "cleared %d floors" % floors_cleared()

	return ""
```

When one is met, `finish()` prints the reason, calls `on_finished()`, and the
manager stops ticking the player and closes the game. Set
`AutoplayerManager.quit_when_finished = false` to have it stop playing but leave
the run up to be looked at by hand.

Two things happen around the quit that are easy to miss:

- **Anything held down stays held.** A finished player is never ticked again, so
  a crank being turned, a button being pressed or a widget left hovered will
  stay that way forever. Release it in `on_finished()`.
- **The save is waited for.** Saving is debounced and threaded, so quitting on
  the same frame drops the last few seconds of play. The manager waits for it,
  bounded by `SAVE_FLUSH_TIMEOUT_MS`, because saving is driven from
  `_physics_process` and a paused tree stops it.

## The cursor

The manager creates one `AutoplayerCursor` and hands it to nobody: reach it at
`AutoplayerManager.cursor`.

```gdscript
AutoplayerManager.cursor.move_to(screen_position)   # travels there over a moment
AutoplayerManager.cursor.click()                    # flashes, for when you act
```

It never sends input. It just travels to whatever the player is about to act on,
which makes a run legible at a glance, and it keeps moving while the tree is
paused, since a player can drive windows that pause the game. Working out the
screen position of a target is the game's job — with a 3D world in a
`SubViewport`, that means projecting through the camera and mapping the result
through the container's rect.

Pointing at something and acting on it are worth splitting across two ticks: the
cursor arrives, then it clicks. Actions should re-check their preconditions
anyway, so a target that goes stale in between simply fails.

## Pausing

The manager runs with `PROCESS_MODE_ALWAYS`, so players keep being ticked while
an open window has the tree paused. That is deliberate — a player that drives its
own windows has to keep going inside them — and it means a player is responsible
for standing still during a pause it did not cause:

```gdscript
if Pause.is_paused(): return
```
