class_name RawControllerState
extends RefCounted

const MAGIC_TEXT := "RCS1"
const VERSION := 3
const BUTTON_SOUTH := 1 << 0
const BUTTON_EAST := 1 << 1
const BUTTON_WEST := 1 << 2
const BUTTON_NORTH := 1 << 3
const BUTTON_THUMBSTICK := 1 << 4
const BUTTON_MENU := 1 << 5
const EVENT_SET_ORIGIN := 1 << 0
const EVENT_CLEAR_ORIGIN := 1 << 1
const EVENT_CALIBRATE := EVENT_SET_ORIGIN
const EVENT_RECENTER := EVENT_CLEAR_ORIGIN
const PACKET_SIZE := 91


static func default_state() -> Dictionary:
    return {
        "version": VERSION,
        "sequence": 0,
        "timestamp_usec": 0,
        "tracking_valid": false,
        "control_active": false,
        "event_flags": 0,
        "buttons": 0,
        "grip_position": Vector3.ZERO,
        "grip_orientation": Quaternion.IDENTITY,
        "linear_velocity": Vector3.ZERO,
        "angular_velocity": Vector3.ZERO,
        "trigger": 0.0,
        "grip": 0.0,
        "thumbstick": Vector2.ZERO,
    }


static func pack_state(state: Dictionary) -> PackedByteArray:
    var buf := StreamPeerBuffer.new()
    buf.big_endian = false
    buf.put_data(MAGIC_TEXT.to_utf8_buffer())
    buf.put_u8(int(state.get("version", VERSION)))
    buf.put_u32(int(state.get("sequence", 0)))
    buf.put_u64(int(state.get("timestamp_usec", 0)))
    buf.put_u8(1 if state.get("tracking_valid", false) else 0)
    buf.put_u8(1 if state.get("control_active", false) else 0)
    buf.put_u16(int(state.get("event_flags", 0)))
    buf.put_u16(int(state.get("buttons", 0)))

    var position: Vector3 = state.get("grip_position", Vector3.ZERO)
    _put_vector3(buf, position)

    var orientation: Quaternion = state.get("grip_orientation", Quaternion.IDENTITY)
    buf.put_float(orientation.x)
    buf.put_float(orientation.y)
    buf.put_float(orientation.z)
    buf.put_float(orientation.w)

    _put_vector3(buf, state.get("linear_velocity", Vector3.ZERO))
    _put_vector3(buf, state.get("angular_velocity", Vector3.ZERO))
    buf.put_float(float(state.get("trigger", 0.0)))
    buf.put_float(float(state.get("grip", 0.0)))

    var stick: Vector2 = state.get("thumbstick", Vector2.ZERO)
    buf.put_float(stick.x)
    buf.put_float(stick.y)
    return buf.data_array


static func unpack_state(packet: PackedByteArray) -> Dictionary:
    if packet.size() < 5:
        return {"valid": false, "error": "invalid_size"}

    var buf := StreamPeerBuffer.new()
    buf.big_endian = false
    buf.data_array = packet
    buf.seek(0)

    var magic_data := buf.get_data(4)
    if magic_data[0] != OK or magic_data[1].get_string_from_ascii() != MAGIC_TEXT:
        return {"valid": false, "error": "invalid_magic"}

    var version := buf.get_u8()
    if version != VERSION:
        return {"valid": false, "error": "invalid_version", "version": version}
    if packet.size() != PACKET_SIZE:
        return {"valid": false, "error": "invalid_size", "version": version}

    var state: Dictionary = {"version": version}
    state["sequence"] = buf.get_u32()
    state["timestamp_usec"] = buf.get_u64()
    state["tracking_valid"] = buf.get_u8() == 1
    state["control_active"] = buf.get_u8() == 1
    state["event_flags"] = buf.get_u16()
    state["buttons"] = buf.get_u16()
    state["grip_position"] = _get_vector3(buf)
    state["grip_orientation"] = Quaternion(
        buf.get_float(),
        buf.get_float(),
        buf.get_float(),
        buf.get_float()
    ).normalized()
    state["linear_velocity"] = _get_vector3(buf)
    state["angular_velocity"] = _get_vector3(buf)
    state["trigger"] = buf.get_float()
    state["grip"] = buf.get_float()
    state["thumbstick"] = Vector2(buf.get_float(), buf.get_float())
    state["valid"] = true
    return state


static func button_pressed(buttons: int, bit: int) -> bool:
    return (buttons & bit) != 0


static func _put_vector3(buf: StreamPeerBuffer, value: Vector3) -> void:
    buf.put_float(value.x)
    buf.put_float(value.y)
    buf.put_float(value.z)


static func _get_vector3(buf: StreamPeerBuffer) -> Vector3:
    return Vector3(buf.get_float(), buf.get_float(), buf.get_float())
