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
