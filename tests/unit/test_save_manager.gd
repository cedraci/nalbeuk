extends GutTest

const TEST_PATH := "user://test_save.json"

func before_each() -> void:
	SaveManager.save_path = TEST_PATH
	SaveManager.delete_save()
	_delete_if_exists(TEST_PATH + ".bad")
	MetaState.reset()
	SaveManager.run_snapshot = null

func _delete_if_exists(path: String) -> void:
	if FileAccess.file_exists(path):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(path))

func _write_raw(text: String) -> void:
	var file := FileAccess.open(TEST_PATH, FileAccess.WRITE)
	file.store_string(text)
	file.close()

func test_save_then_load_round_trips_meta_state():
	MetaState.level = 3
	MetaState.xp = 12
	MetaState.unlocked_skill_nodes = [&"dwarven_grit"]
	MetaState.owned_equipment_ids = [&"leather_vest"]
	MetaState.equipped_armor_id = &"leather_vest"
	assert_true(SaveManager.save_game())
	MetaState.reset()
	assert_true(SaveManager.load_game())
	assert_eq(MetaState.level, 3)
	assert_eq(MetaState.xp, 12)
	assert_eq(MetaState.unlocked_skill_nodes, [&"dwarven_grit"] as Array[StringName])
	assert_eq(MetaState.equipped_armor_id, &"leather_vest")

func test_save_writes_versioned_json():
	SaveManager.save_game()
	var file := FileAccess.open(TEST_PATH, FileAccess.READ)
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	file.close()
	assert_true(parsed is Dictionary)
	assert_eq(int(parsed["version"]), SaveManager.SAVE_VERSION)
	assert_true(parsed["meta"] is Dictionary)

func test_load_with_no_file_resets_and_returns_false():
	MetaState.level = 5
	assert_false(SaveManager.load_game())
	assert_eq(MetaState.level, 1)

func test_load_with_corrupt_json_quarantines_the_file_and_resets():
	_write_raw("{ this is not json")
	MetaState.level = 5
	assert_false(SaveManager.load_game())
	assert_eq(MetaState.level, 1)
	assert_false(FileAccess.file_exists(TEST_PATH), "The bad file is moved, not left in place.")
	assert_true(FileAccess.file_exists(TEST_PATH + ".bad"), "The bad file is kept for inspection.")

func test_load_with_wrong_version_quarantines_the_file_and_resets():
	_write_raw(JSON.stringify({"version": 99, "meta": {"level": 6}}))
	assert_false(SaveManager.load_game())
	assert_eq(MetaState.level, 1)
	assert_true(FileAccess.file_exists(TEST_PATH + ".bad"))

func test_load_with_non_dictionary_meta_quarantines_the_file_and_resets():
	_write_raw(JSON.stringify({"version": 1, "meta": [1, 2, 3]}))
	assert_false(SaveManager.load_game())
	assert_eq(MetaState.level, 1)
	assert_true(FileAccess.file_exists(TEST_PATH + ".bad"))

func test_quarantine_overwrites_a_previous_bad_file():
	_write_raw("first bad")
	SaveManager.load_game()
	_write_raw("second bad")
	SaveManager.load_game()
	var bad := FileAccess.open(TEST_PATH + ".bad", FileAccess.READ)
	var text := bad.get_as_text()
	bad.close()
	assert_eq(text, "second bad")

func test_delete_save_removes_the_file_and_is_safe_when_missing():
	SaveManager.save_game()
	assert_true(FileAccess.file_exists(TEST_PATH))
	SaveManager.delete_save()
	assert_false(FileAccess.file_exists(TEST_PATH))
	SaveManager.delete_save()
	assert_false(FileAccess.file_exists(TEST_PATH))

func test_save_game_writes_version_two_with_a_null_run_when_nothing_is_suspended():
	SaveManager.run_snapshot = null
	SaveManager.save_game()
	var file := FileAccess.open(TEST_PATH, FileAccess.READ)
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	file.close()
	assert_eq(int(parsed["version"]), 2)
	assert_true(parsed.has("run"))
	assert_null(parsed["run"])

func test_run_snapshot_round_trips_through_the_file():
	SaveManager.run_snapshot = {"current_floor": 3, "gold": 12, "deck": ["dwarf_strike"]}
	SaveManager.save_game()
	SaveManager.run_snapshot = null
	assert_true(SaveManager.load_game())
	assert_true(SaveManager.has_run_snapshot())
	assert_eq(int(SaveManager.run_snapshot["current_floor"]), 3)
	assert_eq(int(SaveManager.run_snapshot["gold"]), 12)

func test_version_one_file_loads_with_no_suspended_run():
	_write_raw(JSON.stringify({"version": 1, "meta": {"level": 4}}))
	SaveManager.run_snapshot = {"stale": true}
	assert_true(SaveManager.load_game())
	assert_eq(MetaState.level, 4)
	assert_false(SaveManager.has_run_snapshot())
	assert_false(FileAccess.file_exists(TEST_PATH + ".bad"), "A version-1 file is not quarantined.")

func test_malformed_run_section_is_dropped_but_the_character_is_kept():
	_write_raw(JSON.stringify({"version": 2, "meta": {"level": 3}, "run": "garbage"}))
	assert_true(SaveManager.load_game())
	assert_eq(MetaState.level, 3)
	assert_false(SaveManager.has_run_snapshot())
	assert_false(FileAccess.file_exists(TEST_PATH + ".bad"))

func test_delete_save_clears_the_snapshot():
	SaveManager.run_snapshot = {"current_floor": 1}
	SaveManager.delete_save()
	assert_false(SaveManager.has_run_snapshot())

func test_missing_file_clears_the_snapshot():
	SaveManager.run_snapshot = {"current_floor": 1}
	assert_false(SaveManager.load_game())
	assert_false(SaveManager.has_run_snapshot())
