extends Node

@export var target_host: String = "127.0.0.1"
@export var target_port: int = 9100
@export var configure_destination_on_ready: bool = true

var _peer: PacketPeerUDP = PacketPeerUDP.new()
var _sequence: int = 0
var _destination_configured: bool = false
var packets_sent: int = 0
var send_errors: int = 0
var last_send_error: Error = OK
var last_send_time_usec: int = 0


func _ready() -> void:
	if configure_destination_on_ready and not target_host.is_empty():
		_peer.set_dest_address(target_host, target_port)
		_destination_configured = true


func send_state(state: Dictionary) -> void:
	if not _destination_configured:
		return
	var enriched := state.duplicate()
	enriched["sequence"] = _sequence
	enriched["timestamp_usec"] = Time.get_ticks_usec()
	last_send_time_usec = enriched["timestamp_usec"]
	last_send_error = _peer.put_packet(RawControllerState.pack_state(enriched))
	if last_send_error == OK:
		packets_sent += 1
		_sequence += 1
	else:
		send_errors += 1


func set_target_host(host: String, port: int = -1) -> void:
	var new_port := port if port > 0 else target_port
	if host == target_host and new_port == target_port and _destination_configured:
		return
	target_host = host
	target_port = new_port
	_peer.close()
	_destination_configured = false
	if target_host.is_empty():
		return
	_peer.set_dest_address(target_host, target_port)
	_destination_configured = true


func clear_target() -> void:
	target_host = ""
	_destination_configured = false
	_peer.close()


func get_diagnostics() -> Dictionary:
	return {
		"telemetry_target_host": target_host,
		"telemetry_target_port": target_port,
		"telemetry_target_configured": _destination_configured,
		"telemetry_packets_sent": packets_sent,
		"telemetry_send_errors": send_errors,
		"telemetry_last_send_error": error_string(last_send_error) if last_send_error != OK else "",
		"telemetry_last_send_error_code": int(last_send_error),
		"telemetry_last_send_usec": last_send_time_usec,
	}


func _exit_tree() -> void:
	_peer.close()
