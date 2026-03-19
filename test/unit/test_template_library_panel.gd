extends "res://addons/gut/test.gd"


func test_library_panel_filters_by_scheme_and_difficulty() -> void:
	var scene: PackedScene = load("res://scenes/shared/template_library_panel.tscn")
	assert_not_null(scene)

	var panel = scene.instantiate()
	add_child_autofree(panel)
	await wait_process_frames(1)

	panel.set_catalog([
		{
			"template_id": "bundled.attitude_tilt",
			"display_name": "Attitude Tilt",
			"summary": "Tilt",
			"origin": "bundled",
			"control_scheme": "absolute_attitude",
			"control_scheme_label": "Absolute Attitude",
			"difficulty": "beginner",
			"difficulty_label": "Beginner",
		},
		{
			"template_id": "bundled.rate_direct",
			"display_name": "Rate Direct",
			"summary": "Rate",
			"origin": "bundled",
			"control_scheme": "direct_rate",
			"control_scheme_label": "Direct Rate",
			"difficulty": "advanced",
			"difficulty_label": "Advanced",
		},
		{
			"template_id": "user.precision",
			"display_name": "Blend Precision",
			"summary": "Blend",
			"origin": "user",
			"control_scheme": "blended_precision",
			"control_scheme_label": "Blended Precision",
			"difficulty": "intermediate",
			"difficulty_label": "Intermediate",
		},
	])

	assert_eq(panel.list.item_count, 3)

	_select_by_metadata(panel.scheme_filter_select, "direct_rate")
	assert_eq(panel.list.item_count, 1)
	assert_eq(str(panel.list.get_item_metadata(0)), "bundled.rate_direct")

	_select_by_metadata(panel.scheme_filter_select, "")
	_select_by_metadata(panel.difficulty_filter_select, "intermediate")
	assert_eq(panel.list.item_count, 1)
	assert_eq(str(panel.list.get_item_metadata(0)), "user.precision")


func test_structured_editor_uses_canonical_labels() -> void:
	var scene: PackedScene = load("res://scenes/shared/template_structured_editor.tscn")
	assert_not_null(scene)

	var editor = scene.instantiate()
	add_child_autofree(editor)
	await wait_process_frames(1)

	assert_eq(_text_for_metadata(editor.control_scheme_select, "direct_rate"), "Direct Rate")
	assert_eq(_text_for_metadata(editor.difficulty_select, "intermediate"), "Intermediate")
	assert_eq(_text_for_metadata(editor.output_select, "throttle"), "Throttle")
	assert_eq(_text_for_metadata(editor.source_select, "swing_pitch_deg"), "forward/back hand tilt")


func _select_by_metadata(select: OptionButton, value: Variant) -> void:
	for index in range(select.item_count):
		if select.get_item_metadata(index) == value:
			select.select(index)
			select.item_selected.emit(index)
			return
	fail_test("Metadata not found: %s" % str(value))


func _text_for_metadata(select: OptionButton, value: Variant) -> String:
	for index in range(select.item_count):
		if select.get_item_metadata(index) == value:
			return select.get_item_text(index)
	return ""
