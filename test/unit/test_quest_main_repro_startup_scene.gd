extends "res://addons/gut/test.gd"


func before_each() -> void:
	_logger().clear_entries()


func test_quest_main_repro_startup_scene_binds_real_panel_with_quest_main_script() -> void:
	var scene: PackedScene = load("res://scenes/repro/quest_main_repro_startup.tscn")
	assert_not_null(scene)

	var repro := scene.instantiate()
	add_child_autofree(repro)
	await wait_process_frames(1)

	assert_not_null(repro.get_node("XROrigin3D/QuestUiLayer/SubViewport/QuestFlightPanel/Panel/Margin/Scroll/VBox/PassthroughToggle"))
	assert_true(_has_event("XR_INPUT_READER_READY"))
	assert_false(_has_event("XR_INPUT_READER_UNBOUND"))
	assert_true(_has_boot_phase("READY_BEGIN"))
	assert_true(_has_boot_phase("UI_BIND_OK"))
	assert_true(_has_boot_phase("XR_INIT_BEGIN"))
	assert_true(_has_boot_phase("CONTROLLER_VISUALS_UPDATED"))
	if _has_boot_phase("XR_INIT_OK"):
		assert_true(_has_event("XR_OPAQUE_BASELINE_APPLIED"))
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
