class_name PanelPositionStore
extends RefCounted

const DEFAULT_PATH := "user://ui/panel_positions.json"

var store_path: String = DEFAULT_PATH


func _init(path: String = DEFAULT_PATH) -> void:
	store_path = path


func load_offsets(panel_key: String) -> Variant:
	var data := _load_all()
	if data.has(panel_key) and typeof(data[panel_key]) == TYPE_DICTIONARY:
		return data[panel_key]
	return null


func save_offsets(panel_key: String, offsets: Dictionary) -> Error:
	var data := _load_all()
	data[panel_key] = offsets
	return _save_all(data)


func clear_offsets(panel_key: String) -> Error:
	var data := _load_all()
	if data.has(panel_key):
		data.erase(panel_key)
		return _save_all(data)
	return OK


func _load_all() -> Dictionary:
	if not FileAccess.file_exists(store_path):
		return {}
	var file := FileAccess.open(store_path, FileAccess.READ)
	if file == null:
		return {}
	var text := file.get_as_text()
	file.close()
	var json := JSON.new()
	if json.parse(text) != OK or typeof(json.data) != TYPE_DICTIONARY:
		return {}
	return json.data


func _save_all(data: Dictionary) -> Error:
	_ensure_parent_dir()
	var file := FileAccess.open(store_path, FileAccess.WRITE)
	if file == null:
		return FileAccess.get_open_error()
	file.store_string(JSON.stringify(data, "\t"))
	file.close()
	return OK


func _ensure_parent_dir() -> void:
	var parent_dir := store_path.get_base_dir()
	if parent_dir.is_empty():
		return
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(parent_dir))
