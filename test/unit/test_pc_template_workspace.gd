extends "res://addons/gut/test.gd"


func test_template_workspace_prioritizes_editor_width_and_clips_overview() -> void:
	var scene: PackedScene = load("res://scenes/shared/pc_template_workspace.tscn")
	assert_not_null(scene)

	var workspace = scene.instantiate()
	add_child_autofree(workspace)
	await wait_process_frames(2)

	var body_split := workspace.get_node("Margin/VBox/BodySplit")
	var library_panel := workspace.get_node("Margin/VBox/BodySplit/LibraryPanel") as Control
	var right_column := workspace.get_node("Margin/VBox/BodySplit/RightColumn") as Control
	var tabs := workspace.get_node("Margin/VBox/BodySplit/RightColumn/Tabs") as Control
	var guide_panel := workspace.get_node("Margin/VBox/BodySplit/RightColumn/Tabs/GuidePanel") as Control
	var guide_body := workspace.get_node("Margin/VBox/BodySplit/RightColumn/Tabs/GuidePanel/Margin/VBox/Body") as RichTextLabel

	assert_false(body_split is HSplitContainer)
	assert_eq(library_panel.custom_minimum_size.x, 220.0)
	assert_eq(right_column.size_flags_horizontal, Control.SIZE_EXPAND_FILL)
	assert_eq(tabs.size_flags_horizontal, Control.SIZE_EXPAND_FILL)
	assert_true(guide_panel.clip_contents)
	assert_true(guide_body.scroll_active)


func test_structured_editor_emits_template_changed_for_metadata_edits() -> void:
	var scene: PackedScene = load("res://scenes/shared/template_structured_editor.tscn")
	assert_not_null(scene)

	var editor = scene.instantiate()
	add_child_autofree(editor)
	await wait_process_frames(1)

	watch_signals(editor)

	editor.display_name_edit.text = "Updated Template"
	editor._on_meta_changed("Updated Template")

	assert_signal_emitted(editor, "template_changed")
