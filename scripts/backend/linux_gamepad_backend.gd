class_name LinuxGamepadBackend
extends "res://scripts/backend/gamepad_backend.gd"

const MAGIC_TEXT := "GPD1"

@export var helper_port: int = 9102
@export var helper_path: String = ""

var _peer: PacketPeerUDP = PacketPeerUDP.new()
var _helper_pid: int = -1
var _available: bool = false


func _ready() -> void:
    if OS.get_name() == "Linux":
        start_backend()


func start_backend() -> void:
    if OS.get_name() != "Linux":
        return
    var path := _resolve_helper_path()
    if path.is_empty() or not FileAccess.file_exists(path):
        push_warning("Linux helper binary not found: %s" % path)
        return
    _helper_pid = OS.create_process(path, [str(helper_port)])
    if _helper_pid > 0:
        _peer.set_dest_address("127.0.0.1", helper_port)
        _available = true


func push_state(mapped_outputs: Dictionary) -> void:
    if not _available:
        return
    var buf: StreamPeerBuffer = StreamPeerBuffer.new()
    buf.big_endian = false
    buf.put_data(MAGIC_TEXT.to_utf8_buffer())
    for key in ["yaw", "throttle", "roll", "pitch", "aux_analog_1", "aux_analog_2"]:
        buf.put_float(float(mapped_outputs.get(key, 0.0)))
    var buttons: int = 0
    for i in range(4):
        if mapped_outputs.get("aux_button_%d" % (i + 1), 0.0) >= 0.5:
            buttons |= 1 << i
    buf.put_u16(buttons)
    _peer.put_packet(buf.data_array)


func stop_backend() -> void:
    _peer.close()
    if _helper_pid > 0:
        OS.kill(_helper_pid)
        _helper_pid = -1
    _available = false


func is_available() -> bool:
    return _available


func _resolve_helper_path() -> String:
    if not helper_path.is_empty():
        return helper_path
    return ProjectSettings.globalize_path("res://tools/linux_gamepad_helper")


func _exit_tree() -> void:
    stop_backend()
