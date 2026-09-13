shader_type canvas_item;

// Ember rim-light along one edge, matching the "one warm light source per
// screen" rule (UiTokens/TorchGlow) — the direction is fixed so every
// creature is lit consistently, with no per-asset tuning. See
// docs/superpowers/specs/2026-09-13-creature-art-pipeline-design.md.

uniform vec2 light_direction = vec2(0.6, -0.8);
uniform vec4 rim_color : source_color = vec4(0.910, 0.643, 0.290, 1.0);
uniform float rim_strength : hint_range(0.0, 2.0) = 1.0;
uniform float rim_reach : hint_range(1.0, 8.0) = 3.0;

void fragment() {
	vec4 tex_color = texture(TEXTURE, UV);
	vec2 dir = normalize(light_direction);
	vec2 offset = dir * TEXTURE_PIXEL_SIZE * rim_reach;
	float alpha_here = tex_color.a;
	float alpha_toward_light = texture(TEXTURE, UV + offset).a;
	float edge = clamp(alpha_here - alpha_toward_light, 0.0, 1.0) * rim_strength;
	COLOR = vec4(tex_color.rgb + rim_color.rgb * edge, tex_color.a);
}
