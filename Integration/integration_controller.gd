extends BaseIntegrationController
## Platform-neutral entry point for the Integration autoload.
##
## The Steam controller is reached by path at runtime rather than being the
## autoload itself. Its Steam.* calls are resolved when the script is parsed,
## so on a platform without the GodotSteam extension the parser merely reaching
## that script is a parse error, which no runtime Flags.STEAM check inside it
## can prevent. The web export has no GodotSteam build and excludes the
## extension, so the autoload has to be a script that never names Steam.

const STEAM_CONTROLLER_PATH := \
	"res://GodotBase/Integration/Steam/steam_integration_controller.gd"


func _ready()-> void:
	_swap_in_platform_controller()

	# Reaches the platform controller's initialize() when the swap happened,
	# and the base no-op when it did not.
	initialize()


## Replaces this node's script with the controller for the platform the game is
## running on, so that every Integration.* call site reaches the platform
## implementation without this class having to forward anything.
##
## Swapping the script keeps the same autoload node, but _ready() does not fire
## again afterwards, which is why the caller drives initialize() by hand.
func _swap_in_platform_controller()-> void:
	if not Flags.STEAM or not Engine.has_singleton("Steam"):
		return

	# A script that failed to parse still loads as a non-null GDScript, so
	# can_instantiate() is the check that matters rather than a null test.
	var steam_script:Script = load(STEAM_CONTROLLER_PATH)
	if steam_script == null or not steam_script.can_instantiate():
		push_error("Steam integration controller could not be loaded from %s"
			% STEAM_CONTROLLER_PATH)
		return

	set_script(steam_script)
