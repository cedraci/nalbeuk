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
// Measured on enemy_coypu.svg (via actual on-screen pixels, not just the SVG's
// own flat fills): Godot's SVG import rasterizes vector edges with
// anti-aliasing, blending the magenta key into adjacent subject colours. That
// produces a continuous gradient of magenta-tinted pixels from distance ~0.0
// up to ~0.6 from pure magenta — a hard cutoff below that range (previously
// 0.08) left most of the gradient visible as a magenta fringe. Real subject
// colours don't start until ~0.65-0.67 away, so key_tolerance ramps the whole
// measured gradient out smoothly while staying clear of real fur colours.
uniform float key_tolerance : hint_range(0.0, 1.0) = 0.6;

// Both samples are taken inline rather than through a subject_alpha() helper:
// Godot exposes stage built-ins only inside the stage function, so a helper
// reading TEXTURE fails to compile ("Unknown identifier in expression:
// 'TEXTURE'"), and passing TEXTURE in as a sampler2D argument trips the
// shader compiler's custom_samplers assertion.
void fragment() {
	vec4 tex_color = texture(TEXTURE, UV);
	vec2 dir = normalize(light_direction);
	vec2 offset = dir * TEXTURE_PIXEL_SIZE * rim_reach;
	// Chroma key: ramp alpha smoothly across the measured anti-aliasing
	// gradient instead of a hard cutoff, so blended edge pixels fade toward
	// transparent proportionally to how magenta-contaminated they are, rather
	// than snapping straight to opaque the moment they clear key_tolerance.
	float a = smoothstep(0.0, key_tolerance, distance(tex_color.rgb, key_color.rgb));
	vec4 toward_light = texture(TEXTURE, UV + offset);
	float a_toward_light = smoothstep(0.0, key_tolerance, distance(toward_light.rgb, key_color.rgb));
	float edge = clamp(a - a_toward_light, 0.0, 1.0) * rim_strength;
	COLOR = vec4(tex_color.rgb + rim_color.rgb * edge, a);
}
