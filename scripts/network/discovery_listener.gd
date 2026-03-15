extends Node

const DiscoveryProtocol = preload("res://scripts/network/discovery_protocol.gd")

@export var listen_port: int = DiscoveryProtocol.DISCOVERY_PORT

signal server_discovered(ip: String, control_port: int, telemetry_port: int)
signal bind_failed(error_code: int)

var _peer: PacketPeerUDP = PacketPeerUDP.new()
var _discovered_ip: String = ""
var _discovered_control_port: int = 0
var _discovered_telemetry_port: int = 0
var _bind_error: Error = OK
var _last_error: String = ""
var _last_packet_ip: String = ""
var _last_packet_usec: int = 0
var _packets_received: int = 0
var _invalid_packets: int = 0


func _ready() -> void:
	_peer.set_broadcast_enabled(true)
	_bind_error = _peer.bind(listen_port)
	if _bind_error != OK:
		_last_error = "Failed to bind UDP port %d: %s" % [
			listen_port,
			error_string(_bind_error),
		]
		push_warning("DiscoveryListener: %s" % _last_error)
		QuestRuntimeLog.warn("DISCOVERY_BIND_FAILED", {
			"listen_port": listen_port,
			"error_code": int(_bind_error),
			"error": _last_error,
		})
		set_process(false)
		bind_failed.emit(int(_bind_error))
		return
	QuestRuntimeLog.info("DISCOVERY_BIND_OK", {
		"listen_port": listen_port,
	})


func _process(_delta: float) -> void:
	while _peer.get_available_packet_count() > 0:
		_packets_received += 1
		var data := _peer.get_packet()
		var sender_ip := _peer.get_packet_ip()
		if data.is_empty() or sender_ip.is_empty():
			_invalid_packets += 1
			continue
		var parsed: Dictionary = DiscoveryProtocol.parse_packet(data)
		if not bool(parsed.get("valid", false)):
			_invalid_packets += 1
			_last_error = str(parsed.get("error", "invalid_packet"))
			continue
		_last_packet_ip = sender_ip
		_last_packet_usec = Time.get_ticks_usec()
		var control_port := int(parsed.get("control_port", 9101))
		var telemetry_port := int(parsed.get("telemetry_port", 9100))
		if sender_ip != _discovered_ip or control_port != _discovered_control_port or telemetry_port != _discovered_telemetry_port:
			_discovered_ip = sender_ip
			_discovered_control_port = control_port
			_discovered_telemetry_port = telemetry_port
			_last_error = ""
			QuestRuntimeLog.info("DISCOVERY_PACKET_ACCEPTED", {
				"ip": sender_ip,
				"control_port": control_port,
				"telemetry_port": telemetry_port,
			})
			server_discovered.emit(sender_ip, control_port, telemetry_port)


static func parse_packet(data: PackedByteArray) -> Dictionary:
	return DiscoveryProtocol.parse_packet(data)


func get_bind_error() -> Error:
	return _bind_error


func get_diagnostics() -> Dictionary:
	return {
		"discovery_listen_port": listen_port,
		"discovery_bind_error": int(_bind_error),
		"discovery_bind_error_text": error_string(_bind_error) if _bind_error != OK else "",
		"discovery_last_error": _last_error,
		"discovery_packets_received": _packets_received,
		"discovery_invalid_packets": _invalid_packets,
		"discovery_last_ip": _discovered_ip,
		"discovery_last_control_port": _discovered_control_port,
		"discovery_last_telemetry_port": _discovered_telemetry_port,
		"discovery_last_packet_ip": _last_packet_ip,
		"discovery_last_packet_usec": _last_packet_usec,
	}


func _exit_tree() -> void:
	_peer.close()
