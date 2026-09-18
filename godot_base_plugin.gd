@tool
## Registers GodotBase's autoloads when the plugin is enabled, and removes them
## again when it is disabled.
##
## Godot only calls _enable_plugin/_disable_plugin on the transition, so a
## project that already lists these autoloads in project.godot keeps them as
## they are; enabling the plugin in the editor is what writes them.
##
## The order below is the order the singletons are added in, and it matters:
## each one may use the ones declared before it.
extends EditorPlugin

const ROOT:String = "res://addons/GodotBase/"

## Autoload name -> script or scene inside GodotBase, in registration order.
const AUTOLOADS:Array[Array] = [
	["Log", "GameplayLogger/gameplay_logger.gd"],
	["SaveManager", "Autoloads/save_manager.gd"],
	["SignalManager", "Autoloads/signal_manager.gd"],
	["Integration", "Integration/integration_controller.gd"],
	["AudioManager", "Autoloads/audio_manager.gd"],
	["Settings", "SettingsSystem/settings_manager.gd"],
	["Pause", "Scenes/PauseController/pause_controller.gd"],
	["InputManager", "Autoloads/input_manager.gd"],
	["AutoplayerManager", "Autoplayers/autoplayer_manager.gd"],
	["PerfStats", "Performance/perf_stats.gd"],
]


func _enable_plugin() -> void:
	for autoload in AUTOLOADS:
		add_autoload_singleton(autoload[0], ROOT + autoload[1])


func _disable_plugin() -> void:
	for autoload in AUTOLOADS:
		remove_autoload_singleton(autoload[0])
