shader_type canvas_item;

uniform float width = 0.05;
uniform float x : hint_range(0.0, 1.0, 0.01) = 0.4;
uniform float degs : hint_range(0.0, 360.0, 0.1) = 15.0;
uniform float slope = 0.1;
uniform float mix_factor : hint_range(0.0, 1.0, 0.01) = 1.0;
uniform vec4 color : source_color = vec4(vec3(1.0), 0.8);

void fragment() {
	// Called for every pixel the material is visible on.
	vec2 uv = (UV*2.0)-1.0;
	vec2 px = 0.5*uv/TEXTURE_PIXEL_SIZE;

	float x_offset = UV.y/tan(radians(degs));
	float p = x*(1.0+width);
	float x_d = abs(UV.x-p-x_offset);
	if(x_d < width/2.0)
	{
		COLOR = mix(COLOR, color, mix_factor);
	}
}
