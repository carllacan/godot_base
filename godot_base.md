# GodotBase Framework Documentation

GodotBase is a collection of reusable code, scenes, and resources designed to be shared across multiple Godot projects. Each project includes a `GodotBase/` folder containing the framework.

---

## Table of Contents

1. [Core Philosophy](#core-philosophy)
2. [Base Classes](#base-classes)
3. [Settings System](#settings-system)
4. [Modifier System](#modifier-system)
5. [Components](#components)
6. [Scene Utilities](#scene-utilities)
7. [Autoloads](#autoloads)
8. [Global Utilities](#global-utilities)
9. [Integration (Steam, etc.)](#integration)
10. [Configuration](#configuration)

---

## Core Philosophy

- **Inheritance over duplication**: Extend `Base*` classes rather than copying code
- **Configuration via resources**: Use `.tres` files to configure behavior
- **Signals for decoupling**: Components communicate via signals
- **Composition via components**: Add behavior by attaching component nodes
- **Generalization and flexibility**: Provide abstract features that can be used everywhere, but allow for project-specific customization

---

## Base Classes

### BaseGameState

**File**: `GodotBase/Classes/base_game_state.gd`

The foundation for player save files. Extend this to create your game's `GameState` class.

```gdscript
extends BaseGameState
class_name GameState

# Add game-specific save data
@export var unlocked_levels:Array[int] = []
@export var total_playtime:float = 0.0

static func create()-> GameState:
    var state = GameState.new()
    state.reset()
    return state

func reset()-> void:
    unlocked_levels = [1]
    total_playtime = 0.0
```

**Key methods to override**:
- `reset()` - Initialize default values for new save
- `save()` - Persist to disk (calls parent implementation)

### BaseGameRun

**File**: `GodotBase/Classes/base_game_run.gd`

Base class for a single gameplay attempt/session. Extend to create your game's `GameRun` class.

```gdscript
extends BaseGameRun
class_name GameRun

signal debris_collected_changed

@export var level:int = 1
@export var score:float = 0
@export var time_elapsed:float = 0

var run:GameState : set = set_run

func set_run(new_value:GameState)-> void:
    run = new_value
    on_new_run_set()

func on_new_run_set()-> void:
    # Apply persistent upgrades, etc.
    pass
```

### BaseActor

**File**: `GodotBase/GameWorld/base_actor.gd`

Base class for game entities in the world. Extends `RigidBody2D`.

**Signals**:
- `effect_dropped(effect:BaseEffect)` - When actor drops a visual effect
- `debris_dropped(debris:Array)` - When actor drops collectibles
- `actor_dropped(actor:BaseActor)` - When actor spawns another actor
- `destruction_begun` - When destruction animation starts
- `destroyed` - When fully destroyed

**Key methods**:
- `destroy()` - Start destruction sequence
- `play_destruction_animation()` - Override for custom death animation

```gdscript
extends BaseActor
class_name Enemy

@export var model:EnemyModel

func _ready()-> void:
    super._ready()
    # Enemy-specific setup

func play_destruction_animation()-> void:
    # Custom death animation
    var tween = create_tween()
    tween.tween_property(self, "scale", Vector2.ZERO, 0.3)
    await tween.finished
    destroyed.emit()
```

### BaseGameWorld

**File**: `GodotBase/GameWorld/base_game_world.gd`

Container for managing actors. Extends `Node2D`.

**Properties**:
- `actors:Array[BaseActor]` - All actors in the world
- `run:GameState` - Reference to current save

**Key methods**:
- `add_actor(actor:BaseActor)` - Add and track an actor
- `remove_actor(actor:BaseActor)` - Remove and cleanup an actor
- `clear_actors()` - Remove all actors

### BaseBuildConfiguration

**File**: `GodotBase/Classes/base_build_config.gd`

Configuration resource for development/release builds.

**Properties**:
- `skip_splash_screen:bool` - Skip splash on launch
- `skip_main_menu:bool` - Go directly to game
- `testing_save:Resource` - Override save file for testing
- `force_debug:bool` - Override DEBUG flag
- `force_demo:bool` - Override DEMO flag
- `force_steam:bool` - Override STEAM flag

**Usage**:
```gdscript
# In your BuildConfiguration.gd
extends BaseBuildConfiguration
class_name BuildConfiguration

static var Default:BuildConfiguration:
    get:
        if _default == null:
            _default = load("res://Parameters/BuildConfigurations/editor_build_config.tres")
        return _default

static var _default:BuildConfiguration

# Access anywhere:
if BuildConfiguration.Default.skip_splash_screen:
    # Skip to main menu
```

### BaseWindow

**File**: `GodotBase/Scenes/WindowsLayer/base_window.gd`

Reusable dialog/popup window with animations.

**Signals**:
- `opened` - When window finishes opening
- `closed` - When window finishes closing

**Properties**:
- `title:String` - Window title
- `text:String` - Window body text
- `destroy_on_close:bool` - Auto queue_free when closed

**Methods**:
- `open()` - Show with animation
- `close()` - Hide with animation

**Results enum**: `Results.Yes`, `Results.No`

```gdscript
var confirm_window = BaseWindow.BASE_SCENE.instantiate()
confirm_window.title = tr("Are you sure?")
confirm_window.text = tr("This action cannot be undone.")
confirm_window.destroy_on_close = true
add_child(confirm_window)
confirm_window.open()
await confirm_window.closed

if confirm_window.result == BaseWindow.Results.Yes:
    # Proceed
```

### BaseEffect

**File**: `GodotBase/Classes/base_effect.gd`

Base for visual/audio effects.

**Signals**:
- `finished` - When effect completes

**Methods**:
- `play()` - Start the effect

### BaseBuildConfiguration

A class that is used to quickly configure "hacks" for testing. 
Programmers sometimes put cheats in the code to facilitate testing. E.g. if want the player to be invulnerable so we can test other stuff without worrying about dying we do "damage = 0 # FOR TESTING, REMOVE LATER" and just hope that we will indeed remember to remove it. Sometimes this doesn't happen and that line makes it into production in the shape of a bug.
The BaseBuildConfiguration class exist to avoid this. It has two goals:
1) to make it easier to enable and disable these hacks, by transforming them into @export variables on a resource that can be edited in the editor.
    * For instance: a bool flag that makes the player invulnerable becomes a checkbox, overriding what kinds of enemies appear becomes clicking Quick load and selecting the appropriate resource...
2) It's also a good way of avoiding debug hacks from slipping their way intro production, since the release version will load a default BaseBuildConfiguration resource with default values, and therefore no hacks. 

The BaseBuildConfiguration includes certain hacks that would be relevant to most games. Projects are expected to extend this class into BuildConfiguration, which includes further hacks specific to that project, and to create at least two of this BuildConfiguration resource files: one for testing and one for release. The static variable BuildConfiguration.Default will return the appropriate one, ensuring the hacks are not enabled in production releases (unless we do edit the release configuration file)

An example of how to implement such hackd:


```gdscript
if BuildConfig.Default.enemy_type_override != null:
    enemy_type = BuildConfig.Default.enemy_type_override
    
...
    
if BuildConfig.Default.player_invulnerable:
    damage = 0
```

### InteractiveNode

**File**: `GodotBase/Scenes/InteractiveNode/interactive_node.gd`

Button-like interactive control with hover states.

**Signals**:
- `pressed`, `released`
- `hovered`, `unhovered`

**Styles**: `NORMAL`, `DISABLED`, `HOVERED`, `PRESSED`

---

## Settings System

**Location**: `GodotBase/SettingsSystem/`

A complete system for managing player settings with persistence.

### SettingInfo

Resource defining a single setting's metadata.

**Properties**:
- `name:String` - Internal identifier
- `dname:String` - Display name (localized)
- `description:String` - Help text
- `type:Type` - `BOOL`, `INT`, or `ARRAY`
- `min_value`, `max_value` - For INT type
- `options:Array` - For ARRAY type (cycle through options)

### SettingsContainer

Resource holding multiple settings and their values.

```gdscript
var container:SettingsContainer
container.get_setting_value(music_setting)  # Get value
container.set_setting(music_setting, false)  # Set value
```

### Settings (Autoload)

Global settings manager. Access via `Settings` autoload.

**Key methods**:
- `Settings.get_setting_value(setting:SettingInfo)` - Get current value
- `Settings.set_setting(setting:SettingInfo, value)` - Set and persist
- `Settings.cycle_setting(setting:SettingInfo)` - Cycle through options

**Signals**:
- `setting_changed(name:String, new_value:Variant)`

**Auto-applied reactions**:
- Audio bus muting (music, sfx, master)
- Window mode changes
- Language changes

### Pre-built Settings

Located in `GodotBase/SettingsSystem/BaseSettings/`:

| File | Purpose |
|------|---------|
| `music_enabled.tres` | Toggle music |
| `sfx_enabled.tres` | Toggle sound effects |
| `sound_enabled.tres` | Master volume toggle |
| `window_mode.tres` | Fullscreen/windowed |
| `language.tres` | Language selection |
| `graphics_quality.tres` | Graphics preset |
| `analytics_enabled.tres` | Analytics opt-in |

---

## Modifier System

**File**: `GodotBase/ModifierSystem/modifier.gd`

System for modifying numeric values (stats, damage, speed, etc.).

### Modifier Resource

```gdscript
var modifier = Modifier.new()
modifier.key = "damage"
modifier.value = 0.25  # +25%
modifier.mode = Modifier.Mode.MULTIPLICATIVE
```

**Modes**:
- `ADDITIVE` - `result = base + value`
- `MULTIPLICATIVE` - `result = base * (1.0 + value)`

### Applying Modifiers

```gdscript
# Apply all modifiers from multiple sources
var final_damage = Modifier.apply_all(base_damage, "damage", [
    player.modifiers,
    active_buffs,
    equipment_bonuses
])
```

---

## Components

**Location**: `GodotBase/Components/`

Reusable behavior nodes that attach to parents.

### BaseComponent

All components extend this. Automatically connects to parent's `ready` signal.

### FaderComponent

Fading in/out with state machine.

**States**: `INVISIBLE`, `FADING_IN`, `VISIBLE`, `FADING_OUT`

**Methods**:
- `fade_in(duration:float)`
- `fade_out(duration:float)`
- `set_visible_immediate()`
- `set_invisible_immediate()`

### Floater

Adds floating/bobbing animation to parent.

**Properties**:
- `amplitude:float` - Bob height
- `frequency:float` - Bob speed

### HoverEffects

Scale and color changes on hover.

**Properties**:
- `hover_scale:float` - Scale when hovered
- `hover_color:Color` - Modulate when hovered

### TypewriterEffect

Text reveal effect for labels.

**Properties**:
- `characters_per_second:float`
- `target_label:Label`

**Methods**:
- `start(text:String)`
- `skip()` - Show all text immediately

### SoundReaction

Plays sounds in response to signals.

### SizeFollower

Keeps node size matched to parent.

### SpritesheetRunner

Plays spritesheet animations.

### VisibilityController / Shower

Control visibility with optional fade.

### OpenLink

Opens URLs or platform store pages on interaction.

### ChangeTrigger

Triggers callbacks when a watched value changes.

---

## Scene Utilities

### WindowsLayer

**File**: `GodotBase/Scenes/WindowsLayer/windows_layer.gd`

Manages a stack of popup windows.

**Methods**:
- `push_window(window:BaseWindow)`
- `pop_window()`

### PauseController

**File**: `GodotBase/Scenes/PauseController/pause_controller.gd`

Multi-source pause management. Multiple systems can request pause; game unpauses only when all release.

```gdscript
Pause.request_pause("inventory_open")
# ... later
Pause.release_pause("inventory_open")
```

### VirtualCursor

**File**: `GodotBase/Scenes/VirtualCursor/virtual_cursor.gd`

Gamepad cursor for UI navigation when not using mouse.

### DraggableCamera

**File**: `GodotBase/Scenes/DraggableCamera/draggable_camera.gd`

Camera with pan and zoom support.

### DraggableLayer

**File**: `GodotBase/Scenes/DraggableLayer/draggable_layer.gd`

Layer where elements can be dragged.

### FloatingLabel

**File**: `GodotBase/Scenes/FloatingLabel/floating_label.gd`

Floating combat/damage text.

```gdscript
var label = FloatingLabel.create()
label.text = "-50"
label.position = enemy.position
world.add_child(label)
```

### Tooltip

**File**: `GodotBase/Scenes/Tooltip/tooltip.gd`

Hover tooltips for UI elements.

### PropertyAnimator

**File**: `GodotBase/Scenes/PropertyAnimator/property_animator.gd`

Animates object properties over time.

### RandomSequencer

**File**: `GodotBase/Scenes/RandomSequencer/random_sequencer.gd`

Weighted random selection from a sequence.

### SoundRandomizer

**File**: `GodotBase/Scenes/SoundRandomizer/sound_randomizer.gd`

Plays random sound variations.

### SaveIndicator

**File**: `GodotBase/Scenes/SaveIndicator/saving_indicator.gd`

Shows saving status icon.

### DebugLayer

**File**: `GodotBase/Scenes/DebugLayer/debug_layer.gd`

FPS counter and debug visualizations.

### EnemyGenerator

**File**: `GodotBase/Scenes/EnemyGenerator/enemy_generator.gd`

Spawns enemies based on configuration.

### CircleSprite / RegularPolygon

Drawing utilities for shapes.

---

## Autoloads

### InputManager

**File**: `GodotBase/Autoloads/input_manager.gd`

Detects input type and manages virtual cursor.

**Methods**:
- `InputManager.is_joypad()` - Currently using gamepad
- `InputManager.is_kbm()` - Currently using keyboard/mouse
- `InputManager.get_virtual_cursor_pos()` - Virtual cursor position
- `InputManager.get_left_joystick_position()` - Left stick Vector2
- `InputManager.get_right_joystick_position()` - Right stick Vector2

**Signals**:
- `input_type_changed(is_joypad:bool)`
- `virtual_cursor_clicked`

### BaseSaveManager

**File**: `GodotBase/Autoloads/save_manager.gd`

Queues saves with deadtime to prevent rapid successive saves.

**Signals**:
- `saving_started`
- `saving_finished`

**Properties**:
- `save_queued:bool`
- `is_saving:bool`

### SignalManager

**File**: `GodotBase/Autoloads/signal_manager.gd`

Delayed signal emission for frame-safe updates.

```gdscript
# Emit signal at the end of current frame
SignalManager.emit_this_frame(my_object.changed)
```

### AnalyticsManager

**File**: `GodotBase/Autoloads/analytics_manager.gd`

Event tracking and analytics (opt-in).

### BaseDebugActions

**File**: `GodotBase/Autoloads/debug_actions.gd`

Debug command binding and visualization toggles.

### MovieMaker

**File**: `GodotBase/Autoloads/movie_maker.gd`

GIF/WebP recording for promotional material.

---

## Global Utilities

### Utils

**File**: `GodotBase/Globals/utils.gd`

Static utility methods.

| Method | Purpose |
|--------|---------|
| `Utils.unique(array)` | Remove duplicates |
| `Utils.angle_distance(a, b)` | Shortest angle between two angles (radians) |
| `Utils.angle_distance_deg(a, b)` | Shortest angle (degrees) |
| `Utils.bunch(total, num_bunches)` | Distribute amount into N bunches |
| `Utils.rand_weighted(dict)` | Weighted random selection |
| `Utils.standardize_string(s)` | Capitalize, trim, format for display |
| `Utils.piecewise_linear(x, points)` | Evaluate piecewise linear function |
| `Utils.write_local_file(path, bytes)` | Write bytes to user:// |
| `Utils.get_layer_number(layer_name)` | Get physics layer by name |

### Flags

**File**: `GodotBase/Globals/flags.gd`

Static flags with build config overrides.

```gdscript
if Flags.DEBUG:
    # Debug-only code

if Flags.DEMO:
    # Demo version restrictions

if Flags.STEAM:
    # Steam-specific features
```

**Available flags**: `DEBUG`, `DEMO`, `WEB`, `STEAM`, `ITCHIO`

### BaseGroups

**File**: `GodotBase/Globals/base_groups.gd`

Group name constants for scene tree organization.

### BaseEnums

**File**: `GodotBase/base_enums.gd`

Common enumerations:
- `Sense` - `CLOCKWISE`, `COUNTERCLOCKWISE`
- `Direction4` - `RIGHT`, `DOWN`, `LEFT`, `UP`
- `Direction8` - 8-directional enum

---

## Integration

**Location**: `GodotBase/Integration/`

### BaseIntegrationController

Abstract base for platform integration.

**Methods** (override in platform-specific class):
- `initialize()`
- `mark_achievement_as_completed(id:String)`
- `open_store_page()`
- `get_current_language()-> String`
- `sync_file(path:String)` - Cloud save

### SteamIntegrationController

Steam-specific implementation.

**Features**:
- Achievement management
- Statistics tracking
- Steam overlay
- Cloud save sync with conflict resolution
- Language detection

**Usage**:
```gdscript
# Access via Integration autoload
Integration.mark_achievement_as_completed("FIRST_VICTORY")
Integration.open_store_page()
```

---

## Configuration

### GodotBase Settings Resource

**File**: `GodotBase/godot_base_settings.gd`

Configure GodotBase behavior per-project.

Create `res://Parameters/godot_base_settings.tres` to override defaults:

```gdscript
# In your project's godot_base_settings.tres
music_setting = preload("res://Settings/custom_music_setting.tres")
sfx_setting = preload("res://Settings/custom_sfx_setting.tres")
# ... other overrides
```

**Configurable**:
- Custom SettingInfo for base settings
- MovieMaker dimensions and format
- Default values for various systems
- Custom GodotBaseSettings to change how some GodotBase classes work

---

## Helper Classes

### Task

**File**: `GodotBase/Classes/task.gd`

Promise-like async result container.

### ResourceDict / ResourceList

**Files**: `GodotBase/Classes/resource_dict.gd`, `resource_list.gd`

Editor-friendly dictionary/array of resources.

### PolarVector2D

**File**: `GodotBase/Classes/polar_vector_2d.gd`

Polar coordinate representation.

### FocusManager

**File**: `GodotBase/Navigation/focus_manager.gd`

UI focus and keyboard navigation management.

### ResourceGetter


**File**: `GodotBase/Navigation/focus_manager.gd`

Resource-based class that can be used to gather all Resources of one type automatically. Place an instance of this class in the folder containing the resources (they can be in subfolders if you use check the relevant flag in the ResourceGetter). When you need all these resources you just need to preload the ResourceGetter instance and call get_all() to get a list of all the resource files next to the getter.

Example usage: we have a Resource-based class called MonsterModel, containing info about monsters. At several places in the code we want to get the info of all monsters, so we put a ResourceGetter in the folder containing the MonsterModel resource files and, in the MonsterModel class, we add a static var ALL = preload("/path/to/Monsters/_resource_getter.tres").get_all(). Now we can at any point do MonsterModel.ALL and we'll get a list of all MonsterModel files.

---

## Folder Structure

```
GodotBase/
├── Autoloads/          # Global singletons
├── Classes/            # Core data classes
├── Components/         # Behavior components
├── Distribution/       # Version info
├── EditorScripts/      # Editor-only tools
├── GameResources/      # Base resource classes
├── GameWorld/          # Actor/world system
├── Globals/            # Static utilities
├── Icons/              # UI icons
├── Integration/        # Platform integration
├── ModifierSystem/     # Stat modifiers
├── Navigation/         # Input/focus
├── Scenes/             # Reusable scenes
├── Sequences/          # Sequence system
├── SettingsSystem/     # Settings management
├── Shaders/            # Shader utilities
├── tests/              # Unit tests
├── base_enums.gd       # Common enums
└── godot_base_settings.gd  # Configuration
```
