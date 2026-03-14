extends Node

@export var target_host: String = "127.0.0.1"
@export var target_port: int = 9100

var _peer: PacketPeerUDP = PacketPeerUDP.new()
var _sequence: int = 0
var last_send_time_usec: int = 0


func _ready() -> void:
    _peer.set_dest_address(target_host, target_port)


func send_state(state: Dictionary) -> void:
    var enriched := state.duplicate()
    enriched["sequence"] = _sequence
    enriched["timestamp_usec"] = Time.get_ticks_usec()
    last_send_time_usec = enriched["timestamp_usec"]
    _peer.put_packet(RawControllerState.pack_state(enriched))
    _sequence += 1


func set_target_host(host: String, port: int = -1) -> void:
    var new_port := port if port > 0 else target_port
    if host == target_host and new_port == target_port:
        return
    target_host = host
    target_port = new_port
    _peer.close()
    _peer.set_dest_address(target_host, target_port)


func _exit_tree() -> void:
    _peer.close()
