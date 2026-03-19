extends "res://addons/gut/test.gd"

const QuestConnectionController = preload("res://scripts/quest/quest_connection_controller.gd")


class FakeControlClient:
	extends Node

	var server_host := ""
	var server_port := 0
	var connected := false

	func set_server_host(host: String, port: int) -> void:
		server_host = host
		server_port = port

	func disconnect_from_server(_immediate := false) -> void:
		connected = false

	func get_diagnostics() -> Dictionary:
		return {"socket_connected": connected}

	func get_connection_state() -> String:
		return "connected" if connected else "unconfigured"

	func is_socket_connected() -> bool:
		return connected


class FakeTelemetrySender:
	extends Node

	var target_host := ""
	var target_port := 0

	func set_target_host(host: String, port: int) -> void:
		target_host = host
		target_port = port

	func clear_target() -> void:
		target_host = ""
		target_port = 0

	func get_diagnostics() -> Dictionary:
		return {"telemetry_packets_sent": 0, "telemetry_send_errors": 0}


class FakeDiscoveryListener:
	extends Node

	var bind_error := OK

	func get_bind_error() -> int:
		return bind_error

	func get_diagnostics() -> Dictionary:
		return {"discovery_packets_received": 0, "discovery_invalid_packets": 0}


func test_connection_controller_applies_manual_host_and_auto_discovery_wait_state() -> void:
	var panel: Control = load("res://scenes/quest_connection_panel.tscn").instantiate()
	var control_client := FakeControlClient.new()
	var telemetry_sender := FakeTelemetrySender.new()
	var discovery_listener := FakeDiscoveryListener.new()
	var controller := QuestConnectionController.new()
	add_child_autofree(panel)
	add_child_autofree(control_client)
	add_child_autofree(telemetry_sender)
	add_child_autofree(discovery_listener)
	add_child_autofree(controller)
	assert_true(controller.configure(control_client, telemetry_sender, discovery_listener, panel))

	controller.connect_mode_select.select(1)
	controller.manual_server_host_edit.text = "192.168.1.55"
	controller._on_connect_mode_selected(1)
	controller._on_apply_connection_pressed()
	assert_eq(control_client.server_host, "192.168.1.55")
	assert_eq(telemetry_sender.target_host, "192.168.1.55")

	controller.connect_mode_select.select(0)
	controller._on_connect_mode_selected(0)
	assert_eq(controller.get_connection_state_snapshot()["state"], "waiting_for_beacon")
