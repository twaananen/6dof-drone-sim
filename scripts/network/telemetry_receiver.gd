extends Node

const RawControllerState = preload("res://scripts/telemetry/raw_controller_state.gd")

@export var listen_port: int = 9100
@export var bind_host: String = "0.0.0.0"
@export var restart_gap_usec: int = 100000

signal state_received(state)

var _peer: PacketPeerUDP = PacketPeerUDP.new()
var _last_sequence: int = -1
var _last_packet_local_usec: int = -1
var _bind_error: Error = OK
var latest_state: Dictionary = RawControllerState.default_state()
var packets_received: int = 0
var packets_dropped: int = 0


func _ready() -> void:
	if _uses_default_bind_host():
		_bind_error = _peer.bind(listen_port)
	else:
		_bind_error = _peer.bind(listen_port, bind_host)
	if _bind_error != OK:
		push_error("Failed to bind telemetry receiver: %s" % error_string(_bind_error))


func _process(_delta: float) -> void:
	while _peer.get_available_packet_count() > 0:
		var packet := _peer.get_packet()
		var unpacked := RawControllerState.unpack_state(packet)
		if not unpacked.get("valid", false):
			continue

		var now_usec: int = Time.get_ticks_usec()
		var sequence: int = int(unpacked.get("sequence", -1))
		if not _should_accept_sequence(sequence, now_usec):
			continue
		if _last_sequence >= 0 and sequence > _last_sequence + 1:
			packets_dropped += sequence - _last_sequence - 1
		_last_sequence = sequence
		_last_packet_local_usec = now_usec

		packets_received += 1
		latest_state = unpacked
		state_received.emit(unpacked)


func get_stats() -> Dictionary:
	return {
		"packets_received": packets_received,
		"packets_dropped": packets_dropped,
		"last_sequence": _last_sequence,
	}


func get_listen_port() -> int:
	return _peer.get_local_port()


func get_bind_error() -> Error:
	return _bind_error


func _uses_default_bind_host() -> bool:
	return bind_host.is_empty() or bind_host == "*" or bind_host == "0.0.0.0"


func _exit_tree() -> void:
	_peer.close()


func _should_accept_sequence(sequence: int, now_usec: int) -> bool:
	if _last_sequence < 0:
		return true
	if sequence > _last_sequence:
		return true
	if _last_packet_local_usec < 0:
		return false
	return (now_usec - _last_packet_local_usec) > restart_gap_usec
