extends "res://addons/gut/test.gd"

const QuestFlightRuntimeController = preload("res://scripts/quest/quest_flight_runtime_controller.gd")


class FakeIndicator:
	extends Node3D

	func show_from_transform(new_transform: Transform3D) -> void:
		transform = new_transform
		visible = true

	func hide_indicator() -> void:
		visible = false

	func update_displacement(position: Vector3) -> void:
		global_position = position


class FakeReader:
	extends Node

	func read_state() -> Dictionary:
		return {}

	func request_set_origin() -> void:
		pass

	func request_clear_origin() -> void:
		pass


class FakeSender:
	extends Node

	func send_state(_state: Dictionary) -> void:
		pass


func test_build_pose_log_fields_and_origin_suppression_match_existing_behavior() -> void:
	var controller := QuestFlightRuntimeController.new()
	var reader := FakeReader.new()
	var sender := FakeSender.new()
	var right_hand := XRController3D.new()
	var indicator := FakeIndicator.new()
	add_child_autofree(reader)
	add_child_autofree(sender)
	add_child_autofree(right_hand)
	add_child_autofree(indicator)
	add_child_autofree(controller)
	controller.configure(reader, sender, right_hand, indicator)

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

	var fields := controller.build_pose_log_fields(state, origin_transform, true)
	assert_eq(fields["displacement_x"], 0.2)
	assert_eq(fields["displacement_y"], 0.1)
	assert_eq(fields["displacement_z"], 0.4)
	assert_eq(fields["displacement_local_x"], -0.4)
	assert_eq(fields["displacement_local_z"], 0.2)

	controller.sync_flight_origin_indicator({
		"control_active": true,
		"event_flags": RawControllerState.EVENT_SET_ORIGIN,
	})
	assert_true(indicator.visible)

	controller.sync_flight_origin_indicator({
		"control_active": true,
		"event_flags": RawControllerState.EVENT_CLEAR_ORIGIN,
	})
	assert_false(indicator.visible)

	controller.sync_flight_origin_indicator({
		"control_active": false,
		"event_flags": 0,
	})
	controller.sync_flight_origin_indicator({
		"control_active": true,
		"event_flags": RawControllerState.EVENT_SET_ORIGIN,
	})
	assert_true(indicator.visible)
