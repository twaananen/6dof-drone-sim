extends Node3D

const SessionProfile = preload("res://scripts/workflow/session_profile.gd")
const QuestConnectionState = preload("res://scripts/network/quest_connection_state.gd")
const OpenXRBootstrap = preload("res://scripts/xr/openxr_bootstrap.gd")

const DEFAULT_CONTROL_PORT := 9101
const DEFAULT_TELEMETRY_PORT := 9100
const CONNECTION_MODE_AUTO := "auto"
const CONNECTION_MODE_MANUAL := "manual"
const DIAGNOSTIC_PUSH_INTERVAL_USEC := 500000

@onready var controller_reader: Node = $ControllerReader
@onready var telemetry_sender: Node = $TelemetrySender
@onready var control_client: Node = $ControlClient
@onready var discovery_listener: Node = $DiscoveryListener
@onready var xr_camera: XRCamera3D = $XROrigin3D/XRCamera3D
@onready var ui_pivot: Node3D = $XROrigin3D/UiPivot
@onready var quest_ui_layer: Node = $XROrigin3D/UiPivot/QuestUiLayer
@onready var left_hand: XRController3D = $XROrigin3D/LeftHand
@onready var right_hand: XRController3D = $XROrigin3D/RightHand
@onready var left_fallback_mesh: MeshInstance3D = $XROrigin3D/LeftHand/FallbackMesh
@onready var right_fallback_mesh: MeshInstance3D = $XROrigin3D/RightHand/FallbackMesh

var connect_mode_select: OptionButton
var manual_server_host_label: Label
var manual_server_host_edit: LineEdit
var apply_connection_button: Button
var retry_connect_button: Button
var recenter_panel_button: Button
var preset_select: OptionButton
var template_select: OptionButton
var status_label: Label
var workflow_mode_select: OptionButton
var workflow_details_label: Label
var checklist_box: VBoxContainer
var stream_client_label: Label
var stream_client_select: OptionButton
var run_label_edit: LineEdit
var latency_budget_spin: SpinBox
var observed_latency_spin: SpinBox
var focus_loss_spin: SpinBox
var operator_note_edit: TextEdit
var apply_session_details_button: Button
var calibrate_button: Button
var recenter_button: Button
var snapshot_note_edit: TextEdit
var capture_snapshot_button: Button
var report_issue_button: Button
var export_report_button: Button
var sensitivity_slider: HSlider
var deadzone_slider: HSlider
var expo_slider: HSlider
var integrator_slider: HSlider
var output_preview_label: Label
var workflow_diagnostics_label: Label

var _active_template_name: String = ""
var _last_status: Dictionary = {}
var _session_profile: Dictionary = SessionProfile.new().to_dict()
var _updating_preset_select: bool = false
var _updating_workflow_select: bool = false
var _updating_stream_client_select: bool = false
var _updating_session_detail_controls: bool = false
var _updating_connection_mode_select: bool = false
var _connection_mode: String = CONNECTION_MODE_AUTO
var _manual_server_host: String = ""
var _discovered_server_ip: String = ""
var _discovered_control_port: int = DEFAULT_CONTROL_PORT
var _discovered_telemetry_port: int = DEFAULT_TELEMETRY_PORT
var _connection_state: QuestConnectionState = QuestConnectionState.new()
var _xr_bootstrap: OpenXRBootstrap = OpenXRBootstrap.new()
var _xr_diagnostics: Dictionary = {}
var _last_runtime_diagnostics_push_usec: int = 0


func _ready() -> void:
	_bind_ui_controls()
	_wire_ui_signals()
	control_client.connected.connect(_on_control_connected)
	control_client.disconnected.connect(_on_control_disconnected)
	control_client.message_received.connect(_on_control_message)
	control_client.connection_state_changed.connect(_on_control_connection_state_changed)
	discovery_listener.server_discovered.connect(_on_server_discovered)
	discovery_listener.bind_failed.connect(_on_discovery_bind_failed)

	_load_connection_modes()
	_load_presets(_session_profile.get("presets", []))
	_load_workflow_modes(_session_profile.get("available_modes", []))
	_load_stream_clients(_session_profile.get("stream_clients", []))
	_load_session_details()
	_rebuild_manual_check_controls()

	_connection_state.set_xr_starting()
	_xr_diagnostics = _xr_bootstrap.initialize(XRServer.find_interface("OpenXR"), get_viewport())
	if bool(_xr_diagnostics.get("ok", false)):
		_set_auto_discovery_wait_state()
	else:
		_connection_state.set_error(str(_xr_diagnostics.get("error", "OpenXR initialization failed")))

	_update_controller_visuals()
	_recenter_ui_panel()
	_update_workflow_controls()
	_update_status_label()


func _physics_process(_delta: float) -> void:
	telemetry_sender.send_state(controller_reader.read_state())
	_update_status_label()
	_maybe_push_runtime_diagnostics()


func _bind_ui_controls() -> void:
	var quest_panel := quest_ui_layer.call("get_scene_root") as Control
	if quest_panel == null:
		push_error("Quest UI layer did not provide a Control root")
		return

	var base_path := "Panel/Margin/Scroll/VBox/"
	status_label = quest_panel.get_node(base_path + "StatusLabel")
	connect_mode_select = quest_panel.get_node(base_path + "ConnectModeSelect")
	manual_server_host_label = quest_panel.get_node(base_path + "ManualServerHostLabel")
	manual_server_host_edit = quest_panel.get_node(base_path + "ManualServerHostEdit")
	apply_connection_button = quest_panel.get_node(base_path + "ConnectionButtons/ApplyConnectionButton")
	retry_connect_button = quest_panel.get_node(base_path + "ConnectionButtons/RetryConnectButton")
	recenter_panel_button = quest_panel.get_node(base_path + "ConnectionButtons/RecenterPanelButton")
	preset_select = quest_panel.get_node(base_path + "PresetSelect")
	template_select = quest_panel.get_node(base_path + "TemplateSelect")
	workflow_mode_select = quest_panel.get_node(base_path + "WorkflowModeSelect")
	workflow_details_label = quest_panel.get_node(base_path + "WorkflowDetailsLabel")
	checklist_box = quest_panel.get_node(base_path + "ChecklistBox")
	stream_client_label = quest_panel.get_node(base_path + "StreamClientLabel")
	stream_client_select = quest_panel.get_node(base_path + "StreamClientSelect")
	run_label_edit = quest_panel.get_node(base_path + "RunLabelEdit")
	latency_budget_spin = quest_panel.get_node(base_path + "LatencyBudgetSpin")
	observed_latency_spin = quest_panel.get_node(base_path + "ObservedLatencySpin")
	focus_loss_spin = quest_panel.get_node(base_path + "FocusLossSpin")
	operator_note_edit = quest_panel.get_node(base_path + "OperatorNoteEdit")
	apply_session_details_button = quest_panel.get_node(base_path + "ApplySessionDetailsButton")
	calibrate_button = quest_panel.get_node(base_path + "Buttons/CalibrateButton")
	recenter_button = quest_panel.get_node(base_path + "Buttons/RecenterButton")
	snapshot_note_edit = quest_panel.get_node(base_path + "SnapshotNoteEdit")
	capture_snapshot_button = quest_panel.get_node(base_path + "SnapshotButtons/CaptureSnapshotButton")
	report_issue_button = quest_panel.get_node(base_path + "SnapshotButtons/ReportIssueButton")
	export_report_button = quest_panel.get_node(base_path + "SnapshotButtons/ExportReportButton")
	sensitivity_slider = quest_panel.get_node(base_path + "Tuning/SensitivitySlider")
	deadzone_slider = quest_panel.get_node(base_path + "Tuning/DeadzoneSlider")
	expo_slider = quest_panel.get_node(base_path + "Tuning/ExpoSlider")
	integrator_slider = quest_panel.get_node(base_path + "Tuning/IntegratorSlider")
	output_preview_label = quest_panel.get_node(base_path + "OutputPreviewLabel")
	workflow_diagnostics_label = quest_panel.get_node(base_path + "WorkflowDiagnosticsLabel")


func _wire_ui_signals() -> void:
	calibrate_button.pressed.connect(func(): controller_reader.request_calibration())
	recenter_button.pressed.connect(func(): controller_reader.request_recenter())
	recenter_panel_button.pressed.connect(_recenter_ui_panel)
	connect_mode_select.item_selected.connect(_on_connect_mode_selected)
	manual_server_host_edit.text_changed.connect(func(_new_text: String): _update_connection_controls())
	apply_connection_button.pressed.connect(_on_apply_connection_pressed)
	retry_connect_button.pressed.connect(_on_retry_connect_pressed)
	preset_select.item_selected.connect(_on_preset_selected)
	template_select.item_selected.connect(_on_template_selected)
	workflow_mode_select.item_selected.connect(_on_workflow_mode_selected)
	stream_client_select.item_selected.connect(_on_stream_client_selected)
	apply_session_details_button.pressed.connect(_on_apply_session_details_pressed)
	sensitivity_slider.value_changed.connect(_on_tuning_changed)
	deadzone_slider.value_changed.connect(_on_tuning_changed)
	expo_slider.value_changed.connect(_on_tuning_changed)
	integrator_slider.value_changed.connect(_on_tuning_changed)
	capture_snapshot_button.pressed.connect(_on_capture_snapshot_pressed)
	report_issue_button.pressed.connect(_on_report_issue_pressed)
	export_report_button.pressed.connect(_on_export_report_pressed)


func _load_connection_modes() -> void:
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
	if _connection_mode == CONNECTION_MODE_AUTO:
		control_client.disconnect_from_server(true)
		telemetry_sender.clear_target()
		if _discovered_server_ip.is_empty():
			_set_auto_discovery_wait_state()
		else:
			_apply_target_host(_discovered_server_ip, _discovered_control_port, _discovered_telemetry_port, false)
	else:
		control_client.disconnect_from_server(true)
		telemetry_sender.clear_target()
		_connection_state.set_manual_override(_manual_server_host, DEFAULT_CONTROL_PORT, DEFAULT_TELEMETRY_PORT)
	_update_connection_controls()
	_update_status_label()


func _on_apply_connection_pressed() -> void:
	if _connection_mode == CONNECTION_MODE_MANUAL:
		_manual_server_host = manual_server_host_edit.text.strip_edges()
		if _manual_server_host.is_empty():
			_connection_state.set_error("Enter a manual server IP before connecting")
			_update_status_label()
			return
		_apply_target_host(_manual_server_host, DEFAULT_CONTROL_PORT, DEFAULT_TELEMETRY_PORT, true)
		return

	if _discovered_server_ip.is_empty():
		_set_auto_discovery_wait_state()
	else:
		_apply_target_host(_discovered_server_ip, _discovered_control_port, _discovered_telemetry_port, false)
	_update_status_label()


func _on_retry_connect_pressed() -> void:
	control_client.disconnect_from_server(true)
	telemetry_sender.clear_target()
	if _connection_mode == CONNECTION_MODE_MANUAL:
		_on_apply_connection_pressed()
		return
	if _discovered_server_ip.is_empty():
		_set_auto_discovery_wait_state()
	else:
		_apply_target_host(_discovered_server_ip, _discovered_control_port, _discovered_telemetry_port, false)
	_update_status_label()


func _on_server_discovered(ip: String, control_port: int, telemetry_port: int) -> void:
	_discovered_server_ip = ip
	_discovered_control_port = control_port
	_discovered_telemetry_port = telemetry_port
	if _connection_mode == CONNECTION_MODE_AUTO:
		_apply_target_host(ip, control_port, telemetry_port, false)
		return
	_update_status_label()


func _apply_target_host(host: String, control_port: int, telemetry_port: int, manual_override: bool) -> void:
	if host.is_empty():
		_connection_state.set_error("Server host is empty")
		return
	if manual_override:
		_connection_state.set_manual_override(host, control_port, telemetry_port)
	else:
		_connection_state.set_beacon_received(host, control_port, telemetry_port)
	control_client.set_server_host(host, control_port)
	telemetry_sender.set_target_host(host, telemetry_port)
	_update_connection_controls()
	_update_status_label()
	_push_runtime_diagnostics(true)


func _on_control_connection_state_changed(state: String, error_code: int) -> void:
	match state:
		"connecting":
			_connection_state.set_tcp_connecting(
				str(control_client.server_host),
				int(control_client.server_port),
				int(telemetry_sender.target_port)
			)
		"connected":
			_connection_state.set_tcp_connected(
				str(control_client.server_host),
				int(control_client.server_port),
				int(telemetry_sender.target_port)
			)
		"unconfigured":
			if _connection_mode == CONNECTION_MODE_MANUAL:
				_connection_state.set_manual_override(_manual_server_host, DEFAULT_CONTROL_PORT, DEFAULT_TELEMETRY_PORT)
			else:
				_set_auto_discovery_wait_state()
		"error":
			_connection_state.set_error("Control connection error: %s" % error_string(error_code))
		_:
			if _connection_mode == CONNECTION_MODE_MANUAL:
				_connection_state.set_manual_override(_manual_server_host, DEFAULT_CONTROL_PORT, DEFAULT_TELEMETRY_PORT)
			elif _discovered_server_ip.is_empty():
				_set_auto_discovery_wait_state()
			else:
				_connection_state.set_beacon_received(_discovered_server_ip, _discovered_control_port, _discovered_telemetry_port)
	_update_status_label()
	_push_runtime_diagnostics(true)


func _on_discovery_bind_failed(error_code: int) -> void:
	if _connection_mode == CONNECTION_MODE_AUTO:
		_connection_state.set_error("Discovery listener failed to bind: %s" % error_string(error_code))
	_update_status_label()


func _set_auto_discovery_wait_state() -> void:
	var bind_error := int(discovery_listener.get_bind_error())
	if bind_error != OK:
		_connection_state.set_error("Discovery listener failed to bind: %s" % error_string(bind_error))
		return
	_connection_state.set_waiting_for_beacon()


func _update_controller_visuals() -> void:
	var render_models_enabled := bool(ProjectSettings.get_setting("xr/openxr/extensions/meta/render_model", false))
	var render_models_available := render_models_enabled and bool(_xr_diagnostics.get("render_model_plugin_available", false))
	if render_models_available:
		_ensure_render_model(left_hand, false)
		_ensure_render_model(right_hand, true)
	left_fallback_mesh.visible = not render_models_available
	right_fallback_mesh.visible = not render_models_available


func _ensure_render_model(controller: XRController3D, use_alt_render_model: bool) -> void:
	if controller.get_node_or_null("ControllerRenderModel") != null:
		return
	if not ClassDB.class_exists("OpenXRFbRenderModel"):
		return
	var render_model := ClassDB.instantiate("OpenXRFbRenderModel") as Node
	if render_model == null:
		return
	render_model.name = "ControllerRenderModel"
	if use_alt_render_model:
		render_model.set("render_model_type", 1)
	controller.add_child(render_model)
	render_model.owner = self


func _recenter_ui_panel() -> void:
	var forward := -xr_camera.global_transform.basis.z
	forward.y = 0.0
	if is_zero_approx(forward.length_squared()):
		forward = Vector3(0.0, 0.0, -1.0)
	else:
		forward = forward.normalized()
	ui_pivot.global_position = xr_camera.global_position + (forward * 1.1) + Vector3(0.0, -0.12, 0.0)
	ui_pivot.look_at(xr_camera.global_position, Vector3.UP, true)


func _on_control_connected() -> void:
	control_client.send_message({
		"type": "hello",
		"client": "quest",
		"diagnostics": _build_runtime_diagnostics(),
	})
	_update_workflow_controls()
	_push_runtime_diagnostics(true)


func _on_control_disconnected() -> void:
	_last_status = {}
	_update_workflow_controls()
	_update_status_label()


func _on_control_message(message: Dictionary) -> void:
	match str(message.get("type", "")):
		"template_catalog":
			_load_catalog(message.get("templates", []))
		"session_profile":
			_connection_state.set_profile_synced()
			_session_profile = message.get("profile", {})
			_load_presets(_session_profile.get("presets", []))
			_load_workflow_modes(_session_profile.get("available_modes", []))
			_load_stream_clients(_session_profile.get("stream_clients", []))
			_load_session_details()
			_select_preset(str(_session_profile.get("preset_id", SessionProfile.PRESET_PASSTHROUGH_BASELINE)))
			_select_workflow_mode(str(_session_profile.get("mode", SessionProfile.MODE_PASSTHROUGH_STANDALONE)))
			_select_stream_client(str(_session_profile.get("stream_client", SessionProfile.STREAM_CLIENT_NONE)))
			_rebuild_manual_check_controls()
			_update_workflow_controls()
			_push_runtime_diagnostics(true)
		"active_template":
			_active_template_name = str(message.get("template_name", ""))
		"status":
			_last_status = message
			if _active_template_name.is_empty():
				_active_template_name = str(message.get("template_name", ""))


func _load_presets(presets: Array) -> void:
	_updating_preset_select = true
	preset_select.clear()
	if presets.is_empty():
		presets = SessionProfile.available_presets()
	for preset_info in presets:
		var value: String = str(preset_info.get("value", ""))
		var label: String = str(preset_info.get("label", value))
		preset_select.add_item(label)
		preset_select.set_item_metadata(preset_select.item_count - 1, value)
	_updating_preset_select = false


func _load_catalog(templates: Array) -> void:
	var previous: String = _active_template_name
	template_select.clear()
	for item in templates:
		template_select.add_item(str(item))
	if previous.is_empty() and template_select.item_count > 0:
		template_select.select(0)
	else:
		for index in range(template_select.item_count):
			if template_select.get_item_text(index) == previous:
				template_select.select(index)
				break


func _on_preset_selected(index: int) -> void:
	if _updating_preset_select:
		return
	var preset_id: Variant = preset_select.get_item_metadata(index)
	control_client.send_message({
		"type": "set_session_preset",
		"preset_id": str(preset_id),
	})


func _on_template_selected(index: int) -> void:
	control_client.send_message({
		"type": "select_template",
		"template_name": template_select.get_item_text(index),
	})


func _on_workflow_mode_selected(index: int) -> void:
	if _updating_workflow_select:
		return
	var mode: Variant = workflow_mode_select.get_item_metadata(index)
	control_client.send_message({
		"type": "set_session_mode",
		"mode": str(mode),
	})


func _on_stream_client_selected(index: int) -> void:
	if _updating_stream_client_select:
		return
	var stream_client: Variant = stream_client_select.get_item_metadata(index)
	control_client.send_message({
		"type": "set_stream_client",
		"stream_client": str(stream_client),
	})


func _on_apply_session_details_pressed() -> void:
	if _updating_session_detail_controls:
		return
	control_client.send_message({
		"type": "set_session_details",
		"run_label": run_label_edit.text.strip_edges(),
		"latency_budget_ms": int(round(latency_budget_spin.value)),
		"observed_latency_ms": int(round(observed_latency_spin.value)),
		"focus_loss_events": int(round(focus_loss_spin.value)),
		"operator_note": operator_note_edit.text.strip_edges(),
	})


func _on_manual_check_toggled(pressed: bool, check_id: String) -> void:
	var manual_checks: Dictionary = _session_profile.get("manual_checks", {}).duplicate(true)
	manual_checks[check_id] = pressed
	_session_profile["manual_checks"] = manual_checks
	var completed := 0
	var manual_check_items: Array = []
	for check_info in _session_profile.get("manual_check_items", []):
		var item: Dictionary = check_info.duplicate(true)
		if str(item.get("id", "")) == check_id:
			item["checked"] = pressed
		if bool(item.get("checked", false)):
			completed += 1
		manual_check_items.append(item)
	_session_profile["manual_check_items"] = manual_check_items
	if manual_check_items.size() > 0:
		_session_profile["manual_check_summary"] = "%d/%d workflow checks complete" % [
			completed,
			manual_check_items.size(),
		]
	else:
		_session_profile["manual_check_summary"] = ""
	control_client.send_message({
		"type": "set_manual_check",
		"check_id": check_id,
		"checked": pressed,
	})
	_rebuild_manual_check_controls()
	_update_status_label()


func _on_tuning_changed(_value: float) -> void:
	control_client.send_message({
		"type": "apply_tuning",
		"settings": {
			"sensitivity": sensitivity_slider.value,
			"deadzone": deadzone_slider.value,
			"expo": expo_slider.value,
			"integrator_gain": integrator_slider.value,
		},
	})


func _update_status_label() -> void:
	var mode_label := str(_session_profile.get("mode_label", "Passthrough Standalone"))
	var stream_client_enabled := bool(_session_profile.get("stream_client_enabled", false))
	var run_label := str(_session_profile.get("run_label", ""))
	var preset_label := str(_session_profile.get("preset_label", ""))
	var runtime_diagnostics := _build_runtime_diagnostics()
	var current_host := str(runtime_diagnostics.get("control_target_host", ""))
	if current_host.is_empty():
		current_host = _discovered_server_ip if not _discovered_server_ip.is_empty() else "searching..."
	var lines := PackedStringArray([
		"XR: %s" % str(runtime_diagnostics.get("xr_state", "xr_starting")),
		"Connect: %s (%s)" % [
			str(runtime_diagnostics.get("discovery_state", QuestConnectionState.STATE_XR_STARTING)),
			_connection_mode,
		],
		"Server: %s" % current_host,
		"Control: %s" % control_client.get_connection_state(),
		"Discovery: %d beacon(s), %d invalid" % [
			int(runtime_diagnostics.get("beacon_packets_received", 0)),
			int(runtime_diagnostics.get("discovery_invalid_packets", 0)),
		],
		"Telemetry: %d sent / %d errors" % [
			int(runtime_diagnostics.get("telemetry_packets_sent", 0)),
			int(runtime_diagnostics.get("telemetry_send_errors", 0)),
		],
		"Workflow: %s" % mode_label,
		"Preset: %s" % preset_label,
		"Template: %s" % _active_template_name,
		"Failsafe: %s" % ("active" if _last_status.get("failsafe_active", true) else "clear"),
		"Backend: %s" % ("ready" if _last_status.get("backend_available", false) else "offline"),
		"Packets: %s received / %s dropped" % [
			str(_last_status.get("packets_received", 0)),
			str(_last_status.get("packets_dropped", 0)),
		],
	])
	var xr_error := str(runtime_diagnostics.get("xr_error", ""))
	if not xr_error.is_empty():
		lines.append("XR Error: %s" % xr_error)
	var discovery_error := str(runtime_diagnostics.get("discovery_error", ""))
	if not discovery_error.is_empty():
		lines.append("Connect Error: %s" % discovery_error)
	if _connection_mode == CONNECTION_MODE_MANUAL and not _manual_server_host.is_empty():
		lines.append("Manual Host: %s" % _manual_server_host)
	if not run_label.is_empty():
		lines.append("Run: %s" % run_label)
	if stream_client_enabled:
		lines.append("Stream App: %s" % str(_session_profile.get("stream_client_label", "Choose Stream App")))
	var latency_budget_ms := int(_session_profile.get("latency_budget_ms", 0))
	if latency_budget_ms > 0:
		lines.append("Latency Budget: <= %d ms" % latency_budget_ms)
	var observed_latency_ms := int(_session_profile.get("observed_latency_ms", 0))
	if observed_latency_ms > 0:
		lines.append("Observed Latency: %d ms" % observed_latency_ms)
	var focus_loss_events := int(_session_profile.get("focus_loss_events", 0))
	if focus_loss_events > 0 or str(_session_profile.get("mode", "")) == SessionProfile.MODE_EXPERIMENTAL_STREAM:
		lines.append("Focus Loss Events: %d" % focus_loss_events)
	var operator_note := str(_session_profile.get("operator_note", ""))
	if not operator_note.is_empty():
		lines.append("Operator Note: %s" % operator_note)
	var manual_check_summary := str(_session_profile.get("manual_check_summary", ""))
	if not manual_check_summary.is_empty():
		lines.append("Manual Checks: %s" % manual_check_summary)
	var baseline_comparison: Dictionary = _last_status.get("baseline_comparison", {})
	var comparison_summary := str(baseline_comparison.get("summary", ""))
	if not comparison_summary.is_empty():
		lines.append("Compare: %s" % comparison_summary)
	var recent_snapshots: Array = _last_status.get("recent_run_snapshots", [])
	if not recent_snapshots.is_empty():
		var latest_snapshot: Dictionary = recent_snapshots[0]
		lines.append("Last Snapshot: %s (%s)" % [
			_snapshot_kind_label(str(latest_snapshot.get("kind", "checkpoint"))),
			str(latest_snapshot.get("captured_at_text", "")),
		])
	var last_report_export: Dictionary = _last_status.get("last_report_export", {})
	var export_summary := str(last_report_export.get("summary", ""))
	if not export_summary.is_empty():
		lines.append("Last Report: %s" % str(last_report_export.get("exported_at_text", "")))
		lines.append("Report Status: %s" % export_summary)
	var playbook: Dictionary = _last_status.get("session_playbook", {})
	if not playbook.is_empty():
		lines.append("Phase: %s" % str(playbook.get("phase_label", "Setup")))
		var next_actions: Array = playbook.get("next_actions", [])
		for index in range(mini(next_actions.size(), 2)):
			lines.append("Next: %s" % str(next_actions[index]))
		var debug_actions: Array = playbook.get("debug_actions", [])
		if not debug_actions.is_empty():
			lines.append("Debug: %s" % str(debug_actions[0]))
	status_label.text = "\n".join(lines)
	workflow_details_label.text = _format_session_playbook(playbook)
	var outputs: Dictionary = _last_status.get("output_summary", {})
	output_preview_label.text = "Outputs: T %.2f | Y %.2f | P %.2f | R %.2f" % [
		float(outputs.get("throttle", 0.0)),
		float(outputs.get("yaw", 0.0)),
		float(outputs.get("pitch", 0.0)),
		float(outputs.get("roll", 0.0)),
	]
	workflow_diagnostics_label.text = _format_session_diagnostics(_last_status.get("session_diagnostics", {}))


func _build_runtime_diagnostics() -> Dictionary:
	var diagnostics := _connection_state.to_dict()
	diagnostics["connection_mode"] = _connection_mode
	diagnostics["manual_server_host"] = _manual_server_host
	diagnostics["discovery_state"] = _connection_state.state
	diagnostics["discovery_error"] = _connection_state.last_error
	diagnostics["xr_state"] = str(_xr_diagnostics.get("state", OpenXRBootstrap.STATE_XR_STARTING))
	diagnostics["xr_error"] = str(_xr_diagnostics.get("error", ""))
	diagnostics["xr_alpha_blend_supported"] = bool(_xr_diagnostics.get("alpha_blend_supported", false))
	diagnostics["xr_passthrough_plugin_available"] = bool(_xr_diagnostics.get("passthrough_plugin_available", false))
	diagnostics["xr_render_model_plugin_available"] = bool(_xr_diagnostics.get("render_model_plugin_available", false))
	diagnostics["xr_passthrough_extension_available"] = bool(_xr_diagnostics.get("passthrough_extension_available", false))
	var discovery: Dictionary = discovery_listener.get_diagnostics()
	diagnostics.merge(discovery, true)
	diagnostics["beacon_packets_received"] = int(discovery.get("discovery_packets_received", 0))
	diagnostics.merge(control_client.get_diagnostics(), true)
	diagnostics.merge(telemetry_sender.get_diagnostics(), true)
	diagnostics["active_template_name"] = _active_template_name
	return diagnostics


func _maybe_push_runtime_diagnostics() -> void:
	if not control_client.is_socket_connected():
		return
	var now_usec := Time.get_ticks_usec()
	if now_usec - _last_runtime_diagnostics_push_usec < DIAGNOSTIC_PUSH_INTERVAL_USEC:
		return
	_push_runtime_diagnostics(false)


func _push_runtime_diagnostics(force: bool) -> void:
	if not force and not control_client.is_socket_connected():
		return
	if not control_client.is_socket_connected():
		return
	_last_runtime_diagnostics_push_usec = Time.get_ticks_usec()
	control_client.send_message({
		"type": "quest_diagnostics",
		"diagnostics": _build_runtime_diagnostics(),
	})


func _load_workflow_modes(modes: Array) -> void:
	_updating_workflow_select = true
	workflow_mode_select.clear()
	if modes.is_empty():
		modes = SessionProfile.available_modes()
	for mode_info in modes:
		var value: String = str(mode_info.get("value", ""))
		var label: String = str(mode_info.get("label", value))
		if mode_info.get("experimental", false):
			label += " [exp]"
		workflow_mode_select.add_item(label)
		workflow_mode_select.set_item_metadata(workflow_mode_select.item_count - 1, value)
	_updating_workflow_select = false


func _load_stream_clients(stream_clients: Array) -> void:
	_updating_stream_client_select = true
	stream_client_select.clear()
	if stream_clients.is_empty():
		stream_clients = SessionProfile.available_stream_clients()
	for stream_client_info in stream_clients:
		var value: String = str(stream_client_info.get("value", ""))
		var label: String = str(stream_client_info.get("label", value))
		stream_client_select.add_item(label)
		stream_client_select.set_item_metadata(stream_client_select.item_count - 1, value)
	_updating_stream_client_select = false


func _select_workflow_mode(mode: String) -> void:
	_updating_workflow_select = true
	for index in range(workflow_mode_select.item_count):
		if str(workflow_mode_select.get_item_metadata(index)) == mode:
			workflow_mode_select.select(index)
			break
	_updating_workflow_select = false


func _select_stream_client(stream_client: String) -> void:
	_updating_stream_client_select = true
	for index in range(stream_client_select.item_count):
		if str(stream_client_select.get_item_metadata(index)) == stream_client:
			stream_client_select.select(index)
			break
	_updating_stream_client_select = false


func _load_session_details() -> void:
	_updating_session_detail_controls = true
	run_label_edit.text = str(_session_profile.get("run_label", ""))
	latency_budget_spin.value = int(_session_profile.get("latency_budget_ms", 0))
	observed_latency_spin.value = int(_session_profile.get("observed_latency_ms", 0))
	focus_loss_spin.value = int(_session_profile.get("focus_loss_events", 0))
	operator_note_edit.text = str(_session_profile.get("operator_note", ""))
	_updating_session_detail_controls = false


func _select_preset(preset_id: String) -> void:
	_updating_preset_select = true
	for index in range(preset_select.item_count):
		if str(preset_select.get_item_metadata(index)) == preset_id:
			preset_select.select(index)
			break
	_updating_preset_select = false


func _rebuild_manual_check_controls() -> void:
	for child in checklist_box.get_children():
		child.queue_free()
	for check_info in _session_profile.get("manual_check_items", []):
		var check_id := str(check_info.get("id", ""))
		var checkbox := CheckBox.new()
		checkbox.text = str(check_info.get("label", ""))
		checkbox.tooltip_text = str(check_info.get("detail", ""))
		checkbox.button_pressed = bool(check_info.get("checked", false))
		checkbox.disabled = not control_client.is_socket_connected()
		checkbox.toggled.connect(_on_manual_check_toggled.bind(check_id))
		checklist_box.add_child(checkbox)


func _update_connection_controls() -> void:
	var manual_mode := _connection_mode == CONNECTION_MODE_MANUAL
	manual_server_host_label.visible = manual_mode
	manual_server_host_edit.visible = manual_mode
	manual_server_host_edit.editable = manual_mode
	apply_connection_button.text = "Apply Manual Host" if manual_mode else "Use Auto Discovery"
	retry_connect_button.disabled = manual_mode and manual_server_host_edit.text.strip_edges().is_empty()


func _update_workflow_controls() -> void:
	_update_connection_controls()
	var stream_client_enabled := bool(_session_profile.get("stream_client_enabled", false))
	stream_client_label.visible = stream_client_enabled
	stream_client_select.visible = stream_client_enabled
	stream_client_select.disabled = (not stream_client_enabled) or (not control_client.is_socket_connected())
	preset_select.disabled = not control_client.is_socket_connected()
	workflow_mode_select.disabled = not control_client.is_socket_connected()
	run_label_edit.editable = control_client.is_socket_connected()
	latency_budget_spin.editable = control_client.is_socket_connected()
	observed_latency_spin.editable = control_client.is_socket_connected()
	focus_loss_spin.editable = control_client.is_socket_connected()
	operator_note_edit.editable = control_client.is_socket_connected()
	apply_session_details_button.disabled = not control_client.is_socket_connected()
	snapshot_note_edit.editable = control_client.is_socket_connected()
	capture_snapshot_button.disabled = not control_client.is_socket_connected()
	report_issue_button.disabled = not control_client.is_socket_connected()
	export_report_button.disabled = not control_client.is_socket_connected()
	for child in checklist_box.get_children():
		if child is CheckBox:
			child.disabled = not control_client.is_socket_connected()


func _format_session_diagnostics(diagnostics: Dictionary) -> String:
	var lines := PackedStringArray()
	if diagnostics.is_empty():
		lines.append("Checklist: waiting for desktop status.")
	else:
		var summary: String = str(diagnostics.get("summary", ""))
		if not summary.is_empty():
			lines.append("Checklist: %s" % summary)
		for item in diagnostics.get("items", []):
			var state := str(item.get("state", "ready"))
			var prefix := "OK"
			if state == "warning":
				prefix = "Blocker"
			elif state == "attention":
				prefix = "Check"
			lines.append("%s: %s" % [prefix, str(item.get("label", ""))])
	var runtime_diagnostics := _build_runtime_diagnostics()
	lines.append("Quest XR: %s" % str(runtime_diagnostics.get("xr_state", "xr_starting")))
	lines.append("Quest Connect: %s" % str(runtime_diagnostics.get("discovery_state", QuestConnectionState.STATE_XR_STARTING)))
	var connect_error := str(runtime_diagnostics.get("discovery_error", ""))
	if not connect_error.is_empty():
		lines.append("Quest Error: %s" % connect_error)
	var baseline_comparison: Dictionary = _last_status.get("baseline_comparison", {})
	var comparison_summary := str(baseline_comparison.get("summary", ""))
	if not comparison_summary.is_empty():
		lines.append("Compare: %s" % comparison_summary)
		var recommendations: Array = baseline_comparison.get("recommendations", [])
		if not recommendations.is_empty():
			lines.append("Compare Next: %s" % str(recommendations[0]))
	var recent_snapshots: Array = _last_status.get("recent_run_snapshots", [])
	if not recent_snapshots.is_empty():
		lines.append("Recent Snapshots:")
		for snapshot in recent_snapshots:
			lines.append(_format_recent_snapshot(snapshot))
	return "\n".join(lines)


func _format_session_playbook(playbook: Dictionary) -> String:
	var fallback_hint := str(_session_profile.get("workflow_hint", ""))
	if playbook.is_empty():
		return fallback_hint
	var lines := PackedStringArray()
	var headline := str(playbook.get("headline", ""))
	if not headline.is_empty():
		lines.append(headline)
	var summary := str(playbook.get("summary", ""))
	if not summary.is_empty():
		lines.append(summary)
	var next_actions: Array = playbook.get("next_actions", [])
	for index in range(mini(next_actions.size(), 3)):
		lines.append("Next: %s" % str(next_actions[index]))
	var debug_actions: Array = playbook.get("debug_actions", [])
	if not debug_actions.is_empty():
		lines.append("Debug: %s" % str(debug_actions[0]))
	if not fallback_hint.is_empty():
		lines.append("Hint: %s" % fallback_hint)
	return "\n".join(lines)


func _on_capture_snapshot_pressed() -> void:
	var severity := str(_last_status.get("session_diagnostics", {}).get("severity", "attention"))
	var kind := "checkpoint"
	if severity == "ready":
		kind = "ready"
	control_client.send_message({
		"type": "capture_run_snapshot",
		"kind": kind,
		"origin": "quest",
		"note": snapshot_note_edit.text.strip_edges(),
	})
	snapshot_note_edit.clear()


func _on_report_issue_pressed() -> void:
	control_client.send_message({
		"type": "capture_run_snapshot",
		"kind": "issue",
		"origin": "quest",
		"note": snapshot_note_edit.text.strip_edges(),
	})
	snapshot_note_edit.clear()


func _on_export_report_pressed() -> void:
	control_client.send_message({
		"type": "export_session_report",
		"note": snapshot_note_edit.text.strip_edges(),
	})
	snapshot_note_edit.clear()


func _format_recent_snapshot(snapshot: Dictionary) -> String:
	return "%s %s | %s" % [
		_snapshot_kind_label(str(snapshot.get("kind", "checkpoint"))),
		str(snapshot.get("captured_at_text", "")),
		_format_snapshot_summary(snapshot),
	]


func _format_snapshot_summary(snapshot: Dictionary) -> String:
	var summary := str(snapshot.get("diagnostics_summary", ""))
	var observed_latency_ms := int(snapshot.get("observed_latency_ms", 0))
	if observed_latency_ms > 0:
		summary = "%s | %d ms" % [summary, observed_latency_ms] if not summary.is_empty() else "%d ms" % observed_latency_ms
	var focus_loss_events := int(snapshot.get("focus_loss_events", 0))
	if focus_loss_events > 0:
		summary = "%s | focus %d" % [summary, focus_loss_events] if not summary.is_empty() else "focus %d" % focus_loss_events
	return summary


func _snapshot_kind_label(kind: String) -> String:
	match kind:
		"ready":
			return "READY"
		"issue":
			return "ISSUE"
		_:
			return "CHECKPOINT"
