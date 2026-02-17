shader_type canvas_item;

uniform vec4 dash_color : source_color = vec4(1.0, 1.0, 1.0, 1.0);

uniform float radius = 64.0;
uniform float width = 6.0;
uniform float dash_length = 12.0;
uniform float gap_length = 8.0;

// 0..1 animated offset
uniform float offset : hint_range(0.0, 1.0, 0.1) = 0.0;

void fragment() {
	// Convert UV to pixel coordinates
	vec2 tex_size = vec2(1.0) / TEXTURE_PIXEL_SIZE;
	vec2 p = UV * tex_size;
	vec2 center = tex_size * 0.5;

	vec2 d = p - center;
	float dist = length(d);

	// Ring mask (thickness in pixels)
	float half_w = width * 0.5;
	float ring = step(radius - half_w, dist) * (1.0 - step(radius + half_w, dist));

	if (ring <= 0.0) {
		discard;
	}

	// Angle around circle (0..TAU)
	float angle = atan(d.y, d.x);
	if (angle < 0.0) {
		angle += TAU;
	}

	// Convert angle to arc length in pixels
	float circumference = TAU * radius;
	float arc_len = angle / TAU * circumference;

	float pattern_len = dash_length + gap_length;
	float shifted = arc_len + offset * pattern_len;
	float m = mod(shifted, pattern_len);

	if (m > dash_length) {
		discard;
	}

	COLOR = dash_color;
}
