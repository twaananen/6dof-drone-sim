extends "res://addons/gut/test.gd"


func before_each() -> void:
	_logger().clear_entries()


func test_quest_main_scene_uses_spatial_ui_panel() -> void:
	var scene: PackedScene = load("res://scenes/quest_main.tscn")
	assert_not_null(scene)

	var quest_main := scene.instantiate()
	add_child_autofree(quest_main)
	await wait_process_frames(1)
	assert_null(quest_main.get_node_or_null("CanvasLayer"))
	assert_not_null(quest_main.get_node("XROrigin3D/QuestUiLayer"))
	assert_not_null(quest_main.get_node("XROrigin3D/RightAim/RightPointer"))
	assert_not_null(quest_main.get_node("XROrigin3D/LeftAim/LeftPointer"))
	assert_null(quest_main.get_node_or_null("Backdrop"))
	assert_not_null(quest_main.get_node("Floor"))
	assert_null(quest_main.get_node_or_null("Background"))
	assert_not_null(quest_main.get_node("XROrigin3D/QuestUiLayer/SubViewport/QuestPanel/Panel/Margin/Scroll/VBox/RunLabelEdit"))
	assert_not_null(quest_main.get_node("XROrigin3D/QuestUiLayer/SubViewport/QuestPanel/Panel/Margin/Scroll/VBox/ManualServerHostEdit"))
	assert_not_null(quest_main.get_node("XROrigin3D/QuestUiLayer/SubViewport/QuestPanel/Panel/Margin/Scroll/VBox/ConnectionButtons/RecenterPanelButton"))
	assert_not_null(quest_main.get_node("XROrigin3D/QuestUiLayer/SubViewport/QuestPanel/Panel/Margin/Scroll/VBox/PassthroughToggle"))
	assert_true(_has_boot_phase("READY_BEGIN"))
	assert_true(_has_boot_phase("UI_BIND_OK"))
	assert_true(_has_boot_phase("UI_SIGNALS_BOUND"))
	assert_true(_has_boot_phase("XR_INIT_BEGIN"))
	assert_true(_has_boot_phase("CONTROLLER_VISUALS_UPDATED"))
	if _has_boot_phase("XR_INIT_OK"):
		assert_true(_has_event("XR_OPAQUE_BASELINE_APPLIED"))
		assert_true(_has_boot_phase("UI_PANEL_RECENTERED") or _has_boot_phase("UI_PANEL_RECENTER_DEFERRED"))
	assert_true(_has_boot_phase("PASSTHROUGH_TOGGLE_SYNCED"))
	assert_true(_has_boot_phase("READY_COMPLETE"))


func _has_boot_phase(phase_name: String) -> bool:
	for entry in _logger().get_entries():
		if str(entry.get("event", "")) == "BOOT" and str(entry.get("phase", "")) == phase_name:
			return true
	return false


func _has_event(event_name: String) -> bool:
	for entry in _logger().get_entries():
		if str(entry.get("event", "")) == event_name:
			return true
	return false


func _logger() -> Node:
	return get_tree().root.get_node("QuestRuntimeLog")
