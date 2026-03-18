class_name SourceDeriver
extends RefCounted

const CalibrationState = preload("res://scripts/telemetry/calibration_state.gd")
var calibration: CalibrationState = CalibrationState.new()


func calibrate_from_state(state: Dictionary) -> void:
	calibration.calibrate(
		state.get("grip_position", Vector3.ZERO),
		state.get("grip_orientation", Quaternion.IDENTITY)
	)


func reset_calibration() -> void:
	calibration.reset()


func derive_sources(state: Dictionary) -> Dictionary:
	var position: Vector3 = calibration.apply_position(state.get("grip_position", Vector3.ZERO))
	var orientation: Quaternion = calibration.apply_orientation(
		state.get("grip_orientation", Quaternion.IDENTITY)
	)
	var basis: Basis = Basis(orientation)
	var euler: Vector3 = basis.get_euler(EULER_ORDER_YXZ)
	var swing_twist: Dictionary = _swing_twist_decompose(orientation, Vector3(0, 0, -1))
	var buttons: int = int(state.get("buttons", 0))
	var angvel: Vector3 = state.get("angular_velocity", Vector3.ZERO)
	var linvel: Vector3 = state.get("linear_velocity", Vector3.ZERO)

	return {
		"control_active": 1.0 if bool(state.get("control_active", false)) else 0.0,
		"pose_pitch_deg": rad_to_deg(euler.x),
		"pose_yaw_deg": rad_to_deg(euler.y),
		"pose_roll_deg": rad_to_deg(euler.z),
		"twist_roll_deg": swing_twist["twist_deg"],
		"swing_pitch_deg": swing_twist["swing_pitch_deg"],
		"swing_yaw_deg": swing_twist["swing_yaw_deg"],
		"pos_x_m": position.x,
		"pos_y_m": position.y,
		"pos_z_m": position.z,
		"angvel_x_rad_s": angvel.x,
		"angvel_y_rad_s": angvel.y,
		"angvel_z_rad_s": angvel.z,
		"linvel_x_m_s": linvel.x,
		"linvel_y_m_s": linvel.y,
		"linvel_z_m_s": linvel.z,
		"radius_xyz_m": position.length(),
		"radius_xz_m": Vector2(position.x, position.z).length(),
		"trigger": float(state.get("trigger", 0.0)),
		"grip": float(state.get("grip", 0.0)),
		"thumbstick_x": state.get("thumbstick", Vector2.ZERO).x,
		"thumbstick_y": state.get("thumbstick", Vector2.ZERO).y,
		"button_south": 1.0 if RawControllerState.button_pressed(buttons, RawControllerState.BUTTON_SOUTH) else 0.0,
		"button_east": 1.0 if RawControllerState.button_pressed(buttons, RawControllerState.BUTTON_EAST) else 0.0,
		"button_west": 1.0 if RawControllerState.button_pressed(buttons, RawControllerState.BUTTON_WEST) else 0.0,
		"button_north": 1.0 if RawControllerState.button_pressed(buttons, RawControllerState.BUTTON_NORTH) else 0.0,
		"button_thumbstick": 1.0 if RawControllerState.button_pressed(buttons, RawControllerState.BUTTON_THUMBSTICK) else 0.0,
		"button_menu": 1.0 if RawControllerState.button_pressed(buttons, RawControllerState.BUTTON_MENU) else 0.0,
	}


static func _swing_twist_decompose(q: Quaternion, twist_axis: Vector3) -> Dictionary:
	var projection: float = Vector3(q.x, q.y, q.z).dot(twist_axis)
	var twist := Quaternion(
		twist_axis.x * projection,
		twist_axis.y * projection,
		twist_axis.z * projection,
		q.w
	)
	var twist_len := twist.length()
	if twist_len < 1e-6:
		twist = Quaternion.IDENTITY
	else:
		twist = Quaternion(twist.x / twist_len, twist.y / twist_len, twist.z / twist_len, twist.w / twist_len)
	var swing := q * twist.inverse()

	var twist_angle := 2.0 * atan2(Vector3(twist.x, twist.y, twist.z).dot(twist_axis), twist.w)
	var swing_euler := Basis(swing).get_euler(EULER_ORDER_YXZ)

	return {
		"twist_deg": rad_to_deg(twist_angle),
		"swing_pitch_deg": rad_to_deg(swing_euler.x),
		"swing_yaw_deg": rad_to_deg(swing_euler.y),
	}
