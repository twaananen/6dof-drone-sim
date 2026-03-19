extends Node3D

const SessionProfile = preload("res://scripts/workflow/session_profile.gd")

const PANEL_KEY_FLIGHT := "flight"
const PANEL_KEY_CONNECTION := "connection"
const PANEL_KEY_SESSION := "session"
const PANEL_KEY_TUTORIAL := "tutorial"
const PANEL_KEY_TEMPLATE_LIBRARY := "template_library"
const PANEL_KEY_TEMPLATE_GUIDE := "template_guide"
const PANEL_KEY_TEMPLATE_EDITOR := "template_editor"

@onready var controller_reader: Node = $ControllerReader
@onready var telemetry_sender: Node = $TelemetrySender
@onready var control_client: Node = $ControlClient
@onready var discovery_listener: Node = $DiscoveryListener
@onready var world_environment: WorldEnvironment = $WorldEnvironment
@onready var xr_camera: XRCamera3D = $XROrigin3D/XRCamera3D
@onready var quest_ui_layer: Node3D = $XROrigin3D/QuestUiLayer
@onready var tutorial_ui_layer: Node3D = get_node_or_null("XROrigin3D/TutorialUiLayer") as Node3D
@onready var connection_layer: Node3D = get_node_or_null("XROrigin3D/QuestConnectionLayer") as Node3D
@onready var session_layer: Node3D = get_node_or_null("XROrigin3D/QuestSessionLayer") as Node3D
@onready var template_library_layer: Node3D = get_node_or_null("XROrigin3D/QuestTemplateLibraryLayer") as Node3D
@onready var template_guide_layer: Node3D = get_node_or_null("XROrigin3D/QuestTemplateGuideLayer") as Node3D
@onready var template_editor_layer: Node3D = get_node_or_null("XROrigin3D/QuestTemplateEditorLayer") as Node3D
@onready var left_hand: XRController3D = $XROrigin3D/LeftHand
@onready var right_hand: XRController3D = $XROrigin3D/RightHand
@onready var left_fallback_mesh: MeshInstance3D = $XROrigin3D/LeftHand/FallbackMesh
@onready var right_fallback_mesh: MeshInstance3D = $XROrigin3D/RightHand/FallbackMesh
@onready var right_origin_indicator: Node3D = get_node_or_null("XROrigin3D/RightOriginIndicator") as Node3D

@onready var quest_xr_controller: Node = $QuestXrController
@onready var quest_panel_controller: Node = $QuestPanelController
@onready var quest_connection_controller: Node = $QuestConnectionController
@onready var quest_template_controller: Node = $QuestTemplateController
@onready var quest_session_controller: Node = $QuestSessionController
@onready var quest_flight_runtime_controller: Node = $QuestFlightRuntimeController
@onready var quest_status_controller: Node = $QuestStatusController

var template_library_panel: TemplateLibraryPanel

var _template_catalog: Array = []
var _active_template_id: String = ""
var _active_template_summary: Dictionary = {}
var _active_template_payload: Dictionary = {}


func _ready() -> void:
	_log_boot("READY_BEGIN", {"scene": "quest_main"})
	var flight_panel_root := _get_layer_root(quest_ui_layer)
	if flight_panel_root == null:
		_log_error("QUEST_READY_ABORTED", {"reason": "flight_panel_root_missing"})
		return
	var tutorial_panel_root := _get_layer_root(tutorial_ui_layer)
	var connection_panel_root := _get_layer_root(connection_layer)
	var session_panel_root := _get_layer_root(session_layer)
	var template_library_root := _get_layer_root(template_library_layer)
	var template_guide_root := _get_layer_root(template_guide_layer)
	var template_editor_root := _get_layer_root(template_editor_layer)

	if not _configure_controllers(
		flight_panel_root,
		tutorial_panel_root,
		connection_panel_root,
		session_panel_root,
		template_library_root,
		template_guide_root,
		template_editor_root
	):
		_log_error("QUEST_READY_ABORTED", {"reason": "controller_config_failed"})
		return
	_log_boot("UI_BIND_OK", {})

	_connect_controller_signals()
	_connect_external_signals()
	_log_boot("UI_SIGNALS_BOUND", {})

	var default_profile := SessionProfile.new().to_dict()
	quest_session_controller.apply_session_profile(default_profile)
	quest_status_controller.apply_session_profile(default_profile)
	quest_connection_controller.set_xr_starting()

	_log_boot("XR_INIT_BEGIN", {})
	var xr_diagnostics: Dictionary = quest_xr_controller.initialize_xr()
	if bool(xr_diagnostics.get("ok", false)):
		_log_boot("XR_INIT_OK", {
			"passthrough_enabled": bool(xr_diagnostics.get("passthrough_enabled", false)),
			"display_refresh_rate": float(xr_diagnostics.get("display_refresh_rate", 0.0)),
		})
		quest_panel_controller.schedule_startup_recenter(quest_xr_controller.get_xr_interface())
		quest_connection_controller.begin_auto_discovery_wait()
	else:
		quest_connection_controller.set_error_state(str(xr_diagnostics.get("error", "OpenXR initialization failed")))
		_log_error("XR_INIT_FAILED", {"error": str(xr_diagnostics.get("error", "OpenXR initialization failed"))})

	quest_session_controller.refresh_ui_enabled_state(control_client.is_socket_connected())
	quest_connection_controller.refresh_ui_enabled_state(control_client.is_socket_connected())
	_sync_template_compat_state_from_controller()
	quest_status_controller.refresh_all()
	_log_boot("READY_COMPLETE", {
		"xr_state": str(quest_status_controller.build_runtime_diagnostics().get("xr_state", "xr_starting")),
		"discovery_state": str(quest_connection_controller.get_connection_state_snapshot().get("state", "xr_starting")),
	})


func _configure_controllers(
	flight_panel_root: Control,
	tutorial_panel_root: Control,
	connection_panel_root: Control,
	session_panel_root: Control,
	template_library_root: Control,
	template_guide_root: Control,
	template_editor_root: Control
) -> bool:
	var passthrough_toggle := _require_panel_node(
		flight_panel_root,
		"Panel/Margin/Scroll/VBox/PassthroughToggle"
	) as BaseButton
	var calibrate_button := _require_panel_node(
		flight_panel_root,
		"Panel/Margin/Scroll/VBox/Buttons/CalibrateButton"
	) as Button
	var recenter_button := _require_panel_node(
		flight_panel_root,
		"Panel/Margin/Scroll/VBox/Buttons/RecenterButton"
	) as Button
	var recenter_panel_button := _require_panel_node(
		flight_panel_root,
		"Panel/Margin/Scroll/VBox/PanelButtons/RecenterPanelButton"
	) as Button
	var show_tutorial_button := _require_panel_node(
		flight_panel_root,
		"Panel/Margin/Scroll/VBox/PanelButtons/ShowTutorialButton"
	) as Button
	var hide_tutorial_button: Button = null
	if tutorial_panel_root != null:
		hide_tutorial_button = _require_panel_node(
			tutorial_panel_root,
			"Panel/Margin/Scroll/VBox/HideTutorialButton"
		) as Button
	var nav_buttons := {
		PANEL_KEY_TEMPLATE_LIBRARY: _require_panel_node(
			flight_panel_root,
			"Panel/Margin/Scroll/VBox/NavigationButtons/ShowLibraryButton"
		) as Button,
		PANEL_KEY_TEMPLATE_GUIDE: _require_panel_node(
			flight_panel_root,
			"Panel/Margin/Scroll/VBox/NavigationButtons/ShowGuideButton"
		) as Button,
		PANEL_KEY_TEMPLATE_EDITOR: _require_panel_node(
			flight_panel_root,
			"Panel/Margin/Scroll/VBox/NavigationButtons/ShowEditorButton"
		) as Button,
		PANEL_KEY_CONNECTION: _require_panel_node(
			flight_panel_root,
			"Panel/Margin/Scroll/VBox/NavigationButtons/ShowConnectionButton"
		) as Button,
		PANEL_KEY_SESSION: _require_panel_node(
			flight_panel_root,
			"Panel/Margin/Scroll/VBox/NavigationButtons/ShowSessionButton"
		) as Button,
	}
	quest_flight_runtime_controller.configure(
		controller_reader,
		telemetry_sender,
		right_hand,
		right_origin_indicator
	)
	if not quest_flight_runtime_controller.bind_flight_controls(calibrate_button, recenter_button):
		return false
	if not quest_template_controller.configure(
		flight_panel_root,
		template_library_root,
		template_guide_root,
		template_editor_root
	):
		return false
	if not quest_session_controller.configure(session_panel_root, control_client):
		return false
	if not quest_connection_controller.configure(
		control_client,
		telemetry_sender,
		discovery_listener,
		connection_panel_root
	):
		return false
	quest_xr_controller.configure(
		world_environment,
		get_viewport(),
		left_hand,
		right_hand,
		left_fallback_mesh,
		right_fallback_mesh,
		passthrough_toggle
	)
	quest_panel_controller.configure(
		xr_camera,
		tutorial_ui_layer,
		{
			PANEL_KEY_FLIGHT: quest_ui_layer,
			PANEL_KEY_CONNECTION: connection_layer,
			PANEL_KEY_SESSION: session_layer,
			PANEL_KEY_TUTORIAL: tutorial_ui_layer,
			PANEL_KEY_TEMPLATE_LIBRARY: template_library_layer,
			PANEL_KEY_TEMPLATE_GUIDE: template_guide_layer,
			PANEL_KEY_TEMPLATE_EDITOR: template_editor_layer,
		},
		recenter_panel_button,
		show_tutorial_button,
		hide_tutorial_button,
		nav_buttons
	)
	quest_status_controller.configure(
		flight_panel_root,
		connection_panel_root,
		session_panel_root,
		control_client,
		quest_connection_controller,
		quest_xr_controller,
		quest_flight_runtime_controller,
		quest_template_controller,
		quest_session_controller,
		quest_panel_controller
	)
	template_library_panel = quest_template_controller.template_library_panel
	return true


func _connect_controller_signals() -> void:
	quest_template_controller.control_message_requested.connect(_send_control_message)
	quest_session_controller.control_message_requested.connect(_send_control_message)
	quest_status_controller.control_message_requested.connect(_send_control_message)
	quest_session_controller.session_profile_changed.connect(_on_session_profile_changed)
	quest_flight_runtime_controller.local_state_updated.connect(func(_state: Dictionary): quest_status_controller.refresh_all())
	quest_connection_controller.connection_diagnostics_changed.connect(func(_diagnostics: Dictionary): quest_status_controller.refresh_all())
	quest_xr_controller.passthrough_diagnostics_changed.connect(func(_diagnostics: Dictionary): quest_status_controller.refresh_all())
	quest_xr_controller.xr_session_ready.connect(quest_panel_controller.handle_xr_session_ready)
	quest_xr_controller.xr_initialized.connect(func(_diagnostics: Dictionary): quest_status_controller.refresh_all())
	quest_xr_controller.xr_failed.connect(func(_error: String, _diagnostics: Dictionary): quest_status_controller.refresh_all())


func _connect_external_signals() -> void:
	control_client.connected.connect(_on_control_connected)
	control_client.disconnected.connect(_on_control_disconnected)
	control_client.message_received.connect(_on_control_message)
	control_client.connection_state_changed.connect(quest_connection_controller.on_control_connection_state_changed)
	discovery_listener.server_discovered.connect(quest_connection_controller.on_server_discovered)
	discovery_listener.bind_failed.connect(quest_connection_controller.on_discovery_bind_failed)


func _on_control_connected() -> void:
	_log_info("CONTROL_CONNECTED", {
		"host": str(control_client.server_host),
		"port": int(control_client.server_port),
	})
	_send_control_message({
		"type": "hello",
		"client": "quest",
		"diagnostics": quest_status_controller.build_runtime_diagnostics(),
	})
	quest_connection_controller.handle_control_connected()
	quest_session_controller.refresh_ui_enabled_state(true)
	quest_status_controller.handle_control_connected()


func _on_control_disconnected() -> void:
	_log_warn("CONTROL_DISCONNECTED", {
		"host": str(control_client.server_host),
		"port": int(control_client.server_port),
	})
	quest_connection_controller.handle_control_disconnected()
	quest_template_controller.handle_control_disconnected()
	quest_session_controller.refresh_ui_enabled_state(false)
	quest_status_controller.handle_control_disconnected()


func _on_control_message(message: Dictionary) -> void:
	match str(message.get("type", "")):
		"template_catalog":
			quest_template_controller.apply_template_catalog(message.get("templates", []))
			_sync_template_compat_state_from_controller()
		"session_profile":
			quest_connection_controller.mark_profile_synced()
			quest_session_controller.apply_session_profile(message.get("profile", {}))
			quest_status_controller.apply_session_profile(quest_session_controller.get_session_profile())
			quest_session_controller.refresh_ui_enabled_state(control_client.is_socket_connected())
		"active_template":
			quest_template_controller.apply_active_template(
				str(message.get("template_id", "")),
				message.get("template_summary", {}),
				message.get("template", {})
			)
			_sync_template_compat_state_from_controller()
		"status":
			quest_session_controller.apply_pc_status(message)
			quest_template_controller.apply_status_template_fallback(message)
			quest_status_controller.apply_pc_status(message)
			_sync_template_compat_state_from_controller()
		"inspect_tree":
			_handle_inspect_tree(message)
		"inspect_node":
			_handle_inspect_node(message)


func _on_session_profile_changed(profile: Dictionary) -> void:
	quest_status_controller.apply_session_profile(profile)


func _send_control_message(message: Dictionary) -> void:
	control_client.send_message(message)


func _get_layer_root(layer: Node) -> Control:
	if layer == null or not layer.has_method("get_scene_root"):
		return null
	return layer.call("get_scene_root") as Control


func _require_panel_node(quest_panel: Control, node_path: String) -> Node:
	if quest_panel == null:
		return null
	var node := quest_panel.get_node_or_null(node_path)
	if node == null:
		var error_text := "Quest panel missing node: %s" % node_path
		push_error(error_text)
		_log_error("UI_BIND_MISSING_NODE", {
			"path": node_path,
			"error": error_text,
		})
	return node


func _sync_template_compat_state_from_controller() -> void:
	_template_catalog = quest_template_controller.get_template_catalog()
	_active_template_id = quest_template_controller.get_active_template_id()
	_active_template_summary = quest_template_controller.get_active_template_summary()
	_active_template_payload = quest_template_controller.get_active_template_payload()
	template_library_panel = quest_template_controller.template_library_panel


func _build_pose_log_fields(
	state: Dictionary,
	origin_transform: Transform3D,
	origin_visible: bool
) -> Dictionary:
	return quest_flight_runtime_controller.build_pose_log_fields(state, origin_transform, origin_visible)


func _sync_flight_origin_indicator(state: Dictionary) -> void:
	quest_flight_runtime_controller.sync_flight_origin_indicator(state)


func _update_status_label() -> void:
	quest_status_controller.refresh_all()


func _build_runtime_diagnostics() -> Dictionary:
	return quest_status_controller.build_runtime_diagnostics()


func _sync_template_surfaces() -> void:
	quest_template_controller.override_local_state(
		_template_catalog,
		_active_template_id,
		_active_template_summary,
		_active_template_payload
	)
	quest_template_controller.sync_template_surfaces()
	_sync_template_compat_state_from_controller()


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


func _log_boot(phase: String, fields: Dictionary = {}) -> void:
	QuestRuntimeLog.boot(phase, fields)


func _log_info(event: String, fields: Dictionary = {}) -> void:
	QuestRuntimeLog.info(event, fields)


func _log_warn(event: String, fields: Dictionary = {}) -> void:
	QuestRuntimeLog.warn(event, fields)


func _log_error(event: String, fields: Dictionary = {}) -> void:
	QuestRuntimeLog.error(event, fields)
