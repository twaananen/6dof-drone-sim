extends "res://addons/gut/test.gd"

const QuestSessionController = preload("res://scripts/quest/quest_session_controller.gd")
const SessionProfile = preload("res://scripts/workflow/session_profile.gd")


class FakeControlClient:
	extends Node

	var connected := true

	func is_socket_connected() -> bool:
		return connected


func test_session_controller_rebuilds_manual_checks_and_emits_snapshot_actions() -> void:
	var panel: Control = load("res://scenes/quest_session_panel.tscn").instantiate()
	var client := FakeControlClient.new()
	var controller := QuestSessionController.new()
	add_child_autofree(panel)
	add_child_autofree(client)
	add_child_autofree(controller)
	assert_true(controller.configure(panel, client))

	var profile := SessionProfile.new().to_dict()
	controller.apply_session_profile(profile)
	assert_gt(controller.checklist_box.get_child_count(), 0)

	controller.apply_pc_status({"session_diagnostics": {"severity": "ready"}})
	controller.snapshot_note_edit.text = "ready note"
	var messages: Array = []
	controller.control_message_requested.connect(func(message: Dictionary): messages.append(message))
	controller._on_capture_snapshot_pressed()

	assert_eq(messages.size(), 1)
	var message: Dictionary = messages[0]
	assert_eq(message["type"], "capture_run_snapshot")
	assert_eq(message["kind"], "ready")
