extends GutTest

func test_markers_for_known_creature_returns_its_points():
	var markers := CreatureArtAccents.markers_for(&"enemy_coypu")
	assert_eq(markers.size(), 2)

func test_markers_for_unknown_creature_returns_empty():
	var markers := CreatureArtAccents.markers_for(&"enemy_nonexistent")
	assert_eq(markers, [] as Array[Vector2])
