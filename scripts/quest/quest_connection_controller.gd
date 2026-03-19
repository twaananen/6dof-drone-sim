extends Node

const QuestConnectionState = preload("res://scripts/network/quest_connection_state.gd")

const DEFAULT_CONTROL_PORT := 9101
const DEFAULT_TELEMETRY_PORT := 9100
const CONNECTION_MODE_AUTO := "auto"
const CONNECTION_MODE_MANUAL := "manual"

signal connection_state_changed(snapshot)
signal connection_diagnostics_changed(diagnostics)

var connect_mode_select: OptionButton
var manual_server_host_label: Label
var manual_server_host_edit: LineEdit
var apply_connection_button: Button
var retry_connect_button: Button
var status_label: Label

var _control_client: Node
var _telemetry_sender: Node
var _discovery_listener: Node
var _connection_mode: String = CONNECTION_MODE_AUTO
var _manual_server_host: String = ""
var _discovered_server_ip: String = ""
var _discovered_control_port: int = DEFAULT_CONTROL_PORT
var _discovered_telemetry_port: int = DEFAULT_TELEMETRY_PORT
var _connection_state: QuestConnectionState = QuestConnectionState.new()
var _updating_connection_mode_select: bool = false


func configure(
	control_client: Node,
	telemetry_sender: Node,
	discovery_listener: Node,
	panel_root: Control
) -> bool:
	_control_client = control_client
	_telemetry_sender = telemetry_sender
	_discovery_listener = discovery_listener
	if panel_root != null:
		var base_path := "Panel/Margin/Scroll/VBox/"
		connect_mode_select = _require_panel_node(panel_root, base_path + "ConnectModeSelect") as OptionButton
		manual_server_host_label = _require_panel_node(panel_root, base_path + "ManualServerHostLabel") as Label
		manual_server_host_edit = _require_panel_node(panel_root, base_path + "ManualServerHostEdit") as LineEdit
		apply_connection_button = _require_panel_node(
			panel_root,
			base_path + "ConnectionButtons/ApplyConnectionButton"
		) as Button
		retry_connect_button = _require_panel_node(
			panel_root,
			base_path + "ConnectionButtons/RetryConnectButton"
		) as Button
		status_label = _require_panel_node(panel_root, base_path + "StatusLabel") as Label
		if not _has_bound_controls():
			return false
		_connect_controls()
	_load_connection_modes()
	return true


func set_xr_starting() -> void:
	_connection_state.set_xr_starting()
	_emit_state_changed()


func set_error_state(error_text: String) -> void:
	_connection_state.set_error(error_text)
	_emit_state_changed()


func mark_profile_synced() -> void:
	_connection_state.set_profile_synced()
	_emit_state_changed()


func begin_auto_discovery_wait() -> void:
	_set_auto_discovery_wait_state()
	_emit_state_changed()


func handle_control_connected() -> void:
	_emit_state_changed()


func handle_control_disconnected() -> void:
	_emit_state_changed()


func refresh_ui_enabled_state(_control_connected: bool) -> void:
	_update_connection_controls()


func get_runtime_diagnostics() -> Dictionary:
	var diagnostics := _connection_state.to_dict()
	diagnostics["connection_mode"] = _connection_mode
	diagnostics["manual_server_host"] = _manual_server_host
	diagnostics["discovery_state"] = _connection_state.state
	diagnostics["discovery_error"] = _connection_state.last_error
	diagnostics["control_target_host"] = str(_control_client.server_host) if _control_client != null else ""
	if _discovery_listener != null:
		var discovery: Dictionary = _discovery_listener.get_diagnostics()
		diagnostics.merge(discovery, true)
		diagnostics["beacon_packets_received"] = int(discovery.get("discovery_packets_received", 0))
	if _control_client != null:
		diagnostics.merge(_control_client.get_diagnostics(), true)
	if _telemetry_sender != null:
		diagnostics.merge(_telemetry_sender.get_diagnostics(), true)
	return diagnostics


func get_connection_state_snapshot() -> Dictionary:
	return _connection_state.to_dict()


func get_connection_mode() -> String:
	return _connection_mode


func get_manual_server_host() -> String:
	return _manual_server_host


func on_control_connection_state_changed(state: String, error_code: int) -> void:
	QuestRuntimeLog.info("CONTROL_CONNECTION_STATE_CHANGED", {
		"state": state,
		"error_code": error_code,
		"host": str(_control_client.server_host),
		"server_port": int(_control_client.server_port),
		"telemetry_port": int(_telemetry_sender.target_port),
	})
	match state:
		"connecting":
			_connection_state.set_tcp_connecting(
				str(_control_client.server_host),
				int(_control_client.server_port),
				int(_telemetry_sender.target_port)
			)
		"connected":
			_connection_state.set_tcp_connected(
				str(_control_client.server_host),
				int(_control_client.server_port),
				int(_telemetry_sender.target_port)
			)
		"unconfigured":
			if _connection_mode == CONNECTION_MODE_MANUAL:
				_connection_state.set_manual_override(
					_manual_server_host,
					DEFAULT_CONTROL_PORT,
					DEFAULT_TELEMETRY_PORT
				)
			else:
				_set_auto_discovery_wait_state()
		"error":
			_connection_state.set_error("Control connection error: %s" % error_string(error_code))
		_:
			if _connection_mode == CONNECTION_MODE_MANUAL:
				_connection_state.set_manual_override(
					_manual_server_host,
					DEFAULT_CONTROL_PORT,
					DEFAULT_TELEMETRY_PORT
				)
			elif _discovered_server_ip.is_empty():
				_set_auto_discovery_wait_state()
			else:
				_connection_state.set_beacon_received(
					_discovered_server_ip,
					_discovered_control_port,
					_discovered_telemetry_port
				)
	_update_connection_controls()
	_emit_state_changed()


func on_server_discovered(ip: String, control_port: int, telemetry_port: int) -> void:
	_discovered_server_ip = ip
	_discovered_control_port = control_port
	_discovered_telemetry_port = telemetry_port
	QuestRuntimeLog.info("DISCOVERY_RESULT_RECEIVED", {
		"ip": ip,
		"control_port": control_port,
		"telemetry_port": telemetry_port,
		"mode": _connection_mode,
	})
	if _connection_mode == CONNECTION_MODE_AUTO:
		_apply_target_host(ip, control_port, telemetry_port, false)
		return
	_emit_state_changed()


func on_discovery_bind_failed(error_code: int) -> void:
	if _connection_mode == CONNECTION_MODE_AUTO:
		_connection_state.set_error("Discovery listener failed to bind: %s" % error_string(error_code))
	QuestRuntimeLog.error("DISCOVERY_BIND_FAILED", {
		"error_code": error_code,
		"error": error_string(error_code),
		"mode": _connection_mode,
	})
	_emit_state_changed()


func _connect_controls() -> void:
	connect_mode_select.item_selected.connect(_on_connect_mode_selected)
	manual_server_host_edit.text_changed.connect(func(_new_text: String): _update_connection_controls())
	apply_connection_button.pressed.connect(_on_apply_connection_pressed)
	retry_connect_button.pressed.connect(_on_retry_connect_pressed)


func _load_connection_modes() -> void:
	if connect_mode_select == null:
		return
	_updating_connection_mode_select = true
	connect_mode_select.clear()
	connect_mode_select.add_item("Auto Discovery")
	connect_mode_select.set_item_metadata(0, CONNECTION_MODE_AUTO)
	connect_mode_select.add_item("Manual IP")
	connect_mode_select.set_item_metadata(1, CONNECTION_MODE_MANUAL)
	connect_mode_select.select(0)
	_updating_connection_mode_select = false
	_update_connection_controls()


func _on_connect_mode_selected(index: int) -> void:
	if _updating_connection_mode_select:
		return
	_connection_mode = str(connect_mode_select.get_item_metadata(index))
	_manual_server_host = manual_server_host_edit.text.strip_edges()
	QuestRuntimeLog.info("CONNECTION_MODE_CHANGED", {
		"mode": _connection_mode,
		"manual_server_host": _manual_server_host,
	})
	if _connection_mode == CONNECTION_MODE_AUTO:
		_control_client.disconnect_from_server(true)
		_telemetry_sender.clear_target()
		if _discovered_server_ip.is_empty():
			_set_auto_discovery_wait_state()
		else:
			_apply_target_host(_discovered_server_ip, _discovered_control_port, _discovered_telemetry_port, false)
	else:
		_control_client.disconnect_from_server(true)
		_telemetry_sender.clear_target()
		_connection_state.set_manual_override(_manual_server_host, DEFAULT_CONTROL_PORT, DEFAULT_TELEMETRY_PORT)
	_update_connection_controls()
	_emit_state_changed()


func _on_apply_connection_pressed() -> void:
	if _connection_mode == CONNECTION_MODE_MANUAL:
		_manual_server_host = manual_server_host_edit.text.strip_edges()
		if _manual_server_host.is_empty():
			_connection_state.set_error("Enter a manual server IP before connecting")
			QuestRuntimeLog.error("MANUAL_CONNECTION_REJECTED", {"reason": "empty_host"})
			_emit_state_changed()
			return
		QuestRuntimeLog.info("MANUAL_CONNECTION_APPLIED", {
			"host": _manual_server_host,
			"control_port": DEFAULT_CONTROL_PORT,
			"telemetry_port": DEFAULT_TELEMETRY_PORT,
		})
		_apply_target_host(_manual_server_host, DEFAULT_CONTROL_PORT, DEFAULT_TELEMETRY_PORT, true)
		return
	QuestRuntimeLog.info("AUTO_DISCOVERY_APPLY_REQUESTED", {
		"discovered_server_ip": _discovered_server_ip,
	})
	if _discovered_server_ip.is_empty():
		_set_auto_discovery_wait_state()
	else:
		_apply_target_host(_discovered_server_ip, _discovered_control_port, _discovered_telemetry_port, false)
	_emit_state_changed()


func _on_retry_connect_pressed() -> void:
	QuestRuntimeLog.info("CONNECTION_RETRY_REQUESTED", {
		"mode": _connection_mode,
		"manual_server_host": _manual_server_host,
		"discovered_server_ip": _discovered_server_ip,
	})
	_control_client.disconnect_from_server(true)
	_telemetry_sender.clear_target()
	if _connection_mode == CONNECTION_MODE_MANUAL:
		_on_apply_connection_pressed()
		return
	if _discovered_server_ip.is_empty():
		_set_auto_discovery_wait_state()
	else:
		_apply_target_host(_discovered_server_ip, _discovered_control_port, _discovered_telemetry_port, false)
	_emit_state_changed()


func _apply_target_host(host: String, control_port: int, telemetry_port: int, manual_override: bool) -> void:
	if host.is_empty():
		_connection_state.set_error("Server host is empty")
		QuestRuntimeLog.error("CONTROL_TARGET_REJECTED", {
			"reason": "empty_host",
			"manual_override": manual_override,
		})
		_emit_state_changed()
		return
	QuestRuntimeLog.info("CONTROL_TARGET_APPLIED", {
		"host": host,
		"control_port": control_port,
		"telemetry_port": telemetry_port,
		"manual_override": manual_override,
	})
	if manual_override:
		_connection_state.set_manual_override(host, control_port, telemetry_port)
	else:
		_connection_state.set_beacon_received(host, control_port, telemetry_port)
	_control_client.set_server_host(host, control_port)
	_telemetry_sender.set_target_host(host, telemetry_port)
	_update_connection_controls()
	_emit_state_changed()


func _set_auto_discovery_wait_state() -> void:
	var bind_error := int(_discovery_listener.get_bind_error())
	if bind_error != OK:
		_connection_state.set_error("Discovery listener failed to bind: %s" % error_string(bind_error))
		QuestRuntimeLog.error("AUTO_DISCOVERY_WAIT_FAILED", {
			"error_code": bind_error,
			"error": error_string(bind_error),
		})
		return
	QuestRuntimeLog.info("AUTO_DISCOVERY_WAITING", {})
	_connection_state.set_waiting_for_beacon()


func _update_connection_controls() -> void:
	if manual_server_host_label == null:
		return
	var manual_mode := _connection_mode == CONNECTION_MODE_MANUAL
	manual_server_host_label.visible = manual_mode
	manual_server_host_edit.visible = manual_mode
	manual_server_host_edit.editable = manual_mode
	apply_connection_button.text = "Apply Manual Host" if manual_mode else "Use Auto Discovery"
	retry_connect_button.disabled = manual_mode and manual_server_host_edit.text.strip_edges().is_empty()


func _emit_state_changed() -> void:
	connection_state_changed.emit(get_connection_state_snapshot())
	connection_diagnostics_changed.emit(get_runtime_diagnostics())


func _require_panel_node(quest_panel: Control, node_path: String) -> Node:
	var node := quest_panel.get_node_or_null(node_path)
	if node == null:
		QuestRuntimeLog.error("UI_BIND_MISSING_NODE", {
			"path": node_path,
			"error": "Quest panel missing node: %s" % node_path,
		})
	return node


func _has_bound_controls() -> bool:
	return connect_mode_select != null \
		and manual_server_host_label != null \
		and manual_server_host_edit != null \
		and apply_connection_button != null \
		and retry_connect_button != null \
		and status_label != null
