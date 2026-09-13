extends GutTest

func test_markers_for_known_creature_returns_its_points():
	var markers := CreatureArtAccents.markers_for(&"enemy_coypu")
	assert_eq(markers.size(), 2)

func test_markers_for_returns_a_copy_not_the_shared_table():
	var first := CreatureArtAccents.markers_for(&"enemy_coypu")
	first.append(Vector2(9, 9))
	first[0] = Vector2(-1, -1)
	var second := CreatureArtAccents.markers_for(&"enemy_coypu")
	assert_eq(second.size(), 2, "mutating the returned array must not corrupt the lookup table")
	assert_ne(second[0], Vector2(-1, -1))

func test_markers_for_unknown_creature_returns_empty():
	var markers := CreatureArtAccents.markers_for(&"enemy_nonexistent")
	assert_eq(markers, [] as Array[Vector2])
