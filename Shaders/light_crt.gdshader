// https://godotshaders.com/shader/lightweight-crt-effect/
shader_type canvas_item;

uniform sampler2D SCREEN_TEXTURE : hint_screen_texture;
uniform vec2 resolution = vec2(320.0, 180.0);

uniform float scan_line_amount : hint_range(0.0, 1.0) = 0.5;
uniform float warp_amount : hint_range(0.0, 1.0) = 0.05;
uniform float vignette_amount : hint_range(0.0, 1.0) = 0.5;
//uniform float vignette_intensity : hint_range(0.0, 1.0) = 0.3;
uniform float grille_amount : hint_range(0.0, 1.0) = 0.05;
uniform float brightness_boost : hint_range(1.0, 2.0) = 1.0;


void fragment() {	
    vec2 uv = SCREEN_UV;

    vec2 delta = uv - 0.5;
    float warp_factor = dot(delta, delta) * warp_amount;
    uv += delta * warp_factor;


	vec3 color = texture(SCREEN_TEXTURE, uv).rgb;
	
	// Scanlines
	
    //float scanline = sin(uv.y * resolution.y * PI) * 0.5 + 0.5;
    //scanline = mix(1.0, scanline, scan_line_amount * 0.5); 
	
    // Scanline: use cos() instead of sin() to avoid phase shift
    //// and drop the "+0.5" by remapping to [0..1]
    //float scanline = 0.5 + 0.5 * cos(uv.y * resolution.y * PI);
    //scanline = mix(1.0, scanline, scan_line_amount * 0.5);
	
	// Square wave version
	float row = fract(uv.y * resolution.y * 0.5); // 0..1 repeating
	float scanline = step(0.5, row);              // 0 for first half, 1 for second
	scanline = mix(1.0, 0.7, scanline * scan_line_amount);
	
	// Grille
	
    //float grille = mod(uv.x * resolution.x, 3.0) < 1.5 ? 0.95 : 1.05;
    //grille = mix(1.0, grille, grille_amount * 0.5);
	
	// replace conditional and mod with fract and smooth step
    //float gx = fract(uv.x * resolution.x / 3.0); // [0..1) band
    //float grille = mix(0.95, 1.05, step(0.5, gx));
    //grille = mix(1.0, grille, grille_amount * 0.5);

	// Boost brightness
	// float brightness = dot(color, color);
    // color *= 1.0+0.0*pow(brightness, 1.5);

	// Vignete
	
    //vec2 v_uv = uv * (1.0 - uv.xy);
    //float vignette = v_uv.x * v_uv.y * 15.0;
    //vignette = mix(1.0, vignette, vignette_amount * 0.7);
	
	 // (cheaper form: avoid extra mul)
    vec2 v = uv * (1.0 - uv);
    float vignette = v.x * v.y * 15.0;
    vignette = mix(1.0, vignette, vignette_amount * 0.7);
	
	color *= scanline;
	//color *= grille;
    color *= vignette;
	
	// Boost brightness
    color *= brightness_boost;

    COLOR.rgb = color;
    //COLOR.a = 1.0;
}