shader_type canvas_item;
const int FRONTIERS_NUM = 3;

uniform float[3] frontier_slopes_degrees;
uniform float[3] frontier_offsets;
uniform bool[3] keep_positive;

varying float[3] frontier_slopes;

void vertex()
{
	for(int i=0;i<FRONTIERS_NUM;i++)
	{
		frontier_slopes[i] = tan(radians(frontier_slopes_degrees[i]));
	}

}


void fragment() {
	vec2 uv = (UV*2.0)-1.0;

	for(int i=0;i<FRONTIERS_NUM;i++)
	{
		float frontier_slope = frontier_slopes[i];//tan(radians(frontier_slopes_degrees[i]));
		float slope_y = frontier_slope*uv.x + frontier_offsets[i];
		if(keep_positive[i])
		{
			if(uv.y < slope_y)
			{
				COLOR.a = 0.0;
				discard;
			}
		}
		else
		{
			if(uv.y >= slope_y)
			{
				COLOR.a = 0.0;
				discard;
			}
		}
	}
}
