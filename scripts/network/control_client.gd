extends Node

@export var server_host: String = "127.0.0.1"
@export var server_port: int = 9101
@export var reconnect_delay_sec: float = 1.0
@export var auto_connect_on_ready: bool = true

signal connected()
signal disconnected()
signal message_received(message)
signal connection_state_changed(state: String, error_code: int)

var _client: StreamPeerTCP = StreamPeerTCP.new()
var _buffer: String = ""
var _was_connected: bool = false
var _reconnect_timer_sec: float = 0.0
var _last_connect_error: Error = OK
var _last_attempt_time_usec: int = 0
var _reported_state: String = ""


func connect_to_server() -> void:
	_client.poll()
	var status := _client.get_status()
	if status == StreamPeerTCP.STATUS_CONNECTED or status == StreamPeerTCP.STATUS_CONNECTING:
		return
	if server_host.is_empty() or server_port <= 0:
		_last_connect_error = ERR_INVALID_PARAMETER
		_report_state("error", _last_connect_error)
		return
	_last_attempt_time_usec = Time.get_ticks_usec()
	_last_connect_error = _client.connect_to_host(server_host, server_port)
	if _last_connect_error != OK:
		_report_state("error", _last_connect_error)
		return
	_report_state("connecting", OK)


func _ready() -> void:
	_reconnect_timer_sec = 0.0
	if auto_connect_on_ready:
		connect_to_server()
	else:
		_report_state("unconfigured", OK)


func _process(delta: float) -> void:
	_client.poll()
	var status := _client.get_status()
	var is_connected := status == StreamPeerTCP.STATUS_CONNECTED
	if is_connected and not _was_connected:
		_was_connected = true
		_reconnect_timer_sec = reconnect_delay_sec
		_report_state("connected", OK)
		connected.emit()
	elif not is_connected and _was_connected:
		_was_connected = false
		_buffer = ""
		_reconnect_timer_sec = reconnect_delay_sec
		_report_state("disconnected", OK)
		disconnected.emit()

	if not is_connected:
		if status == StreamPeerTCP.STATUS_CONNECTING:
			_report_state("connecting", OK)
		elif status == StreamPeerTCP.STATUS_ERROR:
			_report_state("error", _last_connect_error if _last_connect_error != OK else FAILED)
		elif server_host.is_empty():
			_report_state("unconfigured", OK)
		else:
			_report_state("disconnected", OK)
		if (status == StreamPeerTCP.STATUS_NONE or status == StreamPeerTCP.STATUS_ERROR) and not server_host.is_empty():
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
	if server_host.is_empty():
		return "unconfigured"
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
	var new_port := port if port > 0 else server_port
	if host == server_host and new_port == server_port:
		return
	server_host = host
	server_port = new_port
	_client.disconnect_from_host()
	if _was_connected:
		_was_connected = false
		disconnected.emit()
	_buffer = ""
	_reconnect_timer_sec = 0.0
	if server_host.is_empty():
		_report_state("unconfigured", OK)
		return
	connect_to_server()


func disconnect_from_server(clear_host: bool = false) -> void:
	_client.disconnect_from_host()
	_buffer = ""
	_was_connected = false
	_reconnect_timer_sec = reconnect_delay_sec
	if clear_host:
		server_host = ""
	_report_state("unconfigured" if server_host.is_empty() else "disconnected", OK)


func get_diagnostics() -> Dictionary:
	return {
		"control_target_host": server_host,
		"control_target_port": server_port,
		"control_connection_state": get_connection_state(),
		"control_last_error": error_string(_last_connect_error) if _last_connect_error != OK else "",
		"control_last_error_code": int(_last_connect_error),
		"control_last_attempt_usec": _last_attempt_time_usec,
	}


func _report_state(state: String, error_code: Error) -> void:
	if state == _reported_state and error_code == _last_connect_error:
		return
	_reported_state = state
	_last_connect_error = error_code
	connection_state_changed.emit(state, int(error_code))


func _exit_tree() -> void:
	_client.disconnect_from_host()
