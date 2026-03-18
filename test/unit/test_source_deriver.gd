extends "res://addons/gut/test.gd"

const SourceDeriver = preload("res://scripts/telemetry/source_deriver.gd")


func test_derives_calibrated_sources() -> void:
    var deriver := SourceDeriver.new()
    var state := {
        "grip_position": Vector3(1.0, 1.0, 1.0),
        "grip_orientation": Quaternion.IDENTITY,
        "control_active": true,
        "linear_velocity": Vector3(0.1, 0.2, 0.3),
        "angular_velocity": Vector3(0.4, 0.5, 0.6),
        "trigger": 0.8,
        "grip": 0.2,
        "thumbstick": Vector2(0.5, -0.25),
        "buttons": 0
    }
    deriver.calibrate_from_state(state)

    var moved := state.duplicate()
    moved["grip_position"] = Vector3(1.5, 0.5, 2.0)
    var sources := deriver.derive_sources(moved)

    assert_almost_eq(sources["pos_x_m"], 0.5, 0.001)
    assert_almost_eq(sources["pos_y_m"], -0.5, 0.001)
    assert_almost_eq(sources["radius_xyz_m"], Vector3(0.5, -0.5, 1.0).length(), 0.001)
    assert_eq(sources["control_active"], 1.0)
    assert_almost_eq(sources["trigger"], 0.8, 0.001)
    assert_almost_eq(sources["thumbstick_y"], -0.25, 0.001)


func test_twist_roll_isolated_from_pitch() -> void:
    var deriver := SourceDeriver.new()
    var calib_state := {
        "grip_position": Vector3.ZERO,
        "grip_orientation": Quaternion.IDENTITY,
        "control_active": true,
        "linear_velocity": Vector3.ZERO,
        "angular_velocity": Vector3.ZERO,
        "trigger": 0.0,
        "grip": 0.0,
        "thumbstick": Vector2.ZERO,
        "buttons": 0
    }
    deriver.calibrate_from_state(calib_state)

    # Clockwise roll looking forward along -Z (30 degrees)
    var roll_quat := Quaternion(Vector3(0, 0, -1), deg_to_rad(30.0))
    var rolled := calib_state.duplicate()
    rolled["grip_orientation"] = roll_quat
    var sources := deriver.derive_sources(rolled)

    assert_almost_eq(sources["twist_roll_deg"], 30.0, 1.0)
    assert_almost_eq(sources["swing_pitch_deg"], 0.0, 1.0)
    assert_almost_eq(sources["swing_yaw_deg"], 0.0, 1.0)


func test_swing_pitch_isolated_from_roll() -> void:
    var deriver := SourceDeriver.new()
    var calib_state := {
        "grip_position": Vector3.ZERO,
        "grip_orientation": Quaternion.IDENTITY,
        "control_active": true,
        "linear_velocity": Vector3.ZERO,
        "angular_velocity": Vector3.ZERO,
        "trigger": 0.0,
        "grip": 0.0,
        "thumbstick": Vector2.ZERO,
        "buttons": 0
    }
    deriver.calibrate_from_state(calib_state)

    # Pure X-axis rotation (25 degrees pitch)
    var pitch_quat := Quaternion(Vector3(1, 0, 0), deg_to_rad(25.0))
    var pitched := calib_state.duplicate()
    pitched["grip_orientation"] = pitch_quat
    var sources := deriver.derive_sources(pitched)

    assert_almost_eq(sources["swing_pitch_deg"], 25.0, 1.0)
    assert_almost_eq(sources["twist_roll_deg"], 0.0, 1.0)


func test_off_axis_roll_stays_in_twist() -> void:
    var deriver := SourceDeriver.new()
    var calib_state := {
        "grip_position": Vector3.ZERO,
        "grip_orientation": Quaternion.IDENTITY,
        "control_active": true,
        "linear_velocity": Vector3.ZERO,
        "angular_velocity": Vector3.ZERO,
        "trigger": 0.0,
        "grip": 0.0,
        "thumbstick": Vector2.ZERO,
        "buttons": 0
    }
    deriver.calibrate_from_state(calib_state)

    # Rotation around an axis 20 degrees off from -Z toward +X (simulating forearm roll)
    var off_axis := Vector3(sin(deg_to_rad(20.0)), 0, -cos(deg_to_rad(20.0))).normalized()
    var roll_quat := Quaternion(off_axis, deg_to_rad(30.0))
    var rolled := calib_state.duplicate()
    rolled["grip_orientation"] = roll_quat
    var sources := deriver.derive_sources(rolled)

    # Most of the rotation should land in twist_roll_deg (~28.2 deg expected)
    assert_gt(absf(sources["twist_roll_deg"]), 25.0)
    # Swing pitch leakage should be small (~10.3 deg expected)
    assert_lt(absf(sources["swing_pitch_deg"]), 12.0)
