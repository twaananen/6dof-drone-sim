extends Node

@export var server_host: String = "127.0.0.1"
@export var server_port: int = 9101
@export var reconnect_delay_sec: float = 1.0

signal connected()
signal disconnected()
signal message_received(message)

var _client: StreamPeerTCP = StreamPeerTCP.new()
var _buffer: String = ""
var _was_connected: bool = false
var _reconnect_timer_sec: float = 0.0


func connect_to_server() -> void:
	_client.poll()
	var status := _client.get_status()
	if status == StreamPeerTCP.STATUS_CONNECTED or status == StreamPeerTCP.STATUS_CONNECTING:
		return
	_client.connect_to_host(server_host, server_port)


func _ready() -> void:
	_reconnect_timer_sec = 0.0
	connect_to_server()


func _process(delta: float) -> void:
	_client.poll()
	var status := _client.get_status()
	var is_connected := status == StreamPeerTCP.STATUS_CONNECTED
	if is_connected and not _was_connected:
		_was_connected = true
		_reconnect_timer_sec = reconnect_delay_sec
		connected.emit()
	elif not is_connected and _was_connected:
		_was_connected = false
		_buffer = ""
		_reconnect_timer_sec = reconnect_delay_sec
		disconnected.emit()

	if not is_connected:
		if status == StreamPeerTCP.STATUS_NONE or status == StreamPeerTCP.STATUS_ERROR:
			_reconnect_timer_sec = maxf(_reconnect_timer_sec - delta, 0.0)
			if is_zero_approx(_reconnect_timer_sec):
				connect_to_server()
				_reconnect_timer_sec = reconnect_delay_sec
		return

	var available := _client.get_available_bytes()
	if available <= 0:
		return
	_buffer += _client.get_utf8_string(available)
	while true:
		var newline_index := _buffer.find("\n")
		if newline_index < 0:
			break
		var line := _buffer.substr(0, newline_index).strip_edges()
		_buffer = _buffer.substr(newline_index + 1)
		if line.is_empty():
			continue
		var json := JSON.new()
		if json.parse(line) == OK:
			message_received.emit(json.data)
		else:
			push_warning("Control client JSON parse failed: %s" % line)


func send_message(message: Dictionary) -> void:
	_client.poll()
	if _client.get_status() != StreamPeerTCP.STATUS_CONNECTED:
		return
	var line := JSON.stringify(message) + "\n"
	_client.put_data(line.to_utf8_buffer())


func is_socket_connected() -> bool:
	return _client.get_status() == StreamPeerTCP.STATUS_CONNECTED


func get_connection_state() -> String:
	match _client.get_status():
		StreamPeerTCP.STATUS_CONNECTING:
			return "connecting"
		StreamPeerTCP.STATUS_CONNECTED:
			return "connected"
		StreamPeerTCP.STATUS_ERROR:
			return "error"
		_:
			return "disconnected"


func set_server_host(host: String, port: int = -1) -> void:
	if port > 0:
		server_port = port
	if host == server_host:
		return
	server_host = host
	_client.disconnect_from_host()
	if _was_connected:
		_was_connected = false
		disconnected.emit()
	_buffer = ""
	_reconnect_timer_sec = 0.0
	connect_to_server()


func _exit_tree() -> void:
	_client.disconnect_from_host()
