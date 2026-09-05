extends Node

# Autoload singleton, registered in project.godot as "SaveManager".
# Writes one versioned JSON file holding the persistent character (meta)
# and, while a run is suspended, its snapshot (run). Never crashes on a bad
# file: it is renamed to "<save_path>.bad" and a fresh character is used.
# No class_name, same rule as RunState.

const SAVE_VERSION := 2
const OLDEST_READABLE_VERSION := 1
const DEFAULT_SAVE_PATH := "user://save.json"

var save_path: String = DEFAULT_SAVE_PATH
# The latest run snapshot (RunSnapshot.capture()), or null when no run is
# suspended. RunState refreshes it at its checkpoints; save_game() writes it.
var run_snapshot: Variant = null

func save_game() -> bool:
	var payload: Dictionary = {
		"version": SAVE_VERSION,
		"meta": MetaState.to_dict(),
		"run": run_snapshot,
	}
	var file := FileAccess.open(save_path, FileAccess.WRITE)
	if file == null:
		push_warning("SaveManager: cannot write %s (%s)" % [save_path, error_string(FileAccess.get_open_error())])
		return false
	file.store_string(JSON.stringify(payload, "\t"))
	file.close()
	return true

func load_game() -> bool:
	if not FileAccess.file_exists(save_path):
		MetaState.reset()
		run_snapshot = null
		return false
	var file := FileAccess.open(save_path, FileAccess.READ)
	if file == null:
		push_warning("SaveManager: cannot read %s (%s)" % [save_path, error_string(FileAccess.get_open_error())])
		MetaState.reset()
		run_snapshot = null
		return false
	var text: String = file.get_as_text()
	file.close()
	# JSON.parse() reports malformed input as a return code; JSON.parse_string()
	# would also log an engine error, which is noise for a file we quarantine anyway.
	var json := JSON.new()
	if json.parse(text) == OK and json.data is Dictionary:
		var data: Dictionary = json.data
		var version: int = int(data.get("version", -1))
		var meta: Variant = data.get("meta", null)
		if version >= OLDEST_READABLE_VERSION and version <= SAVE_VERSION and meta is Dictionary:
			MetaState.from_dict(meta)
			var raw_run: Variant = data.get("run", null)
			if raw_run == null or raw_run is Dictionary:
				run_snapshot = raw_run
			else:
				push_warning("SaveManager: run section of %s is unreadable; suspended run discarded" % save_path)
				run_snapshot = null
			return true
	_quarantine_bad_save()
	MetaState.reset()
	run_snapshot = null
	return false

func has_run_snapshot() -> bool:
	return run_snapshot is Dictionary

func delete_save() -> void:
	run_snapshot = null
	if FileAccess.file_exists(save_path):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(save_path))

func _quarantine_bad_save() -> void:
	var bad_path: String = save_path + ".bad"
	if FileAccess.file_exists(bad_path):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(bad_path))
	DirAccess.rename_absolute(ProjectSettings.globalize_path(save_path), ProjectSettings.globalize_path(bad_path))
	push_warning("SaveManager: %s was unreadable or out of date; moved to %s and starting fresh" % [save_path, bad_path])
