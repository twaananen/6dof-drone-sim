extends "res://addons/gut/test.gd"


func test_quest_main_scene_uses_spatial_ui_panel() -> void:
	var scene: PackedScene = load("res://scenes/quest_main.tscn")
	assert_not_null(scene)

	var quest_main := scene.instantiate()
	add_child_autofree(quest_main)
	await wait_process_frames(1)
	assert_null(quest_main.get_node_or_null("CanvasLayer"))
	assert_not_null(quest_main.get_node("XROrigin3D/UiPivot/QuestUiLayer"))
	assert_not_null(quest_main.get_node("XROrigin3D/RightHand/RightPointer"))
	assert_not_null(quest_main.get_node("XROrigin3D/LeftHand/LeftPointer"))
	assert_not_null(quest_main.get_node("XROrigin3D/UiPivot/QuestUiLayer/SubViewport/QuestPanel/Panel/Margin/Scroll/VBox/RunLabelEdit"))
	assert_not_null(quest_main.get_node("XROrigin3D/UiPivot/QuestUiLayer/SubViewport/QuestPanel/Panel/Margin/Scroll/VBox/ManualServerHostEdit"))
	assert_not_null(quest_main.get_node("XROrigin3D/UiPivot/QuestUiLayer/SubViewport/QuestPanel/Panel/Margin/Scroll/VBox/ConnectionButtons/RecenterPanelButton"))
