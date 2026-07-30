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
| `--log-console` | Add a console sink (defaults) |
| `--log-file` | Add a file sink (defaults: JSONL-capable `FileLogSinkConfig` defaults — see its fields) |

E.g. `godot --headless -- --no-default-log-sinks --log-file` runs with only
a file sink, ignoring whatever's baked into the build config. These are
boolean presence flags, no `=value` overrides yet — for anything beyond the
defaults (custom `log_dir`, `format`, `min_level`), configure it via
`BuildConfig.log_sinks` instead.

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

Levels: `Debug`, `Info`, `Warning`, `Error` (`LogLevel.Value`). `Error`
entries bypass the async queue and are written synchronously, so they
survive a crash immediately after.

**Metadata must be JSON-primitive** (bool/int/float/String, or Array/Dictionary
of those). Anything else (e.g. a Node reference) logs a `push_warning` and
may not serialize correctly.

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

Each launch gets its own timestamped session folder under `log_dir`
(when `rotation_enabled = true`), which is what actually separates the two
runs on disk — the `Run started` entry just makes it obvious which folder
is which without checking file timestamps.

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
