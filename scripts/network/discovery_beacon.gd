extends Node

const DISCOVERY_PORT: int = 9102
const BROADCAST_INTERVAL_SEC: float = 1.0

@export var control_port: int = 9101
@export var telemetry_port: int = 9100

var _peer: PacketPeerUDP = PacketPeerUDP.new()
var _timer: float = 0.0
var _payload: PackedByteArray


func _ready() -> void:
	_peer.set_broadcast_enabled(true)
	_peer.set_dest_address("255.255.255.255", DISCOVERY_PORT)
	_payload = JSON.stringify({
		"service": "6dof-drone-pc",
		"control_port": control_port,
		"telemetry_port": telemetry_port,
	}).to_utf8_buffer()


func _process(delta: float) -> void:
	_timer += delta
	if _timer >= BROADCAST_INTERVAL_SEC:
		_timer = 0.0
		_peer.put_packet(_payload)


func _exit_tree() -> void:
	_peer.close()
