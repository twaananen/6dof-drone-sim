extends "res://addons/gut/test.gd"

const RawControllerState = preload("res://scripts/telemetry/raw_controller_state.gd")


func test_pc_main_scene_wraps_left_column_in_scroll_container() -> void:
	var scene: PackedScene = load("res://scenes/pc_main.tscn")
	assert_not_null(scene)

	var pc_main := scene.instantiate()
	assert_not_null(pc_main.get_node("VBox/MainSplit/LeftColumnScroll"))
	assert_not_null(pc_main.get_node("VBox/MainSplit/LeftColumnScroll/LeftColumn/WorkflowEditorPanel"))
	assert_not_null(pc_main.get_node("VBox/MainSplit/LeftColumnScroll/LeftColumn/WorkflowRunPanel"))
	assert_not_null(pc_main.get_node("VBox/MainSplit/LeftColumnScroll/LeftColumn/TemplateEditor"))

	pc_main.free()


func test_pc_runtime_pauses_motion_outputs_but_preserves_aux_button_when_control_inactive() -> void:
	var scene: PackedScene = load("res://scenes/pc_main.tscn")
	assert_not_null(scene)

	var pc_main := scene.instantiate()
	add_child_autofree(pc_main)
	await wait_process_frames(1)

	var state := RawControllerState.default_state()
	state["tracking_valid"] = true
	state["control_active"] = false
	state["buttons"] = RawControllerState.BUTTON_SOUTH
	state["trigger"] = 1.0
	state["grip_orientation"] = Basis.from_euler(Vector3(deg_to_rad(20.0), deg_to_rad(35.0), deg_to_rad(15.0))).get_rotation_quaternion()

	pc_main._on_state_received(state)

	assert_eq(pc_main._last_outputs["throttle"], 0.0)
	assert_eq(pc_main._last_outputs["yaw"], 0.0)
	assert_eq(pc_main._last_outputs["pitch"], 0.0)
	assert_eq(pc_main._last_outputs["roll"], 0.0)
	assert_eq(pc_main._last_outputs["aux_button_1"], 1.0)
