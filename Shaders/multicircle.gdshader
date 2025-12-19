shader_type canvas_item;

const int MAX_AMOUNT_OF_CIRCLES = 10;


uniform float[MAX_AMOUNT_OF_CIRCLES] outer_radii;
uniform float[MAX_AMOUNT_OF_CIRCLES] widths;
uniform float[MAX_AMOUNT_OF_CIRCLES] start_angles;
uniform float[MAX_AMOUNT_OF_CIRCLES] angular_widths;
uniform vec4[MAX_AMOUNT_OF_CIRCLES] colors : source_color;
uniform float[MAX_AMOUNT_OF_CIRCLES] radial_antialising_factors;
uniform float[MAX_AMOUNT_OF_CIRCLES] angular_antialising_factors;
uniform int max_amount_of_circles = 10; // case-by-case-optimization
uniform float radial_antialising2 = 0.0;
uniform float angular_antialising = 0.0;
uniform bool enable_antialising = true;


group_uniforms MultiCircle;
uniform bool[MAX_AMOUNT_OF_CIRCLES] enabled;
uniform vec4 background_color : source_color = vec4(0.0);
uniform vec3 mix_color : source_color;
uniform float mix_color_factor : hint_range(0.0, 1.0);
group_uniforms;


group_uniforms FadeInto;
uniform vec4[MAX_AMOUNT_OF_CIRCLES] fade_into_colors : source_color ;
uniform float[MAX_AMOUNT_OF_CIRCLES] fade_into_factors;
group_uniforms;

group_uniforms FadeFrom;
uniform vec4[MAX_AMOUNT_OF_CIRCLES] fade_from_colors : source_color;
uniform float[MAX_AMOUNT_OF_CIRCLES] fade_from_factors;
group_uniforms;

group_uniforms AngularFade;
uniform vec4[MAX_AMOUNT_OF_CIRCLES] angular_fade_colors : source_color;
uniform float[MAX_AMOUNT_OF_CIRCLES] angular_fade_factors;
uniform float[MAX_AMOUNT_OF_CIRCLES] angular_fade_starts;
uniform float[MAX_AMOUNT_OF_CIRCLES] angular_fade_ends;
group_uniforms;


group_uniforms RadialWaves;
uniform bool[MAX_AMOUNT_OF_CIRCLES] waves_enabled;
// Color used in the low part of the color waves
uniform vec4[MAX_AMOUNT_OF_CIRCLES] waves_colors : source_color;
uniform float[MAX_AMOUNT_OF_CIRCLES] waves_periods;
uniform float[MAX_AMOUNT_OF_CIRCLES] waves_lengths;
uniform float[MAX_AMOUNT_OF_CIRCLES] waves_factor_exponents;
group_uniforms;

group_uniforms ColorMix;
uniform vec4[MAX_AMOUNT_OF_CIRCLES] mix_colors : source_color;
uniform float[MAX_AMOUNT_OF_CIRCLES] mix_color_factors;
group_uniforms;


// Applies waves to color.
vec4 get_wave_color(float r2, int circle_idx)
{
	float r = sqrt(r2); // can't help it here
	float outer_radius = outer_radii[circle_idx];
	float outer_radius2 = outer_radius*outer_radius;
	float mix_point = r2/outer_radius2;

	float waves_temporal_freq = 1.0/waves_periods[circle_idx];
	float waves_spatial_freq = 1.0/waves_lengths[circle_idx];
	mix_point = 0.5+0.5*sin(TAU*waves_temporal_freq*TIME + TAU*waves_spatial_freq*r);

	float mix_point2 = pow(mix_point, waves_factor_exponents[circle_idx]);
	vec4 frag_color = mix(colors[circle_idx], waves_colors[circle_idx], mix_point2);
	return frag_color;
}

vec4 draw_circle(vec4 bg_color, float r2_px, float degs, vec4 color, int circle_index,
				float outer_radius, float start_angle, float length_degrees, float width,
				float fade_into_factor, vec4 fade_into_color,
				float fade_from_factor, vec4 fade_from_color,
				float angular_fade_factor, vec4 angular_fade_color, 
				float angular_fade_start, float angular_fade_end,
				float _mix_color_factor, vec4 _mix_color,
				float radial_antialising_factor, float angular_antialising_factor
				)
{
	vec4 this_color = bg_color;
	float outer_radius2 = outer_radius*outer_radius;

	if(r2_px > outer_radius2)
	{
		return this_color;
	}

	degs -= start_angle;
	degs = mod(degs, 360.0);

	float inner_radius = outer_radius - width;
	float inner_radius2 = inner_radius*inner_radius;

	if(inner_radius2 >= r2_px)
		return this_color;
	if(r2_px >= outer_radius2)
		return this_color;
	if(degs > length_degrees)
		return this_color;


	if(waves_enabled[circle_index])
		color = get_wave_color(r2_px, circle_index);

	this_color = color;

	float p, c;
	// Fade into another color as it nears the rim
	if(fade_into_factor > 0.0)
	{
		float f = 1.0-fade_into_factor;
		p = r2_px/outer_radius2;
		if(p > f)
			c = (p-f)/(1.0-f);
		this_color = mix(this_color, fade_into_color, c);
	}
	// Fade from another color as it gets
	if(fade_from_factor > 0.0)
	{
		float f = 1.0-fade_from_factor;
		p = 1.0-r2_px/outer_radius2;
		c = 0.0;
		if(p > f)
			c = (p-f)/(1.0-f);
		this_color = mix(this_color, fade_from_color, c);
	}

	if(angular_fade_factor > 0.0)
	{
		float f = 1.0-angular_fade_factor;
		float degs_from_center = abs(degs - length_degrees/2.0);
		
		if(degs_from_center >= angular_fade_start)
		{
			// Percentage of the way between the center of the arc and its edge
			float fade_width = angular_fade_end-angular_fade_start;
			float degs_into_the_fade = degs_from_center-angular_fade_start;
			p = degs_into_the_fade/fade_width;
			c = 0.0;
			if(p > f)
				c = (p-f)/(1.0-f);
			c = smoothstep(0.0, 1.0, c);
			this_color = mix(this_color, angular_fade_color, c);		
		}		
		if(degs_from_center >= angular_fade_end)
		{
			this_color = angular_fade_color;
		}
	}

	if(_mix_color_factor > 0.0)
	{
		 //Mix with a secondary color
		this_color.rgb = mix(this_color.rgb, _mix_color.rgb, _mix_color_factor);
		this_color.a = mix(this_color.a, _mix_color.a, _mix_color_factor);
	}

	if(enable_antialising)
	{
		float _radial_antialising2 = radial_antialising2*(1.0+radial_antialising_factor);
		if(_radial_antialising2 > 0.0)
		{
			this_color.a *= smoothstep(outer_radius2, outer_radius2-_radial_antialising2, r2_px);
		}

		float _angular_antialising = angular_antialising*(1.0+angular_antialising_factor);
		if(_angular_antialising > 0.0)
		{
			if(length_degrees < 360.0)
			{
				float fade_start = TAU*atan(_angular_antialising/sqrt(r2_px));
				this_color.a *= smoothstep(length_degrees, length_degrees-fade_start, degs);
				this_color.a *= smoothstep(0, fade_start, degs);
			}
		}
	}

	return this_color;
}

void fragment()
{
	vec2 uv = (UV*2.0)-1.0;
	vec2 px = 0.5*uv/TEXTURE_PIXEL_SIZE;

	float r2_px = dot(px, px);

	COLOR = background_color;

	float degs = degrees(atan(px.y, px.x));

	for(int i=0;i<max_amount_of_circles;i++)
	{
		if(enabled[i] == false)
			continue;
		vec4 circle_color = draw_circle(COLOR, r2_px, degs, colors[i], i,
			outer_radii[i], start_angles[i], angular_widths[i], widths[i],
			fade_into_factors[i], fade_into_colors[i],
			fade_from_factors[i], fade_from_colors[i],
			angular_fade_factors[i], angular_fade_colors[i], 
			angular_fade_starts[i], angular_fade_ends[i],
			mix_color_factors[i], mix_colors[i],
			radial_antialising_factors[i], angular_antialising_factors[i]
		);
		
		if(circle_color.a >= 0.99999 || COLOR == background_color)
			COLOR = circle_color;
		else
			COLOR.rgba = mix(COLOR.rgba, circle_color.rgba, circle_color.a);
		//COLOR = circle_color;
	}

	 //Mix with a secondary color
	if (mix_color_factor > 0.0)
		COLOR.rgb = mix(COLOR.rgb, mix_color, mix_color_factor);
}
