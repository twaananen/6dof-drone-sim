extends Node

@export var listen_port: int = 9101

signal message_received(message)
signal client_connected()
signal client_disconnected()

var _server: TCPServer = TCPServer.new()
var _client: StreamPeerTCP
var _buffer: String = ""


func _ready() -> void:
	var err := _server.listen(listen_port)
	if err != OK:
		push_error("Failed to start control server: %s" % error_string(err))


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


func _exit_tree() -> void:
	if _client != null:
		_client.disconnect_from_host()
		_client = null
	_server.stop()
