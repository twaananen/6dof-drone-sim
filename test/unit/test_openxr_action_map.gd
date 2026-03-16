extends "res://addons/gut/test.gd"


func test_action_map_supports_meta_touch_controller_plus() -> void:
	var action_map_text := FileAccess.get_file_as_string("res://openxr_action_map.tres")
	assert_false(action_map_text.is_empty())
	assert_true(action_map_text.contains("/interaction_profiles/meta/touch_controller_plus"))
