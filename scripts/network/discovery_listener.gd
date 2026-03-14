extends Node

const DISCOVERY_PORT: int = 9102

signal server_discovered(ip: String, control_port: int, telemetry_port: int)

var _peer: PacketPeerUDP = PacketPeerUDP.new()
var _discovered_ip: String = ""


func _ready() -> void:
	if _peer.bind(DISCOVERY_PORT) != OK:
		push_warning("DiscoveryListener: failed to bind UDP port %d" % DISCOVERY_PORT)
		set_process(false)


func _process(_delta: float) -> void:
	while _peer.get_available_packet_count() > 0:
		var data := _peer.get_packet()
		var sender_ip := _peer.get_packet_ip()
		if data.is_empty() or sender_ip.is_empty():
			continue
		var json := JSON.new()
		if json.parse(data.get_string_from_utf8()) != OK:
			continue
		var msg: Dictionary = json.data
		if str(msg.get("service", "")) != "6dof-drone-pc":
			continue
		var control_port := int(msg.get("control_port", 9101))
		var telemetry_port := int(msg.get("telemetry_port", 9100))
		if sender_ip != _discovered_ip:
			_discovered_ip = sender_ip
			server_discovered.emit(sender_ip, control_port, telemetry_port)


func _exit_tree() -> void:
	_peer.close()
