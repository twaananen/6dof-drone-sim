extends "res://addons/gut/test.gd"


func test_pc_main_scene_wraps_left_column_in_scroll_container() -> void:
	var scene: PackedScene = load("res://scenes/pc_main.tscn")
	assert_not_null(scene)

	var pc_main := scene.instantiate()
	assert_not_null(pc_main.get_node("VBox/MainSplit/LeftColumnScroll"))
	assert_not_null(pc_main.get_node("VBox/MainSplit/LeftColumnScroll/LeftColumn/WorkflowEditorPanel"))
	assert_not_null(pc_main.get_node("VBox/MainSplit/LeftColumnScroll/LeftColumn/WorkflowRunPanel"))
	assert_not_null(pc_main.get_node("VBox/MainSplit/LeftColumnScroll/LeftColumn/TemplateEditor"))

	pc_main.free()
