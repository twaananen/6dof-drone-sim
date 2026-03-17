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
	assert_not_null(quest_main.get_node("XROrigin3D/TutorialUiLayer"))
	assert_not_null(quest_main.get_node("XROrigin3D/RightOriginIndicator"))
	assert_not_null(quest_main.get_node("XROrigin3D/LeftAim/LeftPointer"))
	assert_not_null(quest_main.get_node("XROrigin3D/LeftAim/ControllerVisual"))
	assert_not_null(quest_main.get_node("XROrigin3D/RightHand/ControllerVisual"))
	assert_null(quest_main.get_node_or_null("XROrigin3D/RightAim/RightPointer"))
	assert_null(quest_main.get_node_or_null("Backdrop"))
	assert_not_null(quest_main.get_node("Floor"))
	assert_null(quest_main.get_node_or_null("Background"))
	assert_not_null(quest_main.get_node("XROrigin3D/QuestUiLayer/SubViewport/QuestPanel/Panel/Margin/Scroll/VBox/RunLabelEdit"))
	assert_not_null(quest_main.get_node("XROrigin3D/QuestUiLayer/SubViewport/QuestPanel/Panel/Margin/Scroll/VBox/ManualServerHostEdit"))
	assert_not_null(quest_main.get_node("XROrigin3D/QuestUiLayer/SubViewport/QuestPanel/Panel/Margin/Scroll/VBox/ConnectionButtons/RecenterPanelButton"))
	assert_not_null(quest_main.get_node("XROrigin3D/QuestUiLayer/SubViewport/QuestPanel/Panel/Margin/Scroll/VBox/ConnectionButtons/ShowTutorialButton"))
	assert_not_null(quest_main.get_node("XROrigin3D/QuestUiLayer/SubViewport/QuestPanel/Panel/Margin/Scroll/VBox/PassthroughToggle"))
	assert_not_null(quest_main.get_node("XROrigin3D/TutorialUiLayer/SubViewport/QuestTutorialPanel/Panel/Margin/Scroll/VBox/HideTutorialButton"))
	assert_true(_has_event("XR_INPUT_READER_READY"))
	assert_false(_has_event("XR_INPUT_READER_UNBOUND"))
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


func test_quest_main_builds_pose_log_fields_with_origin_displacement() -> void:
	var scene: PackedScene = load("res://scenes/quest_main.tscn")
	assert_not_null(scene)

	var quest_main := scene.instantiate()
	add_child_autofree(quest_main)
	await wait_process_frames(1)

	var state := {
		"tracking_valid": true,
		"control_active": true,
		"grip_position": Vector3(1.2, 1.5, -0.4),
		"grip_orientation": Basis.from_euler(Vector3(deg_to_rad(10.0), deg_to_rad(20.0), deg_to_rad(-5.0))).get_rotation_quaternion(),
	}
	var origin_transform := Transform3D(
		Basis.from_euler(Vector3(0.0, deg_to_rad(90.0), 0.0)),
		Vector3(1.0, 1.4, -0.8)
	)

	var fields: Dictionary = quest_main._build_pose_log_fields(state, origin_transform, true)

	assert_eq(fields["controller"], "RightHand")
	assert_true(fields["tracking_valid"])
	assert_true(fields["control_active"])
	assert_eq(fields["grip_position_x"], 1.2)
	assert_eq(fields["origin_position_x"], 1.0)
	assert_eq(fields["displacement_x"], 0.2)
	assert_eq(fields["displacement_y"], 0.1)
	assert_eq(fields["displacement_z"], 0.4)
	assert_eq(fields["displacement_local_x"], -0.4)
	assert_eq(fields["displacement_local_y"], 0.1)
	assert_eq(fields["displacement_local_z"], 0.2)
	assert_almost_eq(fields["displacement_magnitude"], 0.458, 0.001)
	assert_almost_eq(fields["displacement_xz_magnitude"], 0.447, 0.001)


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


func test_clear_origin_hides_indicator_until_release() -> void:
	var scene: PackedScene = load("res://scenes/quest_main.tscn")
	assert_not_null(scene)

	var quest_main := scene.instantiate()
	add_child_autofree(quest_main)
	await wait_process_frames(1)

	quest_main._sync_flight_origin_indicator({
		"control_active": true,
		"event_flags": RawControllerState.EVENT_SET_ORIGIN,
	})
	assert_true(quest_main.right_origin_indicator.visible)

	quest_main._sync_flight_origin_indicator({
		"control_active": true,
		"event_flags": RawControllerState.EVENT_CLEAR_ORIGIN,
	})
	assert_false(quest_main.right_origin_indicator.visible)

	quest_main._sync_flight_origin_indicator({
		"control_active": true,
		"event_flags": 0,
	})
	assert_false(quest_main.right_origin_indicator.visible)

	quest_main._sync_flight_origin_indicator({
		"control_active": false,
		"event_flags": 0,
	})
	quest_main._sync_flight_origin_indicator({
		"control_active": true,
		"event_flags": RawControllerState.EVENT_SET_ORIGIN,
	})
	assert_true(quest_main.right_origin_indicator.visible)
