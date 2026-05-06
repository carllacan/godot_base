shader_type canvas_item;

const int MAX_LINES = 50;

uniform vec4[MAX_LINES] segments; // (x1, y1, x2, y2) in pixels
uniform int line_count = 0;

group_uniforms Line;
uniform float line_half_width : hint_range(0.0, 100.0) = 3.0;
uniform vec4 line_color : source_color = vec4(1.0, 1.0, 1.0, 1.0);
group_uniforms;

group_uniforms Border;
uniform float border_width : hint_range(0.0, 50.0) = 1.5;
uniform vec4 border_color : source_color = vec4(0.0, 0.0, 0.0, 1.0);
group_uniforms;

uniform vec4 background_color : source_color = vec4(0.0, 0.0, 0.0, 0.0);
uniform float antialias_px : hint_range(0.0, 4.0) = 1.0;


float dist_to_segment(vec2 p, vec2 a, vec2 b) {
	vec2 ab = b - a;
	float len_sq = dot(ab, ab);
	if (len_sq < 0.0001) {
		return length(p - a);
	}
	float t = clamp(dot(p - a, ab) / len_sq, 0.0, 1.0);
	return length(p - (a + t * ab));
}


void fragment() {
	vec2 texture_size = 1.0 / TEXTURE_PIXEL_SIZE;
	vec2 pixel = UV * texture_size - texture_size * 0.5;

	float min_dist = 1.0e10;
	for (int i = 0; i < line_count; i++) {
		float d = dist_to_segment(pixel, segments[i].xy, segments[i].zw);
		min_dist = min(min_dist, d);
	}

	float outer_edge = line_half_width + border_width;

	float line_alpha  = 1.0 - smoothstep(line_half_width - antialias_px, line_half_width, min_dist);
	float border_alpha = 1.0 - smoothstep(outer_edge - antialias_px, outer_edge, min_dist);

	vec4 color = background_color;
	color = mix(color, border_color * vec4(1.0, 1.0, 1.0, border_alpha), border_alpha * border_color.a);
	color = mix(color, line_color * vec4(1.0, 1.0, 1.0, line_alpha),   line_alpha  * line_color.a);

	COLOR = color;
}
