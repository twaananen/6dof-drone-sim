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
    var euler: Vector3 = basis.get_euler()
    var buttons: int = int(state.get("buttons", 0))

    return {
        "pose_pitch_deg": rad_to_deg(euler.x),
        "pose_yaw_deg": rad_to_deg(euler.y),
        "pose_roll_deg": rad_to_deg(euler.z),
        "pos_x_m": position.x,
        "pos_y_m": position.y,
        "pos_z_m": position.z,
        "angvel_x_rad_s": state.get("angular_velocity", Vector3.ZERO).x,
        "angvel_y_rad_s": state.get("angular_velocity", Vector3.ZERO).y,
        "angvel_z_rad_s": state.get("angular_velocity", Vector3.ZERO).z,
        "linvel_x_m_s": state.get("linear_velocity", Vector3.ZERO).x,
        "linvel_y_m_s": state.get("linear_velocity", Vector3.ZERO).y,
        "linvel_z_m_s": state.get("linear_velocity", Vector3.ZERO).z,
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
