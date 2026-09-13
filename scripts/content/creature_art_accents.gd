extends RefCounted
class_name CreatureArtAccents

# Eye/mouth accent-glow positions for creature art, keyed by the same art_id
# ArtPlaceholder resolves to a file (scripts/ui/theme/art_placeholder.gd).
# Normalized (0-1) within the art's own display size, hand-placed per
# creature by eye — not derived automatically. See
# docs/superpowers/specs/2026-09-13-creature-art-pipeline-design.md.

const _MARKERS: Dictionary = {
	# Eye, then nose/mouth, read off the 288x266 crop of the reference photo.
	&"enemy_coypu": [Vector2(0.55, 0.26), Vector2(0.71, 0.36)] as Array[Vector2],
}

static func markers_for(art_id: StringName) -> Array[Vector2]:
	if _MARKERS.has(art_id):
		# duplicate(): `const` is not deep-immutable in GDScript, so handing
		# out the stored Array would let a caller mutate this lookup table.
		return (_MARKERS[art_id] as Array[Vector2]).duplicate()
	return [] as Array[Vector2]
