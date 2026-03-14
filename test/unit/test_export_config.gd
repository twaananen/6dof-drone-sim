extends "res://addons/gut/test.gd"


func test_export_presets_commits_required_quest_flags() -> void:
	var export_text := FileAccess.get_file_as_string("res://export_presets.cfg")

	assert_string_contains(export_text, "gradle_build/use_gradle_build=true")
	assert_string_contains(export_text, "xr_features/xr_mode=1")
	assert_string_contains(export_text, "screen/immersive_mode=true")
	assert_string_contains(export_text, "permissions/internet=true")
	assert_string_contains(export_text, "permissions/change_wifi_multicast_state=true")
	assert_string_contains(export_text, "xr_features/enable_meta_plugin=true")
	assert_string_contains(export_text, "meta_xr_features/passthrough=2")
	assert_string_contains(export_text, "meta_xr_features/render_model=2")


func test_project_settings_commit_required_openxr_flags() -> void:
	var project_text := FileAccess.get_file_as_string("res://project.godot")

	assert_string_contains(project_text, "openxr/enabled.android=true")
	assert_string_contains(project_text, "openxr/default_action_map=\"res://openxr_action_map.tres\"")
	assert_string_contains(project_text, "openxr/extensions/meta/passthrough=true")
	assert_string_contains(project_text, "openxr/extensions/meta/render_model=true")
