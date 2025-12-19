/////////////////////////////////
// 2D Radial Distortion Shader //
/////////////////////////////////

// Screen space shader for Godot, based on: https://gist.github.com/aggregate1166877/a889083801d67917c26c12a98e7f57a7

// adapted from: https://godotshaders.com/shader/2d-radial-distortion-fisheye-barrel/
// changed so that it only affects a circular shape

shader_type canvas_item;

uniform float aspect = 0.5625;
uniform float distortion = 1.0;
uniform float radius = 1.0;
uniform float alpha = 1.0;
uniform float crop = 1.0;
uniform vec4 crop_color : source_color = vec4(0,0,0,1);

uniform float effect_radius = 1.0;

//uniform vec2 size = vec2(70.0, 40.0);
uniform sampler2D SCREEN_TEXTURE : hint_screen_texture;

varying vec2 full_uv;

vec2 distort(vec2 p)
{
	float d = length(p);
	float z = sqrt(distortion + d * d * -distortion);
	float r = atan(d, z) / 3.1415926535;
	float phi = atan(p.y, p.x);
	return vec2(r * cos(phi) * (1.0 / aspect) + 0.5, r * sin(phi) + 0.5);
}

void vertex()
{
	full_uv = VERTEX.xy;
}

void fragment()
{
	//vec2 uv = full_uv/size;
	vec2 uv = (UV * 2.0 - 1.0);
	vec2 xy = uv; // move origin of UV coordinates to center of screen

	xy = vec2(xy.x * aspect, xy.y); // adjust aspect ratio

	float d = length(xy); // distance from center

	vec4 tex;

	if (d <= radius && length(uv) <= 1.0)
	{
		xy = distort(xy);
		tex = texture(SCREEN_TEXTURE, xy);
		COLOR = tex;
		COLOR.a = alpha;
	}

	// radial crop
	if (d > crop)
	{
		//COLOR = crop_color;
	}
}