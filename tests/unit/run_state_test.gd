extends GutTest
class_name RunStateTest

# Base class for every test that touches RunState. From Plan 3A on,
# RunState writes level/XP/skills through to MetaState and saves to disk,
# so without this reset one test's unlock would leak into the next test's
# start_new_run() — and hit the real user://save.json.

const TEST_SAVE_PATH := "user://test_save.json"

func before_each() -> void:
	SaveManager.save_path = TEST_SAVE_PATH
	SaveManager.delete_save()
	SaveManager.run_snapshot = null
	MetaState.reset()
