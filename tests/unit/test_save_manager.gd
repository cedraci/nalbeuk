extends GutTest

const TEST_PATH := "user://test_save.json"

func before_each() -> void:
	SaveManager.save_path = TEST_PATH
	SaveManager.delete_save()
	_delete_if_exists(TEST_PATH + ".bad")
	MetaState.reset()

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
	assert_true(SaveManager.save_meta())
	MetaState.reset()
	assert_true(SaveManager.load_meta())
	assert_eq(MetaState.level, 3)
	assert_eq(MetaState.xp, 12)
	assert_eq(MetaState.unlocked_skill_nodes, [&"dwarven_grit"] as Array[StringName])
	assert_eq(MetaState.equipped_armor_id, &"leather_vest")

func test_save_writes_versioned_json():
	SaveManager.save_meta()
	var file := FileAccess.open(TEST_PATH, FileAccess.READ)
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	file.close()
	assert_true(parsed is Dictionary)
	assert_eq(int(parsed["version"]), SaveManager.SAVE_VERSION)
	assert_true(parsed["meta"] is Dictionary)

func test_load_with_no_file_resets_and_returns_false():
	MetaState.level = 5
	assert_false(SaveManager.load_meta())
	assert_eq(MetaState.level, 1)

func test_load_with_corrupt_json_quarantines_the_file_and_resets():
	_write_raw("{ this is not json")
	MetaState.level = 5
	assert_false(SaveManager.load_meta())
	assert_eq(MetaState.level, 1)
	assert_false(FileAccess.file_exists(TEST_PATH), "The bad file is moved, not left in place.")
	assert_true(FileAccess.file_exists(TEST_PATH + ".bad"), "The bad file is kept for inspection.")

func test_load_with_wrong_version_quarantines_the_file_and_resets():
	_write_raw(JSON.stringify({"version": 99, "meta": {"level": 6}}))
	assert_false(SaveManager.load_meta())
	assert_eq(MetaState.level, 1)
	assert_true(FileAccess.file_exists(TEST_PATH + ".bad"))

func test_load_with_non_dictionary_meta_quarantines_the_file_and_resets():
	_write_raw(JSON.stringify({"version": 1, "meta": [1, 2, 3]}))
	assert_false(SaveManager.load_meta())
	assert_eq(MetaState.level, 1)
	assert_true(FileAccess.file_exists(TEST_PATH + ".bad"))

func test_quarantine_overwrites_a_previous_bad_file():
	_write_raw("first bad")
	SaveManager.load_meta()
	_write_raw("second bad")
	SaveManager.load_meta()
	var bad := FileAccess.open(TEST_PATH + ".bad", FileAccess.READ)
	var text := bad.get_as_text()
	bad.close()
	assert_eq(text, "second bad")

func test_delete_save_removes_the_file_and_is_safe_when_missing():
	SaveManager.save_meta()
	assert_true(FileAccess.file_exists(TEST_PATH))
	SaveManager.delete_save()
	assert_false(FileAccess.file_exists(TEST_PATH))
	SaveManager.delete_save()
	assert_false(FileAccess.file_exists(TEST_PATH))
