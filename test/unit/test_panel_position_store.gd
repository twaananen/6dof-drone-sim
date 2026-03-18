extends "res://addons/gut/test.gd"

const PanelPositionStore = preload("res://scripts/ui/panel_position_store.gd")

var _store_path: String = ""


func before_each() -> void:
	_store_path = "user://ui/test_panel_positions_%d.json" % Time.get_ticks_usec()


func after_each() -> void:
	if FileAccess.file_exists(_store_path):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(_store_path))


func test_returns_null_when_no_saved_position() -> void:
	var store := PanelPositionStore.new(_store_path)
	assert_null(store.load_offsets("quest_ui"))


func test_round_trips_offsets() -> void:
	var store := PanelPositionStore.new(_store_path)
	var offsets := {"x": 1.1, "y": -0.5, "z": 0.02}

	var result := store.save_offsets("quest_ui", offsets)
	var loaded = store.load_offsets("quest_ui")

	assert_eq(result, OK)
	assert_not_null(loaded)
	assert_almost_eq(float(loaded["x"]), 1.1, 0.001)
	assert_almost_eq(float(loaded["y"]), -0.5, 0.001)
	assert_almost_eq(float(loaded["z"]), 0.02, 0.001)


func test_multiple_panels_independent() -> void:
	var store := PanelPositionStore.new(_store_path)
	store.save_offsets("quest_ui", {"x": 1.0, "y": 0.0, "z": -0.1})
	store.save_offsets("tutorial", {"x": 0.8, "y": -0.5, "z": 0.05})

	var ui = store.load_offsets("quest_ui")
	var tut = store.load_offsets("tutorial")

	assert_almost_eq(float(ui["x"]), 1.0, 0.001)
	assert_almost_eq(float(tut["y"]), -0.5, 0.001)


func test_clear_removes_single_panel() -> void:
	var store := PanelPositionStore.new(_store_path)
	store.save_offsets("quest_ui", {"x": 1.0, "y": 0.0, "z": 0.0})
	store.save_offsets("tutorial", {"x": 0.8, "y": -0.5, "z": 0.0})

	store.clear_offsets("quest_ui")

	assert_null(store.load_offsets("quest_ui"))
	assert_not_null(store.load_offsets("tutorial"))


func test_clear_nonexistent_key_is_ok() -> void:
	var store := PanelPositionStore.new(_store_path)
	var result := store.clear_offsets("nonexistent")
	assert_eq(result, OK)


func test_handles_corrupt_json() -> void:
	var store := PanelPositionStore.new(_store_path)
	var parent_dir := _store_path.get_base_dir()
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(parent_dir))
	var file := FileAccess.open(_store_path, FileAccess.WRITE)
	file.store_string("not valid json {{{")
	file.close()

	assert_null(store.load_offsets("quest_ui"))
