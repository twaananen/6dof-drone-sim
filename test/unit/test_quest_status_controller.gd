extends "res://addons/gut/test.gd"

const QuestStatusController = preload("res://scripts/quest/quest_status_controller.gd")


class FakeControlClient:
	extends Node

	var connected := true

	func is_socket_connected() -> bool:
		return connected

	func get_connection_state() -> String:
		return "connected" if connected else "unconfigured"


class FakeConnectionController:
	extends Node

	func get_runtime_diagnostics() -> Dictionary:
		return {
			"connection_mode": "manual",
			"manual_server_host": "192.168.1.55",
			"discovery_state": "tcp_connected",
			"control_target_host": "192.168.1.55",
		}


class FakeXrController:
	extends Node

	func get_diagnostics() -> Dictionary:
		return {
			"state": "xr_ready",
			"passthrough_enabled": true,
			"display_refresh_rate": 90.0,
		}


class FakeFlightRuntimeController:
	extends Node

	func get_runtime_diagnostics() -> Dictionary:
		return {
			"control_active": true,
			"tracking_valid": true,
			"right_grip_value": 0.7,
			"right_trigger_value": 0.8,
			"right_buttons_hex": "0x0001",
			"right_button_south_pressed": true,
			"right_thumbstick_x": 0.25,
			"right_thumbstick_y": -0.5,
			"last_origin_event": "set",
		}


class FakeTemplateController:
	extends Node

	func get_active_template_id() -> String:
		return "bundled.attitude_tilt"

	func get_active_template_summary() -> Dictionary:
		return {"display_name": "Attitude Tilt"}


class FakePanelController:
	extends Node

	func is_tutorial_visible() -> bool:
		return false


func test_status_controller_renders_labels_and_emits_diagnostics_messages() -> void:
	var flight_panel: Control = load("res://scenes/quest_flight_panel.tscn").instantiate()
	var connection_panel: Control = load("res://scenes/quest_connection_panel.tscn").instantiate()
	var session_panel: Control = load("res://scenes/quest_session_panel.tscn").instantiate()
	var controller := QuestStatusController.new()
	var control_client := FakeControlClient.new()
	var connection_controller := FakeConnectionController.new()
	var xr_controller := FakeXrController.new()
	var flight_runtime_controller := FakeFlightRuntimeController.new()
	var template_controller := FakeTemplateController.new()
	var session_controller := Node.new()
	var panel_controller := FakePanelController.new()
	add_child_autofree(flight_panel)
	add_child_autofree(connection_panel)
	add_child_autofree(session_panel)
	add_child_autofree(control_client)
	add_child_autofree(connection_controller)
	add_child_autofree(xr_controller)
	add_child_autofree(flight_runtime_controller)
	add_child_autofree(template_controller)
	add_child_autofree(session_controller)
	add_child_autofree(panel_controller)
	add_child_autofree(controller)
	controller.configure(
		flight_panel,
		connection_panel,
		session_panel,
		control_client,
		connection_controller,
		xr_controller,
		flight_runtime_controller,
		template_controller,
		session_controller,
		panel_controller
	)
	controller.apply_session_profile({
		"mode_label": "Passthrough Standalone",
		"preset_label": "Baseline",
	})
	controller.apply_pc_status({
		"output_summary": {"throttle": 0.5, "yaw": 0.2, "pitch": -0.3, "roll": 0.1, "aux_button_1": 1.0},
		"backend_available": true,
	})
	controller.refresh_all()
	assert_string_contains(controller._status_label.text, "Template: Attitude Tilt")
	assert_string_contains(controller._output_preview_label.text, "Outputs: T 0.50")

	var messages: Array = []
	controller.control_message_requested.connect(func(message: Dictionary): messages.append(message))
	controller._push_runtime_diagnostics(true)
	assert_eq(messages.size(), 1)
	assert_eq(messages[0]["type"], "quest_diagnostics")

	control_client.connected = false
	controller._push_runtime_diagnostics(true)
	assert_eq(messages.size(), 2)
	assert_eq(messages[1]["type"], "quest_diagnostics")
