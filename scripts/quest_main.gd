extends Node3D

const SessionProfile = preload("res://scripts/workflow/session_profile.gd")
const QuestConnectionState = preload("res://scripts/network/quest_connection_state.gd")
const OpenXRBootstrap = preload("res://scripts/xr/openxr_bootstrap.gd")
const PanelPositionStore = preload("res://scripts/ui/panel_position_store.gd")

const PANEL_KEY_FLIGHT := "flight"
const PANEL_KEY_CONNECTION := "connection"
const PANEL_KEY_SESSION := "session"
const PANEL_KEY_TUTORIAL := "tutorial"

const DEFAULT_CONTROL_PORT := 9101
const DEFAULT_TELEMETRY_PORT := 9100
const CONNECTION_MODE_AUTO := "auto"
const CONNECTION_MODE_MANUAL := "manual"
const DIAGNOSTIC_PUSH_INTERVAL_USEC := 500000
const POSE_SNAPSHOT_INTERVAL_MSEC := 1000

@onready var controller_reader: Node = $ControllerReader
@onready var telemetry_sender: Node = $TelemetrySender
@onready var control_client: Node = $ControlClient
@onready var discovery_listener: Node = $DiscoveryListener
@onready var world_environment: WorldEnvironment = $WorldEnvironment
@onready var xr_camera: XRCamera3D = $XROrigin3D/XRCamera3D
@onready var ui_pivot: Node3D = $XROrigin3D/QuestUiLayer
@onready var quest_ui_layer: Node = $XROrigin3D/QuestUiLayer
@onready var tutorial_ui_layer: Node3D = get_node_or_null("XROrigin3D/TutorialUiLayer") as Node3D
@onready var connection_layer: Node3D = get_node_or_null("XROrigin3D/QuestConnectionLayer") as Node3D
@onready var session_layer: Node3D = get_node_or_null("XROrigin3D/QuestSessionLayer") as Node3D
@onready var left_hand: XRController3D = $XROrigin3D/LeftHand
@onready var right_hand: XRController3D = $XROrigin3D/RightHand
@onready var left_fallback_mesh: MeshInstance3D = $XROrigin3D/LeftHand/FallbackMesh
@onready var right_fallback_mesh: MeshInstance3D = $XROrigin3D/RightHand/FallbackMesh
@onready var right_origin_indicator: Node3D = get_node_or_null("XROrigin3D/RightOriginIndicator") as Node3D

var connect_mode_select: OptionButton
var manual_server_host_label: Label
var manual_server_host_edit: LineEdit
var apply_connection_button: Button
var retry_connect_button: Button
var recenter_panel_button: Button
var show_tutorial_button: Button
var passthrough_toggle: BaseButton
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
var hide_tutorial_button: Button
var show_connection_button: Button
var show_session_button: Button

var _active_template_name: String = ""
var _last_status: Dictionary = {}
var _last_local_controller_state: Dictionary = {}
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
var _updating_passthrough_toggle: bool = false
var _xr_interface: XRInterface
var _panel_recentering_connected: bool = false
var _panel_position_store := PanelPositionStore.new()
var _managed_panels: Dictionary = {}
var _last_pose_snapshot_msec: int = 0
var _suppress_origin_indicator_until_release: bool = false


func _register_panel(key: String, node: Node3D) -> void:
	_managed_panels[key] = {
		"node": node,
		"default_offset": node.position - xr_camera.position,
	}
	if node.has_signal("manipulation_ended"):
		node.manipulation_ended.connect(func(): _save_panel_position(node, key))


func _ready() -> void:
	_log_boot("READY_BEGIN", {
		"scene": "quest_main",
	})
	_register_panel(PANEL_KEY_FLIGHT, ui_pivot)
	if connection_layer != null:
		_register_panel(PANEL_KEY_CONNECTION, connection_layer)
	if session_layer != null:
		_register_panel(PANEL_KEY_SESSION, session_layer)
	if tutorial_ui_layer != null:
		_register_panel(PANEL_KEY_TUTORIAL, tutorial_ui_layer)
	if not _bind_ui_controls():
		_log_error("QUEST_READY_ABORTED", {
			"reason": "ui_bind_failed",
		})
		return
	_wire_ui_signals()
	_log_boot("UI_SIGNALS_BOUND", {})
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
	_log_boot("XR_INIT_BEGIN", {})
	_xr_bootstrap.world_environment = world_environment
	_xr_bootstrap.prefer_passthrough_on_startup = true
	_xr_bootstrap.fallback_to_opaque_on_passthrough_failure = true
	_xr_diagnostics = _xr_bootstrap.initialize(XRServer.find_interface("OpenXR"), get_viewport())
	_xr_interface = XRServer.find_interface("OpenXR")
	if bool(_xr_diagnostics.get("ok", false)):
		_log_boot("XR_INIT_OK", {
			"passthrough_enabled": bool(_xr_diagnostics.get("passthrough_enabled", false)),
			"display_refresh_rate": float(_xr_diagnostics.get("display_refresh_rate", 0.0)),
		})
		_schedule_startup_recenter()
		_set_auto_discovery_wait_state()
	else:
		var xr_error := str(_xr_diagnostics.get("error", "OpenXR initialization failed"))
		_connection_state.set_error(xr_error)
		_log_error("XR_INIT_FAILED", {
			"error": xr_error,
		})

	_update_controller_visuals()
	_log_boot("CONTROLLER_VISUALS_UPDATED", {
		"render_model_plugin_available": bool(_xr_diagnostics.get("render_model_plugin_available", false)),
	})
	_sync_passthrough_toggle()
	_log_boot("PASSTHROUGH_TOGGLE_SYNCED", {
		"enabled": bool(_xr_diagnostics.get("passthrough_enabled", false)),
		"toggle_disabled": passthrough_toggle.disabled,
	})
	_update_workflow_controls()
	_update_status_label()
	_log_boot("READY_COMPLETE", {
		"xr_state": str(_xr_diagnostics.get("state", OpenXRBootstrap.STATE_XR_STARTING)),
		"discovery_state": _connection_state.state,
	})


func _physics_process(_delta: float) -> void:
	var state: Dictionary = controller_reader.read_state()
	_last_local_controller_state = state.duplicate(true)
	telemetry_sender.send_state(state)
	_sync_flight_origin_indicator(state)
	_maybe_log_pose_snapshot(state)
	_update_status_label()
	_maybe_push_runtime_diagnostics()


func _bind_ui_controls() -> bool:
	_log_boot("UI_BIND_BEGIN", {})
	if not _bind_flight_controls():
		return false
	if not _bind_connection_controls():
		return false
	if not _bind_session_controls():
		return false
	if tutorial_ui_layer != null:
		var tutorial_panel := tutorial_ui_layer.call("get_scene_root") as Control
		if tutorial_panel == null:
			_log_error("UI_BIND_FAILED", {
				"error": "Tutorial UI layer did not provide a Control root",
			})
			return false
		hide_tutorial_button = _require_panel_node(tutorial_panel, "Panel/Margin/Scroll/VBox/HideTutorialButton") as Button
	if not _has_bound_ui_controls():
		_log_error("UI_BIND_FAILED", {
			"error": "Panel controls missing",
		})
		return false
	_log_boot("UI_BIND_OK", {})
	return true


func _bind_flight_controls() -> bool:
	var panel := quest_ui_layer.call("get_scene_root") as Control
	if panel == null:
		_log_error("UI_BIND_FAILED", {"error": "Flight panel root missing"})
		return false
	var base_path := "Panel/Margin/Scroll/VBox/"
	passthrough_toggle = _require_panel_node(panel, base_path + "PassthroughToggle") as BaseButton
	template_select = _require_panel_node(panel, base_path + "TemplateSelect") as OptionButton
	sensitivity_slider = _require_panel_node(panel, base_path + "Tuning/SensitivitySlider") as HSlider
	deadzone_slider = _require_panel_node(panel, base_path + "Tuning/DeadzoneSlider") as HSlider
	expo_slider = _require_panel_node(panel, base_path + "Tuning/ExpoSlider") as HSlider
	integrator_slider = _require_panel_node(panel, base_path + "Tuning/IntegratorSlider") as HSlider
	calibrate_button = _require_panel_node(panel, base_path + "Buttons/CalibrateButton") as Button
	recenter_button = _require_panel_node(panel, base_path + "Buttons/RecenterButton") as Button
	output_preview_label = _require_panel_node(panel, base_path + "OutputPreviewLabel") as Label
	show_connection_button = _require_panel_node(panel, base_path + "NavigationButtons/ShowConnectionButton") as Button
	show_session_button = _require_panel_node(panel, base_path + "NavigationButtons/ShowSessionButton") as Button
	recenter_panel_button = _require_panel_node(panel, base_path + "PanelButtons/RecenterPanelButton") as Button
	show_tutorial_button = _require_panel_node(panel, base_path + "PanelButtons/ShowTutorialButton") as Button
	return true


func _bind_connection_controls() -> bool:
	if connection_layer == null:
		return true
	var panel := connection_layer.call("get_scene_root") as Control
	if panel == null:
		_log_error("UI_BIND_FAILED", {"error": "Connection panel root missing"})
		return false
	var base_path := "Panel/Margin/Scroll/VBox/"
	connect_mode_select = _require_panel_node(panel, base_path + "ConnectModeSelect") as OptionButton
	manual_server_host_label = _require_panel_node(panel, base_path + "ManualServerHostLabel") as Label
	manual_server_host_edit = _require_panel_node(panel, base_path + "ManualServerHostEdit") as LineEdit
	apply_connection_button = _require_panel_node(panel, base_path + "ConnectionButtons/ApplyConnectionButton") as Button
	retry_connect_button = _require_panel_node(panel, base_path + "ConnectionButtons/RetryConnectButton") as Button
	status_label = _require_panel_node(panel, base_path + "StatusLabel") as Label
	return true


func _bind_session_controls() -> bool:
	if session_layer == null:
		return true
	var panel := session_layer.call("get_scene_root") as Control
	if panel == null:
		_log_error("UI_BIND_FAILED", {"error": "Session panel root missing"})
		return false
	var base_path := "Panel/Margin/Scroll/VBox/"
	preset_select = _require_panel_node(panel, base_path + "PresetSelect") as OptionButton
	workflow_mode_select = _require_panel_node(panel, base_path + "WorkflowModeSelect") as OptionButton
	workflow_details_label = _require_panel_node(panel, base_path + "WorkflowDetailsLabel") as Label
	checklist_box = _require_panel_node(panel, base_path + "ChecklistBox") as VBoxContainer
	stream_client_label = _require_panel_node(panel, base_path + "StreamClientLabel") as Label
	stream_client_select = _require_panel_node(panel, base_path + "StreamClientSelect") as OptionButton
	run_label_edit = _require_panel_node(panel, base_path + "RunLabelEdit") as LineEdit
	latency_budget_spin = _require_panel_node(panel, base_path + "LatencyBudgetSpin") as SpinBox
	observed_latency_spin = _require_panel_node(panel, base_path + "ObservedLatencySpin") as SpinBox
	focus_loss_spin = _require_panel_node(panel, base_path + "FocusLossSpin") as SpinBox
	operator_note_edit = _require_panel_node(panel, base_path + "OperatorNoteEdit") as TextEdit
	apply_session_details_button = _require_panel_node(panel, base_path + "ApplySessionDetailsButton") as Button
	snapshot_note_edit = _require_panel_node(panel, base_path + "SnapshotNoteEdit") as TextEdit
	capture_snapshot_button = _require_panel_node(panel, base_path + "SnapshotButtons/CaptureSnapshotButton") as Button
	report_issue_button = _require_panel_node(panel, base_path + "SnapshotButtons/ReportIssueButton") as Button
	export_report_button = _require_panel_node(panel, base_path + "SnapshotButtons/ExportReportButton") as Button
	workflow_diagnostics_label = _require_panel_node(panel, base_path + "WorkflowDiagnosticsLabel") as Label
	return true


func _wire_ui_signals() -> void:
	calibrate_button.pressed.connect(func(): controller_reader.request_set_origin())
	recenter_button.pressed.connect(func(): controller_reader.request_clear_origin())
	recenter_panel_button.pressed.connect(_on_recenter_all_panels)
	if tutorial_ui_layer != null:
		show_tutorial_button.pressed.connect(_show_tutorial_panel)
	if hide_tutorial_button != null:
		hide_tutorial_button.pressed.connect(_hide_tutorial_panel)
	show_connection_button.pressed.connect(func(): _toggle_panel(PANEL_KEY_CONNECTION))
	show_session_button.pressed.connect(func(): _toggle_panel(PANEL_KEY_SESSION))
	passthrough_toggle.toggled.connect(_on_passthrough_toggled)
	template_select.item_selected.connect(_on_template_selected)
	sensitivity_slider.value_changed.connect(_on_tuning_changed)
	deadzone_slider.value_changed.connect(_on_tuning_changed)
	expo_slider.value_changed.connect(_on_tuning_changed)
	integrator_slider.value_changed.connect(_on_tuning_changed)
	if connection_layer != null:
		connect_mode_select.item_selected.connect(_on_connect_mode_selected)
		manual_server_host_edit.text_changed.connect(func(_new_text: String): _update_connection_controls())
		apply_connection_button.pressed.connect(_on_apply_connection_pressed)
		retry_connect_button.pressed.connect(_on_retry_connect_pressed)
	if session_layer != null:
		preset_select.item_selected.connect(_on_preset_selected)
		workflow_mode_select.item_selected.connect(_on_workflow_mode_selected)
		stream_client_select.item_selected.connect(_on_stream_client_selected)
		apply_session_details_button.pressed.connect(_on_apply_session_details_pressed)
		capture_snapshot_button.pressed.connect(_on_capture_snapshot_pressed)
		report_issue_button.pressed.connect(_on_report_issue_pressed)
		export_report_button.pressed.connect(_on_export_report_pressed)


func _schedule_startup_recenter() -> void:
	if _xr_interface == null or not _xr_interface.has_signal("session_begun"):
		for key in _managed_panels:
			var info: Dictionary = _managed_panels[key]
			_restore_or_recenter_panel(info["node"], key, info["default_offset"])
		return
	if _panel_recentering_connected:
		return
	_panel_recentering_connected = true
	if _xr_interface.session_begun.is_connected(_on_xr_session_begun):
		return
	_xr_interface.session_begun.connect(_on_xr_session_begun)
	_log_boot("UI_PANEL_RECENTER_DEFERRED", {})


func _on_xr_session_begun() -> void:
	await get_tree().process_frame
	for key in _managed_panels:
		var info: Dictionary = _managed_panels[key]
		_restore_or_recenter_panel(info["node"], key, info["default_offset"])


func _require_panel_node(quest_panel: Control, node_path: String) -> Node:
	var node := quest_panel.get_node_or_null(node_path)
	if node == null:
		var error_text := "Quest panel missing node: %s" % node_path
		push_error(error_text)
		_log_error("UI_BIND_MISSING_NODE", {
			"path": node_path,
			"error": error_text,
		})
	return node


func _has_bound_ui_controls() -> bool:
	if not (passthrough_toggle != null \
		and template_select != null \
		and sensitivity_slider != null \
		and deadzone_slider != null \
		and expo_slider != null \
		and integrator_slider != null \
		and calibrate_button != null \
		and recenter_button != null \
		and output_preview_label != null \
		and show_connection_button != null \
		and show_session_button != null \
		and recenter_panel_button != null \
		and show_tutorial_button != null):
		return false
	if connection_layer != null and not (status_label != null \
		and connect_mode_select != null \
		and manual_server_host_label != null \
		and manual_server_host_edit != null \
		and apply_connection_button != null \
		and retry_connect_button != null):
		return false
	if session_layer != null and not (preset_select != null \
		and workflow_mode_select != null \
		and workflow_details_label != null \
		and checklist_box != null \
		and stream_client_label != null \
		and stream_client_select != null \
		and run_label_edit != null \
		and latency_budget_spin != null \
		and observed_latency_spin != null \
		and focus_loss_spin != null \
		and operator_note_edit != null \
		and apply_session_details_button != null \
		and snapshot_note_edit != null \
		and capture_snapshot_button != null \
		and report_issue_button != null \
		and export_report_button != null \
		and workflow_diagnostics_label != null):
		return false
	return true


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
	_log_info("CONNECTION_MODE_CHANGED", {
		"mode": _connection_mode,
		"manual_server_host": _manual_server_host,
	})
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
			_log_error("MANUAL_CONNECTION_REJECTED", {
				"reason": "empty_host",
			})
			_update_status_label()
			return
		_log_info("MANUAL_CONNECTION_APPLIED", {
			"host": _manual_server_host,
			"control_port": DEFAULT_CONTROL_PORT,
			"telemetry_port": DEFAULT_TELEMETRY_PORT,
		})
		_apply_target_host(_manual_server_host, DEFAULT_CONTROL_PORT, DEFAULT_TELEMETRY_PORT, true)
		return

	_log_info("AUTO_DISCOVERY_APPLY_REQUESTED", {
		"discovered_server_ip": _discovered_server_ip,
	})
	if _discovered_server_ip.is_empty():
		_set_auto_discovery_wait_state()
	else:
		_apply_target_host(_discovered_server_ip, _discovered_control_port, _discovered_telemetry_port, false)
	_update_status_label()


func _on_retry_connect_pressed() -> void:
	_log_info("CONNECTION_RETRY_REQUESTED", {
		"mode": _connection_mode,
		"manual_server_host": _manual_server_host,
		"discovered_server_ip": _discovered_server_ip,
	})
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
	_log_info("DISCOVERY_RESULT_RECEIVED", {
		"ip": ip,
		"control_port": control_port,
		"telemetry_port": telemetry_port,
		"mode": _connection_mode,
	})
	if _connection_mode == CONNECTION_MODE_AUTO:
		_apply_target_host(ip, control_port, telemetry_port, false)
		return
	_update_status_label()


func _apply_target_host(host: String, control_port: int, telemetry_port: int, manual_override: bool) -> void:
	if host.is_empty():
		_connection_state.set_error("Server host is empty")
		_log_error("CONTROL_TARGET_REJECTED", {
			"reason": "empty_host",
			"manual_override": manual_override,
		})
		return
	_log_info("CONTROL_TARGET_APPLIED", {
		"host": host,
		"control_port": control_port,
		"telemetry_port": telemetry_port,
		"manual_override": manual_override,
	})
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
	_log_info("CONTROL_CONNECTION_STATE_CHANGED", {
		"state": state,
		"error_code": error_code,
		"host": str(control_client.server_host),
		"server_port": int(control_client.server_port),
		"telemetry_port": int(telemetry_sender.target_port),
	})
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
	_log_error("DISCOVERY_BIND_FAILED", {
		"error_code": error_code,
		"error": error_string(error_code),
		"mode": _connection_mode,
	})
	_update_status_label()


func _set_auto_discovery_wait_state() -> void:
	var bind_error := int(discovery_listener.get_bind_error())
	if bind_error != OK:
		_connection_state.set_error("Discovery listener failed to bind: %s" % error_string(bind_error))
		_log_error("AUTO_DISCOVERY_WAIT_FAILED", {
			"error_code": bind_error,
			"error": error_string(bind_error),
		})
		return
	_log_info("AUTO_DISCOVERY_WAITING", {})
	_connection_state.set_waiting_for_beacon()


func _update_controller_visuals() -> void:
	left_fallback_mesh.visible = false
	right_fallback_mesh.visible = false
	for controller in [left_hand, right_hand]:
		var render_model: Node = controller.get_node_or_null("ControllerRenderModel")
		var render_model_3d := render_model as Node3D
		if render_model_3d != null:
			render_model_3d.visible = false


func _place_panel(panel: Node3D, offset: Vector3) -> void:
	var cam_pos := xr_camera.global_position
	if not cam_pos.is_finite():
		_log_error("UI_PANEL_RECENTER_SKIPPED", {
			"reason": "camera_pose_invalid",
		})
		return
	panel.global_position = cam_pos + offset
	panel.look_at(cam_pos, Vector3.UP, true)


func _compute_camera_relative_offsets(panel: Node3D) -> Dictionary:
	var delta := panel.global_position - xr_camera.global_position
	return {"x": delta.x, "y": delta.y, "z": delta.z}


func _restore_or_recenter_panel(panel: Node3D, key: String, default_offset: Vector3) -> void:
	var saved: Variant = _panel_position_store.load_offsets(key)
	if saved != null:
		var offset := Vector3(
			float(saved.get("x", 0.0)),
			float(saved.get("y", 0.0)),
			float(saved.get("z", 0.0)))
		_place_panel(panel, offset)
		_log_info("UI_PANEL_RESTORED", {"key": key})
	else:
		_place_panel(panel, default_offset)
		_log_boot("UI_PANEL_RECENTERED", {
			"key": key,
			"position": [panel.global_position.x, panel.global_position.y, panel.global_position.z],
		})


func _save_panel_position(panel: Node3D, key: String) -> void:
	var offsets := _compute_camera_relative_offsets(panel)
	_panel_position_store.save_offsets(key, offsets)
	_log_info("UI_PANEL_POSITION_SAVED", {"key": key})


func _on_recenter_all_panels() -> void:
	for key in _managed_panels:
		var info: Dictionary = _managed_panels[key]
		var node: Node3D = info["node"]
		if not node.visible:
			continue
		_place_panel(node, info["default_offset"])
		_panel_position_store.clear_offsets(key)
	_log_info("UI_PANELS_RECENTERED_BY_USER", {})


func _show_tutorial_panel() -> void:
	if tutorial_ui_layer == null:
		return
	tutorial_ui_layer.visible = true
	var info: Dictionary = _managed_panels.get(PANEL_KEY_TUTORIAL, {})
	if not info.is_empty():
		_restore_or_recenter_panel(tutorial_ui_layer, PANEL_KEY_TUTORIAL, info["default_offset"])
	_refresh_tutorial_controls()


func _hide_tutorial_panel() -> void:
	if tutorial_ui_layer == null:
		return
	tutorial_ui_layer.visible = false
	_refresh_tutorial_controls()


func _toggle_panel(key: String) -> void:
	var info: Dictionary = _managed_panels.get(key, {})
	if info.is_empty():
		return
	var node: Node3D = info["node"]
	node.visible = not node.visible
	if node.visible:
		_restore_or_recenter_panel(node, key, info["default_offset"])


func _sync_passthrough_toggle() -> void:
	if passthrough_toggle == null:
		return

	_updating_passthrough_toggle = true
	passthrough_toggle.button_pressed = bool(_xr_diagnostics.get("passthrough_enabled", false))
	passthrough_toggle.disabled = not bool(_xr_diagnostics.get("alpha_blend_supported", false))
	_updating_passthrough_toggle = false


func _on_passthrough_toggled(enabled: bool) -> void:
	if _updating_passthrough_toggle:
		return

	_xr_diagnostics = _xr_bootstrap.set_passthrough_enabled(enabled)
	_log_info("PASSTHROUGH_TOGGLED", {
		"requested": enabled,
		"enabled": bool(_xr_diagnostics.get("passthrough_enabled", false)),
	})
	_sync_passthrough_toggle()
	_update_status_label()
	_push_runtime_diagnostics(true)


func _on_control_connected() -> void:
	_log_info("CONTROL_CONNECTED", {
		"host": str(control_client.server_host),
		"port": int(control_client.server_port),
	})
	control_client.send_message({
		"type": "hello",
		"client": "quest",
		"diagnostics": _build_runtime_diagnostics(),
	})
	_update_workflow_controls()
	_push_runtime_diagnostics(true)


func _on_control_disconnected() -> void:
	_log_warn("CONTROL_DISCONNECTED", {
		"host": str(control_client.server_host),
		"port": int(control_client.server_port),
	})
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
		"inspect_tree":
			_handle_inspect_tree(message)
		"inspect_node":
			_handle_inspect_node(message)


func _resolve_inspect_node(path: String) -> Node:
	if path == "/root":
		return get_tree().root
	var node: Node = get_node_or_null(NodePath(path))
	if node == null:
		node = get_tree().root.get_node_or_null(NodePath(path.trim_prefix("/root/")))
	return node


func _send_inspect_response(result_type: String, request_id: String, result: Variant) -> void:
	if result is String:
		control_client.send_message({"type": result_type, "request_id": request_id, "ok": false, "error": result})
	else:
		control_client.send_message({"type": result_type, "request_id": request_id, "ok": true, "result": result})


func _handle_inspect_tree(message: Dictionary) -> void:
	var request_id := str(message.get("request_id", ""))
	var path_prefix := str(message.get("path_prefix", "/root"))
	var max_depth := int(message.get("max_depth", 3))
	var node := _resolve_inspect_node(path_prefix)
	if node == null:
		_send_inspect_response("inspect_tree_result", request_id, "Node not found: %s" % path_prefix)
		return
	_send_inspect_response("inspect_tree_result", request_id, SceneTreeInspector.walk_tree(node, max_depth))


func _handle_inspect_node(message: Dictionary) -> void:
	var request_id := str(message.get("request_id", ""))
	var node_path := str(message.get("node_path", ""))
	var properties: Array = message.get("properties", [])
	var node := _resolve_inspect_node(node_path)
	if node == null:
		_send_inspect_response("inspect_node_result", request_id, "Node not found: %s" % node_path)
		return
	_send_inspect_response("inspect_node_result", request_id, SceneTreeInspector.inspect_node(node, properties))


func _load_presets(presets: Array) -> void:
	if preset_select == null:
		return
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
	if template_select == null:
		return
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
	if output_preview_label == null and status_label == null:
		return
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
		"Passthrough: %s" % ("on" if bool(runtime_diagnostics.get("xr_passthrough_enabled", false)) else "off"),
		"XR Mode: %s" % str(runtime_diagnostics.get("xr_active_mode", OpenXRBootstrap.PRESENTATION_MODE_OPAQUE)),
		"Refresh: %.0f Hz" % float(runtime_diagnostics.get("xr_display_refresh_rate", 0.0)),
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
		"Control: %s" % ("active" if bool(runtime_diagnostics.get("control_active", false)) else "paused"),
		"Input: tracking %s | grip %.2f | trigger %.2f" % [
			"ok" if bool(runtime_diagnostics.get("tracking_valid", false)) else "lost",
			float(runtime_diagnostics.get("right_grip_value", 0.0)),
			float(runtime_diagnostics.get("right_trigger_value", 0.0)),
		],
		"Buttons: %s | A %s | Stick %.2f, %.2f" % [
			str(runtime_diagnostics.get("right_buttons_hex", "0x0000")),
			"down" if bool(runtime_diagnostics.get("right_button_south_pressed", false)) else "up",
			float(runtime_diagnostics.get("right_thumbstick_x", 0.0)),
			float(runtime_diagnostics.get("right_thumbstick_y", 0.0)),
		],
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
	if bool(runtime_diagnostics.get("xr_passthrough_preferred", false)) and not bool(runtime_diagnostics.get("xr_passthrough_enabled", false)):
		lines.append("XR Note: passthrough preferred but currently off")
	var passthrough_fallback_reason := str(runtime_diagnostics.get("xr_passthrough_fallback_reason", ""))
	if not passthrough_fallback_reason.is_empty():
		lines.append("XR Fallback: %s" % passthrough_fallback_reason)
	var last_origin_event := str(runtime_diagnostics.get("last_origin_event", "none"))
	if last_origin_event != "none":
		lines.append("Origin Event: %s" % last_origin_event)
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
	if status_label != null:
		status_label.text = "\n".join(lines)
	if workflow_details_label != null:
		workflow_details_label.text = _format_session_playbook(playbook)
	var outputs: Dictionary = _last_status.get("output_summary", {})
	if output_preview_label != null:
		output_preview_label.text = "Outputs: T %.2f | Y %.2f | P %.2f | R %.2f | AUX1 %.0f" % [
			float(outputs.get("throttle", 0.0)),
			float(outputs.get("yaw", 0.0)),
			float(outputs.get("pitch", 0.0)),
			float(outputs.get("roll", 0.0)),
			float(outputs.get("aux_button_1", 0.0)),
		]
	if workflow_diagnostics_label != null:
		workflow_diagnostics_label.text = _format_session_diagnostics(_last_status.get("session_diagnostics", {}), runtime_diagnostics)


func _build_runtime_diagnostics() -> Dictionary:
	var diagnostics := _connection_state.to_dict()
	diagnostics["connection_mode"] = _connection_mode
	diagnostics["manual_server_host"] = _manual_server_host
	diagnostics["discovery_state"] = _connection_state.state
	diagnostics["discovery_error"] = _connection_state.last_error
	diagnostics["xr_state"] = str(_xr_diagnostics.get("state", OpenXRBootstrap.STATE_XR_STARTING))
	diagnostics["xr_error"] = str(_xr_diagnostics.get("error", ""))
	diagnostics["xr_alpha_blend_supported"] = bool(_xr_diagnostics.get("alpha_blend_supported", false))
	diagnostics["xr_passthrough_enabled"] = bool(_xr_diagnostics.get("passthrough_enabled", false))
	diagnostics["xr_passthrough_preferred"] = bool(_xr_diagnostics.get("passthrough_preferred", false))
	diagnostics["xr_requested_mode"] = str(_xr_diagnostics.get("xr_requested_mode", OpenXRBootstrap.PRESENTATION_MODE_OPAQUE))
	diagnostics["xr_active_mode"] = str(_xr_diagnostics.get("xr_active_mode", OpenXRBootstrap.PRESENTATION_MODE_OPAQUE))
	diagnostics["xr_passthrough_started"] = bool(_xr_diagnostics.get("xr_passthrough_started", false))
	diagnostics["xr_passthrough_fallback_reason"] = str(_xr_diagnostics.get("xr_passthrough_fallback_reason", ""))
	diagnostics["xr_passthrough_state_event"] = str(_xr_diagnostics.get("xr_passthrough_state_event", ""))
	diagnostics["xr_passthrough_plugin_available"] = bool(_xr_diagnostics.get("passthrough_plugin_available", false))
	diagnostics["xr_render_model_plugin_available"] = bool(_xr_diagnostics.get("render_model_plugin_available", false))
	diagnostics["xr_passthrough_extension_available"] = bool(_xr_diagnostics.get("passthrough_extension_available", false))
	diagnostics["xr_display_refresh_rate"] = float(_xr_diagnostics.get("display_refresh_rate", 0.0))
	diagnostics["xr_target_refresh_rate"] = float(_xr_diagnostics.get("target_refresh_rate", 0.0))
	diagnostics["xr_vrs_enabled"] = bool(_xr_diagnostics.get("vrs_enabled", false))
	diagnostics["control_active"] = bool(_last_local_controller_state.get("control_active", false))
	diagnostics["tracking_valid"] = bool(_last_local_controller_state.get("tracking_valid", false))
	diagnostics["right_trigger_value"] = float(_last_local_controller_state.get("trigger", 0.0))
	diagnostics["right_grip_value"] = float(_last_local_controller_state.get("grip", 0.0))
	var buttons := int(_last_local_controller_state.get("buttons", 0))
	diagnostics["right_buttons"] = buttons
	diagnostics["right_buttons_hex"] = "0x%04X" % buttons
	diagnostics["right_button_south_pressed"] = RawControllerState.button_pressed(buttons, RawControllerState.BUTTON_SOUTH)
	var thumbstick: Vector2 = _last_local_controller_state.get("thumbstick", Vector2.ZERO)
	diagnostics["right_thumbstick_x"] = float(thumbstick.x)
	diagnostics["right_thumbstick_y"] = float(thumbstick.y)
	diagnostics["last_origin_event"] = _describe_origin_event(int(_last_local_controller_state.get("event_flags", 0)))
	diagnostics["tutorial_visible"] = tutorial_ui_layer.visible if tutorial_ui_layer != null else false
	diagnostics["origin_indicator_visible"] = right_origin_indicator.visible if right_origin_indicator != null else false
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
	if workflow_mode_select == null:
		return
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
	if stream_client_select == null:
		return
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
	if workflow_mode_select == null:
		return
	_updating_workflow_select = true
	for index in range(workflow_mode_select.item_count):
		if str(workflow_mode_select.get_item_metadata(index)) == mode:
			workflow_mode_select.select(index)
			break
	_updating_workflow_select = false


func _select_stream_client(stream_client: String) -> void:
	if stream_client_select == null:
		return
	_updating_stream_client_select = true
	for index in range(stream_client_select.item_count):
		if str(stream_client_select.get_item_metadata(index)) == stream_client:
			stream_client_select.select(index)
			break
	_updating_stream_client_select = false


func _load_session_details() -> void:
	if run_label_edit == null:
		return
	_updating_session_detail_controls = true
	run_label_edit.text = str(_session_profile.get("run_label", ""))
	latency_budget_spin.value = int(_session_profile.get("latency_budget_ms", 0))
	observed_latency_spin.value = int(_session_profile.get("observed_latency_ms", 0))
	focus_loss_spin.value = int(_session_profile.get("focus_loss_events", 0))
	operator_note_edit.text = str(_session_profile.get("operator_note", ""))
	_updating_session_detail_controls = false


func _select_preset(preset_id: String) -> void:
	if preset_select == null:
		return
	_updating_preset_select = true
	for index in range(preset_select.item_count):
		if str(preset_select.get_item_metadata(index)) == preset_id:
			preset_select.select(index)
			break
	_updating_preset_select = false


func _rebuild_manual_check_controls() -> void:
	if checklist_box == null:
		return
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
	if manual_server_host_label == null:
		return
	var manual_mode := _connection_mode == CONNECTION_MODE_MANUAL
	manual_server_host_label.visible = manual_mode
	manual_server_host_edit.visible = manual_mode
	manual_server_host_edit.editable = manual_mode
	apply_connection_button.text = "Apply Manual Host" if manual_mode else "Use Auto Discovery"
	retry_connect_button.disabled = manual_mode and manual_server_host_edit.text.strip_edges().is_empty()


func _update_workflow_controls() -> void:
	_update_connection_controls()
	_refresh_tutorial_controls()
	if passthrough_toggle != null:
		passthrough_toggle.disabled = not bool(_xr_diagnostics.get("alpha_blend_supported", false))
	if session_layer == null:
		return
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


func _refresh_tutorial_controls() -> void:
	if show_tutorial_button != null:
		show_tutorial_button.disabled = tutorial_ui_layer != null and tutorial_ui_layer.visible


func _sync_flight_origin_indicator(state: Dictionary) -> void:
	if right_origin_indicator == null:
		return
	var control_active := bool(state.get("control_active", false))
	if state.get("event_flags", 0) & RawControllerState.EVENT_SET_ORIGIN:
		_suppress_origin_indicator_until_release = false
		right_origin_indicator.call("show_from_transform", right_hand.global_transform)
		_log_info("XR_FLIGHT_ORIGIN_ANCHOR", _build_origin_anchor_fields(right_origin_indicator.transform))
	elif state.get("event_flags", 0) & RawControllerState.EVENT_CLEAR_ORIGIN:
		_suppress_origin_indicator_until_release = true
		right_origin_indicator.call("hide_indicator")

	if not control_active:
		_suppress_origin_indicator_until_release = false
		if right_origin_indicator.visible:
			right_origin_indicator.call("hide_indicator")
		return

	if _suppress_origin_indicator_until_release:
		if right_origin_indicator.visible:
			right_origin_indicator.call("hide_indicator")
		return

	if not right_origin_indicator.visible:
		right_origin_indicator.call("show_from_transform", right_hand.global_transform)
	right_origin_indicator.call("update_displacement", right_hand.global_position)


func _maybe_log_pose_snapshot(state: Dictionary) -> void:
	if not bool(state.get("tracking_valid", false)):
		return
	var now_msec := Time.get_ticks_msec()
	if now_msec - _last_pose_snapshot_msec < POSE_SNAPSHOT_INTERVAL_MSEC:
		return
	_last_pose_snapshot_msec = now_msec
	var origin_transform := Transform3D.IDENTITY
	var origin_visible := right_origin_indicator != null and right_origin_indicator.visible
	if origin_visible:
		origin_transform = right_origin_indicator.transform
	_log_info("XR_POSE_SNAPSHOT", _build_pose_log_fields(state, origin_transform, origin_visible))


func _build_pose_log_fields(state: Dictionary, origin_transform: Transform3D, origin_visible: bool) -> Dictionary:
	var grip_position: Vector3 = state.get("grip_position", Vector3.ZERO)
	var grip_orientation: Quaternion = state.get("grip_orientation", Quaternion.IDENTITY)
	var grip_euler_deg := _quaternion_to_euler_deg(grip_orientation)
	var fields := {
		"controller": "RightHand",
		"tracking_valid": bool(state.get("tracking_valid", false)),
		"control_active": bool(state.get("control_active", false)),
		"grip_position_x": snappedf(grip_position.x, 0.001),
		"grip_position_y": snappedf(grip_position.y, 0.001),
		"grip_position_z": snappedf(grip_position.z, 0.001),
		"grip_pitch_deg": snappedf(grip_euler_deg.x, 0.1),
		"grip_yaw_deg": snappedf(grip_euler_deg.y, 0.1),
		"grip_roll_deg": snappedf(grip_euler_deg.z, 0.1),
		"origin_visible": origin_visible,
	}
	if not origin_visible:
		return fields
	var origin_position := origin_transform.origin
	var displacement := grip_position - origin_position
	var local_displacement := origin_transform.basis.inverse() * displacement
	fields["origin_position_x"] = snappedf(origin_position.x, 0.001)
	fields["origin_position_y"] = snappedf(origin_position.y, 0.001)
	fields["origin_position_z"] = snappedf(origin_position.z, 0.001)
	fields["displacement_x"] = snappedf(displacement.x, 0.001)
	fields["displacement_y"] = snappedf(displacement.y, 0.001)
	fields["displacement_z"] = snappedf(displacement.z, 0.001)
	fields["displacement_local_x"] = snappedf(local_displacement.x, 0.001)
	fields["displacement_local_y"] = snappedf(local_displacement.y, 0.001)
	fields["displacement_local_z"] = snappedf(local_displacement.z, 0.001)
	fields["displacement_magnitude"] = snappedf(displacement.length(), 0.001)
	fields["displacement_xz_magnitude"] = snappedf(Vector2(displacement.x, displacement.z).length(), 0.001)
	return fields


func _build_origin_anchor_fields(origin_transform: Transform3D) -> Dictionary:
	var origin_euler_deg := _quaternion_to_euler_deg(origin_transform.basis.get_rotation_quaternion())
	return {
		"controller": "RightHand",
		"origin_position_x": snappedf(origin_transform.origin.x, 0.001),
		"origin_position_y": snappedf(origin_transform.origin.y, 0.001),
		"origin_position_z": snappedf(origin_transform.origin.z, 0.001),
		"origin_pitch_deg": snappedf(origin_euler_deg.x, 0.1),
		"origin_yaw_deg": snappedf(origin_euler_deg.y, 0.1),
		"origin_roll_deg": snappedf(origin_euler_deg.z, 0.1),
	}


func _quaternion_to_euler_deg(rotation: Quaternion) -> Vector3:
	var euler := Basis(rotation).get_euler(EULER_ORDER_YXZ)
	return Vector3(
		rad_to_deg(euler.x),
		rad_to_deg(euler.y),
		rad_to_deg(euler.z)
	)


func _describe_origin_event(event_flags: int) -> String:
	if event_flags & RawControllerState.EVENT_SET_ORIGIN:
		return "set"
	if event_flags & RawControllerState.EVENT_CLEAR_ORIGIN:
		return "clear"
	return "none"


func _format_session_diagnostics(diagnostics: Dictionary, runtime_diagnostics: Dictionary) -> String:
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
	if snapshot_note_edit == null:
		return
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
	if snapshot_note_edit == null:
		return
	control_client.send_message({
		"type": "capture_run_snapshot",
		"kind": "issue",
		"origin": "quest",
		"note": snapshot_note_edit.text.strip_edges(),
	})
	snapshot_note_edit.clear()


func _on_export_report_pressed() -> void:
	if snapshot_note_edit == null:
		return
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


func _log_boot(phase: String, fields: Dictionary = {}) -> void:
	QuestRuntimeLog.boot(phase, fields)


func _log_info(event: String, fields: Dictionary = {}) -> void:
	QuestRuntimeLog.info(event, fields)


func _log_warn(event: String, fields: Dictionary = {}) -> void:
	QuestRuntimeLog.warn(event, fields)


func _log_error(event: String, fields: Dictionary = {}) -> void:
	QuestRuntimeLog.error(event, fields)
