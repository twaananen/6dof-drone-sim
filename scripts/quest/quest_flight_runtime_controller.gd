extends Node

signal local_state_updated(state)

const POSE_SNAPSHOT_INTERVAL_MSEC := 1000

var _controller_reader: Node
var _telemetry_sender: Node
var _right_hand: XRController3D
var _right_origin_indicator: Node3D
var _last_local_controller_state: Dictionary = {}
var _last_pose_snapshot_msec: int = 0
var _suppress_origin_indicator_until_release: bool = false


func configure(
	controller_reader: Node,
	telemetry_sender: Node,
	right_hand: XRController3D,
	right_origin_indicator: Node3D
) -> void:
	_controller_reader = controller_reader
	_telemetry_sender = telemetry_sender
	_right_hand = right_hand
	_right_origin_indicator = right_origin_indicator
	set_physics_process(_controller_reader != null and _telemetry_sender != null)


func bind_flight_controls(calibrate_button: Button, recenter_button: Button) -> bool:
	if calibrate_button == null or recenter_button == null:
		return false
	calibrate_button.pressed.connect(request_set_origin)
	recenter_button.pressed.connect(request_clear_origin)
	return true


func request_set_origin() -> void:
	if _controller_reader != null:
		_controller_reader.request_set_origin()


func request_clear_origin() -> void:
	if _controller_reader != null:
		_controller_reader.request_clear_origin()


func get_last_local_state() -> Dictionary:
	return _last_local_controller_state.duplicate(true)


func get_runtime_diagnostics() -> Dictionary:
	var diagnostics := {
		"control_active": bool(_last_local_controller_state.get("control_active", false)),
		"tracking_valid": bool(_last_local_controller_state.get("tracking_valid", false)),
		"right_trigger_value": float(_last_local_controller_state.get("trigger", 0.0)),
		"right_grip_value": float(_last_local_controller_state.get("grip", 0.0)),
		"origin_indicator_visible": _right_origin_indicator.visible if _right_origin_indicator != null else false,
		"last_origin_event": _describe_origin_event(int(_last_local_controller_state.get("event_flags", 0))),
	}
	var buttons := int(_last_local_controller_state.get("buttons", 0))
	diagnostics["right_buttons"] = buttons
	diagnostics["right_buttons_hex"] = "0x%04X" % buttons
	diagnostics["right_button_south_pressed"] = RawControllerState.button_pressed(
		buttons,
		RawControllerState.BUTTON_SOUTH
	)
	var thumbstick: Vector2 = _last_local_controller_state.get("thumbstick", Vector2.ZERO)
	diagnostics["right_thumbstick_x"] = float(thumbstick.x)
	diagnostics["right_thumbstick_y"] = float(thumbstick.y)
	return diagnostics


func sync_flight_origin_indicator(state: Dictionary) -> void:
	if _right_origin_indicator == null or _right_hand == null:
		return
	var control_active := bool(state.get("control_active", false))
	if state.get("event_flags", 0) & RawControllerState.EVENT_SET_ORIGIN:
		_suppress_origin_indicator_until_release = false
		_right_origin_indicator.call("show_from_transform", _right_hand.global_transform)
		_log_info("XR_FLIGHT_ORIGIN_ANCHOR", _build_origin_anchor_fields(_right_origin_indicator.transform))
	elif state.get("event_flags", 0) & RawControllerState.EVENT_CLEAR_ORIGIN:
		_suppress_origin_indicator_until_release = true
		_right_origin_indicator.call("hide_indicator")

	if not control_active:
		_suppress_origin_indicator_until_release = false
		if _right_origin_indicator.visible:
			_right_origin_indicator.call("hide_indicator")
		return

	if _suppress_origin_indicator_until_release:
		if _right_origin_indicator.visible:
			_right_origin_indicator.call("hide_indicator")
		return

	if not _right_origin_indicator.visible:
		_right_origin_indicator.call("show_from_transform", _right_hand.global_transform)
	_right_origin_indicator.call("update_displacement", _right_hand.global_position)


func build_pose_log_fields(
	state: Dictionary,
	origin_transform: Transform3D,
	origin_visible: bool
) -> Dictionary:
	var grip_position: Vector3 = state.get("grip_position", Vector3.ZERO)
	var grip_orientation: Quaternion = state.get("grip_orientation", Quaternion.IDENTITY)
	var grip_euler_deg := _quaternion_to_euler_deg(grip_orientation)
	var fields := {
		"controller": "RightHand",
		"tracking_valid": bool(state.get("tracking_valid", false)),
		"control_active": bool(state.get("control_active", false)),
		"grip_position_x": snappedf(grip_position.x, 0.001),
		"grip_position_y": snappedf(grip_position.y, 0.001),
		"grip_position_z": snappedf(grip_position.z, 0.001),
		"grip_pitch_deg": snappedf(grip_euler_deg.x, 0.1),
		"grip_yaw_deg": snappedf(grip_euler_deg.y, 0.1),
		"grip_roll_deg": snappedf(grip_euler_deg.z, 0.1),
		"origin_visible": origin_visible,
	}
	if not origin_visible:
		return fields
	var origin_position := origin_transform.origin
	var displacement := grip_position - origin_position
	var local_displacement := origin_transform.basis.inverse() * displacement
	fields["origin_position_x"] = snappedf(origin_position.x, 0.001)
	fields["origin_position_y"] = snappedf(origin_position.y, 0.001)
	fields["origin_position_z"] = snappedf(origin_position.z, 0.001)
	fields["displacement_x"] = snappedf(displacement.x, 0.001)
	fields["displacement_y"] = snappedf(displacement.y, 0.001)
	fields["displacement_z"] = snappedf(displacement.z, 0.001)
	fields["displacement_local_x"] = snappedf(local_displacement.x, 0.001)
	fields["displacement_local_y"] = snappedf(local_displacement.y, 0.001)
	fields["displacement_local_z"] = snappedf(local_displacement.z, 0.001)
	fields["displacement_magnitude"] = snappedf(displacement.length(), 0.001)
	fields["displacement_xz_magnitude"] = snappedf(Vector2(displacement.x, displacement.z).length(), 0.001)
	return fields


func _physics_process(_delta: float) -> void:
	if _controller_reader == null or _telemetry_sender == null:
		return
	var state: Dictionary = _controller_reader.read_state()
	_last_local_controller_state = state.duplicate(true)
	_telemetry_sender.send_state(state)
	sync_flight_origin_indicator(state)
	_maybe_log_pose_snapshot(state)
	local_state_updated.emit(_last_local_controller_state)


func _maybe_log_pose_snapshot(state: Dictionary) -> void:
	if not bool(state.get("tracking_valid", false)):
		return
	var now_msec := Time.get_ticks_msec()
	if now_msec - _last_pose_snapshot_msec < POSE_SNAPSHOT_INTERVAL_MSEC:
		return
	_last_pose_snapshot_msec = now_msec
	var origin_transform := Transform3D.IDENTITY
	var origin_visible := _right_origin_indicator != null and _right_origin_indicator.visible
	if origin_visible:
		origin_transform = _right_origin_indicator.transform
	_log_info("XR_POSE_SNAPSHOT", build_pose_log_fields(state, origin_transform, origin_visible))


func _build_origin_anchor_fields(origin_transform: Transform3D) -> Dictionary:
	var origin_euler_deg := _quaternion_to_euler_deg(origin_transform.basis.get_rotation_quaternion())
	return {
		"controller": "RightHand",
		"origin_position_x": snappedf(origin_transform.origin.x, 0.001),
		"origin_position_y": snappedf(origin_transform.origin.y, 0.001),
		"origin_position_z": snappedf(origin_transform.origin.z, 0.001),
		"origin_pitch_deg": snappedf(origin_euler_deg.x, 0.1),
		"origin_yaw_deg": snappedf(origin_euler_deg.y, 0.1),
		"origin_roll_deg": snappedf(origin_euler_deg.z, 0.1),
	}


func _quaternion_to_euler_deg(rotation: Quaternion) -> Vector3:
	var euler := Basis(rotation).get_euler(EULER_ORDER_YXZ)
	return Vector3(rad_to_deg(euler.x), rad_to_deg(euler.y), rad_to_deg(euler.z))


func _describe_origin_event(event_flags: int) -> String:
	if event_flags & RawControllerState.EVENT_SET_ORIGIN:
		return "set"
	if event_flags & RawControllerState.EVENT_CLEAR_ORIGIN:
		return "clear"
	return "none"


func _log_info(event: String, fields: Dictionary = {}) -> void:
	QuestRuntimeLog.info(event, fields)
