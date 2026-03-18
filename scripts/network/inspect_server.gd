extends Node

@export var listen_port: int = 9102
@export var bind_host: String = "0.0.0.0"
@export var response_timeout: float = 5.0

signal query_received(message: Dictionary)

var _server: TCPServer = TCPServer.new()
var _client: StreamPeerTCP
var _buffer: String = ""
var _listen_error: Error = OK

var _pending_request_id: String = ""
var _pending_timer: float = 0.0


func _ready() -> void:
	if _uses_default_bind_host():
		_listen_error = _server.listen(listen_port)
	else:
		_listen_error = _server.listen(listen_port, bind_host)
	if _listen_error != OK:
		push_error("Failed to start inspect server: %s" % error_string(_listen_error))


func _process(delta: float) -> void:
	if _server.is_connection_available():
		var new_client := _server.take_connection()
		if _client != null:
			_client.disconnect_from_host()
			_buffer = ""
			_pending_request_id = ""
		_client = new_client

	if _client == null:
		return

	_client.poll()
	var status := _client.get_status()
	if status != StreamPeerTCP.STATUS_CONNECTED:
		_client = null
		_buffer = ""
		_pending_request_id = ""
		return

	if not _pending_request_id.is_empty():
		_pending_timer += delta
		if _pending_timer > response_timeout:
			_send_error("Timeout waiting for Quest response")
			_pending_request_id = ""
			_pending_timer = 0.0
		return

	var available := _client.get_available_bytes()
	if available <= 0:
		return

	var data := _client.get_utf8_string(available)
	_buffer += data
	if _buffer.length() > 65536:
		_client.disconnect_from_host()
		_client = null
		_buffer = ""
		_pending_request_id = ""
		return

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
			_handle_query(json.data)
		else:
			_send_error("JSON parse failed")


func _handle_query(message: Dictionary) -> void:
	var request_id: String = str(message.get("request_id", ""))
	if request_id.is_empty():
		request_id = str(randi())
		message["request_id"] = request_id

	_pending_request_id = request_id
	_pending_timer = 0.0
	query_received.emit(message)


func deliver_response(message: Dictionary) -> void:
	var response_id := str(message.get("request_id", ""))
	if response_id != _pending_request_id:
		return
	_pending_request_id = ""
	_pending_timer = 0.0
	_send_response(message)


func _send_response(message: Dictionary) -> void:
	if _client == null:
		return
	var line := JSON.stringify(message) + "\n"
	_client.put_data(line.to_utf8_buffer())
	_client.disconnect_from_host()
	_client = null


func _send_error(error_text: String) -> void:
	_send_response({
		"request_id": _pending_request_id,
		"ok": false,
		"error": error_text,
	})


func has_pending_request() -> bool:
	return not _pending_request_id.is_empty()


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
