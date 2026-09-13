shader_type canvas_item;

// Ember rim-light along one edge, matching the "one warm light source per
// screen" rule (UiTokens/TorchGlow) — the direction is fixed so every
// creature is lit consistently, with no per-asset tuning. See
// docs/superpowers/specs/2026-09-13-creature-art-pipeline-design.md.
//
// The traced SVGs are fully opaque (vtracer emits flat filled paths and gives
// no way to carry alpha), so the subject's silhouette is recovered by
// chroma-keying the synthetic magenta background that tools/art/trace_creature.py
// mattes the subject onto. That key drives BOTH the cutout and the rim-light's
// edge detection — deriving the rim from the texture's own alpha would be a
// no-op here, because there isn't any.

uniform vec2 light_direction = vec2(0.6, -0.8);
uniform vec4 rim_color : source_color = vec4(0.910, 0.643, 0.290, 1.0);
uniform float rim_strength : hint_range(0.0, 2.0) = 1.0;
uniform float rim_reach : hint_range(1.0, 8.0) = 3.0;
uniform vec4 key_color : source_color = vec4(1.0, 0.0, 1.0, 1.0);
// Measured margin on enemy_coypu.svg: the keyed background sits 0.000-0.006
// from pure magenta, the nearest subject colour 0.667 away.
uniform float key_tolerance : hint_range(0.0, 0.5) = 0.08;

// Both samples are taken inline rather than through a subject_alpha() helper:
// Godot exposes stage built-ins only inside the stage function, so a helper
// reading TEXTURE fails to compile ("Unknown identifier in expression:
// 'TEXTURE'"), and passing TEXTURE in as a sampler2D argument trips the
// shader compiler's custom_samplers assertion.
void fragment() {
	vec4 tex_color = texture(TEXTURE, UV);
	vec2 dir = normalize(light_direction);
	vec2 offset = dir * TEXTURE_PIXEL_SIZE * rim_reach;
	// Chroma key: a pixel belongs to the subject iff its colour is further
	// than key_tolerance from the matte's key colour.
	float a = step(key_tolerance, distance(tex_color.rgb, key_color.rgb));
	vec4 toward_light = texture(TEXTURE, UV + offset);
	float a_toward_light = step(key_tolerance, distance(toward_light.rgb, key_color.rgb));
	float edge = clamp(a - a_toward_light, 0.0, 1.0) * rim_strength;
	COLOR = vec4(tex_color.rgb + rim_color.rgb * edge, a);
}
