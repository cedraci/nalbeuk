extends RefCounted
class_name CreatureArtAccents

# Eye/mouth accent-glow positions for creature art, keyed by the same art_id
# ArtPlaceholder resolves to a file (scripts/ui/theme/art_placeholder.gd).
# Normalized (0-1) within the art's own display size, hand-placed per
# creature by eye — not derived automatically. See
# docs/superpowers/specs/2026-09-13-creature-art-pipeline-design.md.

const _MARKERS: Dictionary = {
	&"enemy_coypu": [Vector2(0.34, 0.40), Vector2(0.30, 0.55)] as Array[Vector2],
}

static func markers_for(art_id: StringName) -> Array[Vector2]:
	if _MARKERS.has(art_id):
		return _MARKERS[art_id] as Array[Vector2]
	return [] as Array[Vector2]
