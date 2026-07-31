# GameplayLog

Structured, persisted event logging. Distinct from anything display-facing
(there is no title/text templating here) — this exists to record what
happened during a run as flat, timestamped, JSON-serializable entries, so two
runs (e.g. different `BuildConfig.Default.autoplayer` configs) can be
compared or plotted afterward.

Autoloaded as **`Log`**. Vendored from `godot-logger`
(`~/Projects/godot-logger`) — core logging engine only, no editor dock.

## Quick start

Sinks are configured on `BuildConfig` (`GodotBase/Classes/base_build_config.gd`,
`log_sinks:Array[BaseLogSinkConfig]`), not from code. `Log._ready()` builds
and starts one runtime sink per config entry automatically. To add a sink:
create a `FileLogSinkConfig` or `ConsoleLogSinkConfig` resource, set its
fields in the Inspector, and add it to `log_sinks` on your build config
`.tres` (e.g. `editor_build_config.tres`):

- `FileLogSinkConfig`: `log_dir`, `format` (`PlainText`/`Json`),
  `rotation_enabled`, `max_file_size_kb`, `min_level`.
- `ConsoleLogSinkConfig`: `min_level`.

Sink **configs** (`BaseLogSinkConfig` and subclasses) are plain-data
`Resource`s, safe to edit/save in the Inspector. The **runtime sinks**
they build (`BaseLogSink` and subclasses — `FileLogSink`, `ConsoleLogSink`)
are `RefCounted`, not `Resource`: they own a live thread, mutexes, and an
open file handle, and only exist transiently after `create_sink()` is
called. Don't put a runtime sink instance in an `@export` array — put its
config there instead.

If you need a sink outside the BuildConfig flow (e.g. a one-off in a test),
build and add it directly:

```gdscript
var file_sink := FileLogSinkConfig.new().create_sink()
Log.add_sink(file_sink)   # add_sink() calls start() for you
```

### Command-line overrides

Useful for launching two comparison runs from the command line without
juggling separate BuildConfig `.tres` files (pass after `--`, per
`OS.get_cmdline_user_args()` — see `base_main_scene.gd:_apply_cmdline_overrides`
for the existing convention this follows):

| Flag | Effect |
|------|--------|
| `--no-default-log-sinks` | Skip the sinks configured in `BuildConfig.log_sinks` |
| `--log-sinks=<json>` | Add the sinks described by a JSON array |

`--log-sinks` takes an array of objects. `"type"` picks the config class —
`file` for `FileLogSinkConfig`, `console` for `ConsoleLogSinkConfig` — and
every other key is one of that config's exported properties, so the flag
gains whatever the configs gain, with nothing to keep in sync. Properties
holding an enum also accept its name, case-insensitively: `format` takes
`"text"` or `"json"`, `min_level` takes `"debug"`, `"info"`, `"warning"` or
`"error"`.

```sh
godot --headless -- --no-default-log-sinks --log-sinks='[
  {"type":"file","log_dir":"/tmp/run3","format":"json","rotation_enabled":false},
  {"type":"console","min_level":"warning"}]'
```

That runs with only the two sinks named, ignoring whatever's baked into the
build config; without `--no-default-log-sinks` they're added on top of it.
Both spellings work, `--log-sinks=<json>` and `--log-sinks <json>`.

One switch rather than one per property, because the main caller is a harness
building the string in code. Typed by hand it needs the quoting above.

Anything wrong with the string — bad JSON, an unknown `type`, a key the config
doesn't have, a value of the wrong type — is a `push_error` and **no sinks at
all** from this flag, rather than a quiet fall back to the defaults. A run that
was told to log somewhere and silently didn't is worse than one that refuses.

## Logging

```gdscript
Log.info("Ball dropped", "Game", {"ball_id": id, "value": value})
Log.warning("Unknown upgrade id — skipping", "Save", {"id": upgrade_id})
```

Or get a pre-tagged logger once per system, so you don't repeat the tag at
every call site:

```gdscript
var _log := Log.get_tagged("Prestige")
_log.info("Prestige applied", {"new_level": level})
```

Levels: `Debug`, `Info`, `Warning`, `Error` (`LogLevel.Value`). Logging an
`Error` flushes the file sink before returning, so it survives a crash
immediately after — along with everything logged before it, in order.
`Log.flush()` does the same on demand, for right before something that might
not come back.

**Metadata must be JSON-primitive** (bool/int/float/String/null, or
Array/Dictionary of those). Anything else (e.g. a Node reference) logs a
`push_warning` and may not serialize correctly. What you pass is deep-copied
into the entry, so handing over live game state and carrying on mutating it is
safe — the log keeps the values as they were at the call.

### Logging nothing costs nothing

With no sink attached every call returns immediately, but the caller has still
built the `Dictionary` it passed. Where that costs anything — a lookup, a loop
over game state — guard the whole thing instead:

```gdscript
func _ready() -> void:
    if not Log.is_enabled(): return
    some_signal.connect(_on_something)   # never even connected
```

`Log.is_enabled()` is false when nothing is listening. Sinks are all attached
in `Log._ready()`, so from any other `_ready()` onward the answer is final.
`Log.get_log_paths()` gives the folders any file sinks are writing under; the
autoload prints them at startup.

## Tagging a run for comparison

There's no built-in run-id/label concept yet — if you're comparing two
configs, log it explicitly as the first entry of the run so it's easy to
find later:

```gdscript
Log.info("Run started", "Run", {
    "autoplayer": BuildConfig.Default.autoplayer.resource_path,
    # ...whatever else varies between the runs you're comparing
})
```

Each launch gets its own session folder under `log_dir`, stamped to the second
(when `rotation_enabled = true`), which is what actually separates the two runs
on disk — the `Run started` entry just makes it obvious which folder is which
without checking file timestamps. Within a folder, files roll over once they
pass `max_file_size_kb` real kilobytes.

## Reading the logs back

Output is JSONL (`user://logs/<session_folder>/*.jsonl`) — one JSON object
per line, load with `pd.read_json(path, lines=True)` or equivalent.
Comparing/plotting two runs is an offline step outside Godot; this system
only produces the data.

## Known gaps (see conversation history for why)

- No monotonic sequence number — ordering relies on timestamp, which could
  tie at high autoplayer speed.
- `FileLogSink` always spawns a real `Thread`; unlike `SaveManager`, it
  doesn't check `Flags.WEB`. Needs that guard before shipping to a web
  export target.
- No editor dock for live browsing — the original addon has one
  (`~/Projects/godot-logger/addons/godot_logger/editor/`) but it wasn't
  copied over since it depends on the addon's `EditorPlugin` registration.
