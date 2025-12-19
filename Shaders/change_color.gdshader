shader_type canvas_item;

uniform float mix_factor :hint_range(0.0, 1.0) = 0;
uniform vec3 mix_color : source_color = vec3(1, 1, 1);
uniform float saturation :hint_range(0.0, 1.0) = 1.0;

void fragment() {

	if (saturation < 1.0)
	{
    	vec4 tex_color = texture(TEXTURE, UV);
    	COLOR.rgb = mix(tex_color.rgb, vec3(dot(tex_color.rgb, vec3(0.299, 0.587, 0.114))), 1.0-saturation);
	}

	if(mix_factor > 0.0)
		COLOR.rgb = mix(COLOR.rgb, mix_color.rgb, mix_factor);
}
