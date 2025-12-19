shader_type canvas_item;

uniform float outer_radius = 50.0;
uniform float width = 5.0;
uniform float start_angle : hint_range(0.0, 360.0, 0.1) = 0.0;
uniform float length_degrees : hint_range(0.0, 360.0, 0.1) = 45.0;
uniform vec4 color : source_color = vec4(1.0);


group_uniforms FadeInto;
uniform vec4 fade_into_color : source_color = vec4(1.0);
uniform float fade_into_factor : hint_range(0.0, 1.0, 0.01) = 1.0;
group_uniforms;

group_uniforms FadeFrom;
uniform vec4 fade_from_color : source_color = vec4(1.0);
uniform float fade_from_factor : hint_range(0.0, 1.0, 0.01) = 1.0;
group_uniforms;

group_uniforms AngularFade;
uniform vec4 angular_fade_color : source_color = vec4(vec3(1.0), 0.0);
uniform float angular_fade_factor : hint_range(0.0, 1.0, 0.01) = 1.0;
group_uniforms;


group_uniforms RadialWaves;
uniform bool waves = false;
// Color used in the low part of the color waves
uniform vec4 waves_color : source_color = vec4(vec3(1.0), 0.0);
uniform float waves_period = 1.0;
uniform float waves_length = 40.0;
uniform float waves_factor_exponent = 0.1;
group_uniforms;

group_uniforms ColorMix;
uniform vec3 mix_color : source_color = vec3(1.0);
uniform float mix_color_factor : hint_range(0.0, 1.0, 0.05) = 0.0;

group_uniforms;

group_uniforms RadialLine;
uniform float line_length = 0;
uniform float line_thickness = 2;
group_uniforms;


vec4 get_color(float r)
{
	if(waves == false)
		return color;
	float mix_point = r/outer_radius;

	float waves_temporal_freq = 1.0/waves_period;
	float waves_spatial_freq = 1.0/waves_length;
	mix_point = 0.5+0.5*sin(2.0*PI*waves_temporal_freq*TIME + 2.0*PI*waves_spatial_freq*r);

	vec4 frag_color = mix(color, waves_color, pow(mix_point, waves_factor_exponent));
	return frag_color;
}

bool between(float a, float b, float v)
{
	return a < v && v < b;
}

bool can_early_abort(vec2 uv)
{
	float a0 = start_angle - length_degrees/2.0;
	float af = start_angle + length_degrees/2.0;

	if(a0 < 0.0)
		a0 += 360.0;
	if(af < 0.0)
		af += 360.0;

	if(uv.x > 0.0)
	{
		if(uv.y > 0.0)
		{
			// Second quadrant
			if(between(0, 90.0, a0) && between(0.0, 90.0, af))
				return true;
		}
		else
		{
			// First quadrant
			if(between(270, 360, a0) && between(270, 360, af))
				return true;
		}
	}
	else
	{
		if(uv.y > 0.0)
		{
			// Third quadrant
			if(between(90, 180, a0) && between(90, 180, af))
				return true;
		}
		else
		{
			// Fourth quadrant
			if(between(180, 270, a0) && between(180, 270, af))
				return true;
		}
	}
	return false;
}

void fragment() {
	float inner_radius = outer_radius - width;

	// Called for every pixel the material is visible on.
	vec2 uv = (UV*2.0)-1.0;

	//if(can_early_abort(uv))
		//discard;

	vec2 px = 0.5*uv/TEXTURE_PIXEL_SIZE;

	float r_px = length(px);

	if(r_px > outer_radius)
		discard;

	float degs = degrees(atan(px.y/px.x))+0.0;
	if(uv.x < 0.0)
		degs += 180.0;
	degs -= start_angle;
	degs = mod(degs, 360.0);

	bool in_circle = true;

	if(r_px >= outer_radius)
		in_circle = false;
	else if(inner_radius >= r_px)
		in_circle = false;
	else if(degs > length_degrees)
		in_circle = false;

	if(in_circle)
	{
		COLOR = get_color(r_px);
		//COLOR.rgb *= degs/360.0;

		float p, c;

		// Fade into another color as it nears the rim
		p = r_px/outer_radius;
		if(p > fade_into_factor)
			c = (p-fade_into_factor)/(1.0-fade_into_factor);
		COLOR.rgba = mix(COLOR.rgba, fade_into_color.rgba, c);
		//COLOR.rgb = mix(COLOR.rgb, fade_into_color.rgb, r_inv);

		// Fade from another color as it gets
		p = 1.0-r_px/outer_radius;
		c = 0.0;
		if(p > fade_from_factor)
			c = (p-fade_from_factor)/(1.0-fade_from_factor);
		COLOR.rgba = mix(COLOR.rgba, fade_from_color.rgba, c);

		//COLOR.a = mix(COLOR.a, fade_into_color.a, r_inv);
		float degs_from_center = abs(degs - length_degrees/2.0);
		// Percentage of the way between the center of the arc and its edge
		p = degs_from_center/(length_degrees/2.0);
		c = 0.0;
		if(p > angular_fade_factor)
			c = (p-angular_fade_factor)/(1.0-angular_fade_factor);
		//COLOR.a = c;
		COLOR = mix(COLOR, angular_fade_color, c);
	}
	else
	{
		COLOR.a = 0.0;
	}



    // Radial line
	if(line_length > 0.0)
	{
	    float mid_angle = radians(mod(start_angle + length_degrees * 0.5, 360.0));
	    vec2 dir = vec2(cos(mid_angle), sin(mid_angle));
	    vec2 perp = vec2(-dir.y, dir.x);

	      // Project pixel onto the line direction and perpendicular
	    float proj = dot(px, dir);
	    float dist = abs(dot(px, perp));

	    if (outer_radius - line_length < proj && proj < outer_radius && dist < line_thickness * 0.5)
	        COLOR = color;
	}

	// Mix with a secondary color
	COLOR.rgb = mix(COLOR.rgb, mix_color, mix_color_factor);
}
