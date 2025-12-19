extends Resource
class_name CircleInfo

@export var enabled:bool = true
@export var name:String = ""
@export var width:float = 5
@export var outer_radius:float = 50
@export var radius_factor:float = 1.0
@export_range(-360, 360) var start_angle:float = 0
@export_range(0, 360) var angular_width:float = 60
@export var color:Color = Color.WHITE

@export_group("FadeInto")
@export var fade_into_color:Color = Color.WHITE
@export_range(0, 1.0) var fade_into_factor:float = 0.0


@export_group("FadeFrom")
@export var fade_from_color:Color = Color.WHITE
@export_range(0, 1.0) var fade_from_factor:float = 0.0

@export_group("AngularFade")
@export var angular_fade_color:Color = Color.WHITE
@export_range(0, 1.0) var angular_fade_factor:float = 0.0
## Degrees from the center at which the fade starts
@export_range(0, 180.0) var angular_fade_start:float = 0.0
## Degrees from the center at which the fade ends
@export_range(0, 180.0) var angular_fade_end:float = 0.0


@export_group("RadialWaves")
@export var waves_enabled:bool = false
@export var waves_color:Color = Color.TRANSPARENT
@export var waves_period:float = 1.0
@export var waves_length:float = 10.0
@export_range(0, 1.0) var waves_factor_exponent:float = 0.0


@export_group("ColorMix")
@export var mix_color:Color = Color.WHITE
@export_range(0, 1.0) var mix_color_factor:float = 0.0


@export_group("ColorMix")
@export var line_lengths:float = 0.0
@export var line_thickness:float = 0.0

@export_group("Other")
@export var disable_antialising:bool = false


func enable()-> void: enabled = true
func disable()-> void: enabled = false
