extends "res://addons/gut/test.gd"

const RawControllerState = preload("res://scripts/telemetry/raw_controller_state.gd")


func test_roundtrip_packet() -> void:
    var state := RawControllerState.default_state()
    state["sequence"] = 5
    state["timestamp_usec"] = 42
    state["tracking_valid"] = true
    state["event_flags"] = RawControllerState.EVENT_CALIBRATE
    state["buttons"] = RawControllerState.BUTTON_SOUTH | RawControllerState.BUTTON_MENU
    state["grip_position"] = Vector3(1.0, 2.0, 3.0)
    state["grip_orientation"] = Quaternion(0.0, 0.0, 0.0, 1.0)
    state["linear_velocity"] = Vector3(0.1, 0.2, 0.3)
    state["angular_velocity"] = Vector3(-0.1, -0.2, -0.3)
    state["trigger"] = 0.75
    state["grip"] = 0.5
    state["thumbstick"] = Vector2(0.25, -0.75)

    var packet := RawControllerState.pack_state(state)
    assert_eq(packet.size(), RawControllerState.PACKET_SIZE)

    var unpacked := RawControllerState.unpack_state(packet)
    assert_true(unpacked["valid"])
    assert_eq(unpacked["sequence"], 5)
    assert_eq(unpacked["timestamp_usec"], 42)
    assert_true(unpacked["tracking_valid"])
    assert_eq(unpacked["event_flags"], RawControllerState.EVENT_CALIBRATE)
    assert_eq(unpacked["buttons"], state["buttons"])
    assert_almost_eq(unpacked["grip_position"].x, 1.0, 0.001)
    assert_almost_eq(unpacked["trigger"], 0.75, 0.001)
    assert_almost_eq(unpacked["thumbstick"].y, -0.75, 0.001)


func test_invalid_magic_rejected() -> void:
    var packet := PackedByteArray([0, 0, 0, 0])
    var unpacked := RawControllerState.unpack_state(packet)
    assert_false(unpacked["valid"])
