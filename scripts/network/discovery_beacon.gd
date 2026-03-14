extends Node

const DiscoveryProtocol = preload("res://scripts/network/discovery_protocol.gd")
const BROADCAST_INTERVAL_SEC: float = 1.0

@export var control_port: int = 9101
@export var telemetry_port: int = 9100

var _peer: PacketPeerUDP = PacketPeerUDP.new()
var _timer: float = BROADCAST_INTERVAL_SEC
var _payload: PackedByteArray
var packets_sent: int = 0
var last_send_error: Error = OK
var last_broadcast_time_usec: int = 0


func _ready() -> void:
	_peer.set_broadcast_enabled(true)
	_peer.set_dest_address("255.255.255.255", DiscoveryProtocol.DISCOVERY_PORT)
	_payload = DiscoveryProtocol.build_payload(control_port, telemetry_port)


func _process(delta: float) -> void:
	_timer += delta
	if _timer >= BROADCAST_INTERVAL_SEC:
		_timer = 0.0
		last_send_error = _peer.put_packet(_payload)
		if last_send_error == OK:
			packets_sent += 1
			last_broadcast_time_usec = Time.get_ticks_usec()
		else:
			push_warning("DiscoveryBeacon: failed to broadcast beacon: %s" % error_string(last_send_error))


func get_diagnostics() -> Dictionary:
	return {
		"beacon_packets_sent": packets_sent,
		"beacon_last_error": error_string(last_send_error) if last_send_error != OK else "",
		"beacon_last_error_code": int(last_send_error),
		"beacon_last_broadcast_usec": last_broadcast_time_usec,
		"beacon_control_port": control_port,
		"beacon_telemetry_port": telemetry_port,
	}


func _exit_tree() -> void:
	_peer.close()
