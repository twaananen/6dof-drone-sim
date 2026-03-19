extends "res://addons/gut/test.gd"

const RawControllerState = preload("res://scripts/telemetry/raw_controller_state.gd")

var _test_port_base: int = 40000 + randi() % 10000


func _assign_test_ports(pc_main: Node) -> void:
	_test_port_base += 10
	pc_main.get_node("TelemetryReceiver").listen_port = _test_port_base
	pc_main.get_node("ControlServer").listen_port = _test_port_base + 1
	pc_main.get_node("InspectServer").listen_port = _test_port_base + 2


func test_pc_main_scene_wraps_left_column_in_scroll_container() -> void:
	var scene: PackedScene = load("res://scenes/pc_main.tscn")
	assert_not_null(scene)

	var pc_main := scene.instantiate()
	assert_not_null(pc_main.get_node("VBox/MainSplit/LeftColumnScroll"))
	assert_not_null(pc_main.get_node("VBox/MainSplit/LeftColumnScroll/LeftColumn/WorkflowEditorPanel"))
	assert_not_null(pc_main.get_node("VBox/MainSplit/LeftColumnScroll/LeftColumn/WorkflowRunPanel"))
	assert_not_null(pc_main.get_node("VBox/MainSplit/LeftColumnScroll/LeftColumn/TemplateEditor"))
	assert_not_null(pc_main.get_node("VBox/MainSplit/LeftColumnScroll/LeftColumn/TemplateEditor/VBox/Tabs/Library"))
	assert_not_null(pc_main.get_node("VBox/MainSplit/LeftColumnScroll/LeftColumn/TemplateEditor/VBox/Tabs/Library/Margin/VBox/Filters/SchemeFilterSelect"))
	assert_not_null(pc_main.get_node("VBox/MainSplit/LeftColumnScroll/LeftColumn/TemplateEditor/VBox/Tabs/Library/Margin/VBox/Filters/DifficultyFilterSelect"))
	assert_not_null(pc_main.get_node("VBox/MainSplit/LeftColumnScroll/LeftColumn/TemplateEditor/VBox/Tabs/Guide"))
	assert_not_null(pc_main.get_node("VBox/MainSplit/LeftColumnScroll/LeftColumn/TemplateEditor/VBox/Tabs/Editor"))
	assert_not_null(pc_main.get_node("VBox/MainSplit/LeftColumnScroll/LeftColumn/TemplateEditor/VBox/Tabs/AdvancedJson"))

	pc_main.free()


func test_pc_runtime_pauses_motion_outputs_but_preserves_aux_button_when_control_inactive() -> void:
	var scene: PackedScene = load("res://scenes/pc_main.tscn")
	assert_not_null(scene)

	var pc_main := scene.instantiate()
	_assign_test_ports(pc_main)
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
	assert_eq(pc_main._build_status_payload()["output_summary"]["aux_button_1"], 1.0)


func test_pc_runtime_ignores_origin_capture_when_tracking_is_invalid() -> void:
	var scene: PackedScene = load("res://scenes/pc_main.tscn")
	assert_not_null(scene)

	var pc_main := scene.instantiate()
	_assign_test_ports(pc_main)
	add_child_autofree(pc_main)
	await wait_process_frames(1)

	var state := RawControllerState.default_state()
	state["tracking_valid"] = false
	state["event_flags"] = RawControllerState.EVENT_SET_ORIGIN
	state["grip_position"] = Vector3(2.0, 3.0, 4.0)

	pc_main._on_state_received(state)

	assert_false(pc_main._source_deriver.calibration.is_calibrated())


func test_pc_status_payload_uses_cached_template_summary_and_serialized_template() -> void:
	var scene: PackedScene = load("res://scenes/pc_main.tscn")
	assert_not_null(scene)

	var pc_main := scene.instantiate()
	_assign_test_ports(pc_main)
	add_child_autofree(pc_main)
	await wait_process_frames(1)

	assert_false(pc_main._active_template_summary_cache.is_empty())
	assert_false(pc_main._active_template_payload_cache.is_empty())

	var payload: Dictionary = pc_main._build_status_payload()
	assert_eq(payload["template_summary"], pc_main._active_template_summary_cache)
	assert_eq(payload["template"], pc_main._active_template_payload_cache)
