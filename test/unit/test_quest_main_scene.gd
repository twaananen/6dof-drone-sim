extends "res://addons/gut/test.gd"


func test_quest_main_scene_exposes_session_detail_controls() -> void:
	var scene: PackedScene = load("res://scenes/quest_main.tscn")
	assert_not_null(scene)

	var quest_main := scene.instantiate()
	assert_not_null(quest_main.get_node("CanvasLayer/Panel/VBox/RunLabelEdit"))
	assert_not_null(quest_main.get_node("CanvasLayer/Panel/VBox/LatencyBudgetSpin"))
	assert_not_null(quest_main.get_node("CanvasLayer/Panel/VBox/ObservedLatencySpin"))
	assert_not_null(quest_main.get_node("CanvasLayer/Panel/VBox/FocusLossSpin"))
	assert_not_null(quest_main.get_node("CanvasLayer/Panel/VBox/OperatorNoteEdit"))
	assert_not_null(quest_main.get_node("CanvasLayer/Panel/VBox/ApplySessionDetailsButton"))
	assert_not_null(quest_main.get_node("CanvasLayer/Panel/VBox/SnapshotNoteEdit"))

	quest_main.free()
