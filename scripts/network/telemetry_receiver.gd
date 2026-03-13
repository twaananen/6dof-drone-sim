extends Node

@export var listen_port: int = 9100

signal state_received(state)

var _peer: PacketPeerUDP = PacketPeerUDP.new()
var _last_sequence: int = -1
var latest_state: Dictionary = RawControllerState.default_state()
var packets_received: int = 0
var packets_dropped: int = 0


func _ready() -> void:
    var err := _peer.bind(listen_port)
    if err != OK:
        push_error("Failed to bind telemetry receiver: %s" % error_string(err))


func _process(_delta: float) -> void:
    while _peer.get_available_packet_count() > 0:
        var packet := _peer.get_packet()
        var unpacked := RawControllerState.unpack_state(packet)
        if not unpacked.get("valid", false):
            continue

        var sequence := int(unpacked.get("sequence", -1))
        if _last_sequence >= 0:
            if sequence <= _last_sequence and (_last_sequence - sequence) < 1000:
                continue
        if _last_sequence >= 0 and sequence > _last_sequence + 1:
            packets_dropped += sequence - _last_sequence - 1
        _last_sequence = sequence

        packets_received += 1
        latest_state = unpacked
        state_received.emit(unpacked)


func get_stats() -> Dictionary:
    return {
        "packets_received": packets_received,
        "packets_dropped": packets_dropped,
        "last_sequence": _last_sequence,
    }


func _exit_tree() -> void:
    _peer.close()
