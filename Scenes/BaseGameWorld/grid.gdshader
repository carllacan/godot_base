shader_type canvas_item;

uniform vec2 offset = vec2(0.0, 0.0);
uniform vec2 cell_size = vec2(20.0, 50.0);
uniform float grid_tickness = 3.0;
uniform vec4 background_color : source_color = vec4(1.0);
uniform vec4 grid_color : source_color = vec4(vec3(0.0), 1.0);

void fragment() {
	//vec2 uv = (UV-0.5)*2.0;
	vec2 uv = (UV*2.0)-1.0;
	vec2 xy = 0.5*uv/TEXTURE_PIXEL_SIZE + offset;

	vec2 cell_uv = fract(xy/cell_size);
	vec2 cell_xy = cell_uv*cell_size;
	if(cell_xy.x < grid_tickness/2.0 || cell_xy.x > cell_size.x - grid_tickness/2.0)
		COLOR = grid_color;
	else if(cell_xy.y < grid_tickness/2.0 || cell_xy.y > cell_size.y - grid_tickness/2.0)
		COLOR = grid_color;
	else
		COLOR = background_color;
	//COLOR.rgb = vec3(1.0)*fract(abs(xy.x)*50.0);
	//COLOR.rgb = vec3(x_mod);

}
