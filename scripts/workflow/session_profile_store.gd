class_name SessionProfileStore
extends RefCounted

const SessionProfile = preload("res://scripts/workflow/session_profile.gd")
const DEFAULT_PROFILE_PATH := "user://workflow/session_profile.json"

var profile_path: String = DEFAULT_PROFILE_PATH


func _init(next_profile_path: String = DEFAULT_PROFILE_PATH) -> void:
	profile_path = next_profile_path


func load_profile() -> SessionProfile:
	_ensure_parent_dir()
	var profile := SessionProfile.new()
	if not FileAccess.file_exists(profile_path):
		return profile

	var file := FileAccess.open(profile_path, FileAccess.READ)
	if file == null:
		return profile
	var text := file.get_as_text()
	file.close()

	var json := JSON.new()
	if json.parse(text) != OK or typeof(json.data) != TYPE_DICTIONARY:
		return profile

	profile.from_dict(json.data)
	return profile


func save_profile(profile: SessionProfile) -> Error:
	_ensure_parent_dir()
	var file := FileAccess.open(profile_path, FileAccess.WRITE)
	if file == null:
		return FileAccess.get_open_error()
	file.store_string(JSON.stringify(profile.to_dict(), "\t"))
	file.close()
	return OK


func _ensure_parent_dir() -> void:
	var parent_dir := profile_path.get_base_dir()
	if parent_dir.is_empty():
		return
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(parent_dir))
