extends Node

@export var listen_port: int = 9101
@export var bind_host: String = "0.0.0.0"

signal message_received(message)
signal client_connected()
signal client_disconnected()

var _server: TCPServer = TCPServer.new()
var _client: StreamPeerTCP
var _buffer: String = ""
var _listen_error: Error = OK


func _ready() -> void:
	if _uses_default_bind_host():
		_listen_error = _server.listen(listen_port)
	else:
		_listen_error = _server.listen(listen_port, bind_host)
	if _listen_error != OK:
		push_error("Failed to start control server: %s" % error_string(_listen_error))


func _process(_delta: float) -> void:
	if _server.is_connection_available():
		var new_client := _server.take_connection()
		if _client != null:
			_client.disconnect_from_host()
			_buffer = ""
			client_disconnected.emit()
		_client = new_client
		client_connected.emit()

	if _client == null:
		return

	_client.poll()
	var status := _client.get_status()
	if status != StreamPeerTCP.STATUS_CONNECTED:
		_client = null
		_buffer = ""
		client_disconnected.emit()
		return

	var available := _client.get_available_bytes()
	if available <= 0:
		return

	var data := _client.get_utf8_string(available)
	_buffer += data

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
			push_warning("Control server JSON parse failed: %s" % line)


func send_message(message: Dictionary) -> void:
	if _client == null:
		return
	var line := JSON.stringify(message) + "\n"
	_client.put_data(line.to_utf8_buffer())


func has_client() -> bool:
	return _client != null


func get_listen_port() -> int:
	if _server.is_listening():
		return _server.get_local_port()
	return listen_port


func get_listen_error() -> Error:
	return _listen_error


func _uses_default_bind_host() -> bool:
	return bind_host.is_empty() or bind_host == "*" or bind_host == "0.0.0.0"


func _exit_tree() -> void:
	if _client != null:
		_client.disconnect_from_host()
		_client = null
	_server.stop()
