extends Node

const OpenXRBootstrap = preload("res://scripts/xr/openxr_bootstrap.gd")
const QuestConnectionState = preload("res://scripts/network/quest_connection_state.gd")

const DIAGNOSTIC_PUSH_INTERVAL_USEC := 500000

signal control_message_requested(message)

var _output_preview_label: Label
var _status_label: Label
var _workflow_details_label: Label
var _workflow_diagnostics_label: Label

var _control_client: Node
var _connection_controller: Node
var _xr_controller: Node
var _flight_runtime_controller: Node
var _template_controller: Node
var _session_controller: Node
var _panel_controller: Node

var _last_status: Dictionary = {}
var _session_profile: Dictionary = {}
var _last_runtime_diagnostics_push_usec: int = 0


func configure(
	flight_panel_root: Control,
	connection_panel_root: Control,
	session_panel_root: Control,
	control_client: Node,
	connection_controller: Node,
	xr_controller: Node,
	flight_runtime_controller: Node,
	template_controller: Node,
	session_controller: Node,
	panel_controller: Node
) -> void:
	_control_client = control_client
	_connection_controller = connection_controller
	_xr_controller = xr_controller
	_flight_runtime_controller = flight_runtime_controller
	_template_controller = template_controller
	_session_controller = session_controller
	_panel_controller = panel_controller
	if flight_panel_root != null:
		_output_preview_label = flight_panel_root.get_node_or_null("Panel/Margin/Scroll/VBox/OutputPreviewLabel") as Label
	if connection_panel_root != null:
		_status_label = connection_panel_root.get_node_or_null("Panel/Margin/Scroll/VBox/StatusLabel") as Label
	if session_panel_root != null:
		_workflow_details_label = session_panel_root.get_node_or_null("Panel/Margin/Scroll/VBox/WorkflowDetailsLabel") as Label
		_workflow_diagnostics_label = session_panel_root.get_node_or_null("Panel/Margin/Scroll/VBox/WorkflowDiagnosticsLabel") as Label
	set_process(true)


func apply_pc_status(status: Dictionary) -> void:
	_last_status = status.duplicate(true)
	refresh_all()


func apply_session_profile(profile: Dictionary) -> void:
	_session_profile = profile.duplicate(true)
	refresh_all()


func handle_control_connected() -> void:
	refresh_all()
	_push_runtime_diagnostics(true)


func handle_control_disconnected() -> void:
	_last_status = {}
	refresh_all()


func refresh_all() -> void:
	_update_status_label()


func build_runtime_diagnostics() -> Dictionary:
	var diagnostics: Dictionary = {}
	if _connection_controller != null:
		diagnostics.merge(_connection_controller.get_runtime_diagnostics(), true)
	var xr_diagnostics: Dictionary = _xr_controller.get_diagnostics() if _xr_controller != null else {}
	diagnostics["xr_state"] = str(xr_diagnostics.get("state", OpenXRBootstrap.STATE_XR_STARTING))
	diagnostics["xr_error"] = str(xr_diagnostics.get("error", ""))
	diagnostics["xr_alpha_blend_supported"] = bool(xr_diagnostics.get("alpha_blend_supported", false))
	diagnostics["xr_passthrough_enabled"] = bool(xr_diagnostics.get("passthrough_enabled", false))
	diagnostics["xr_passthrough_preferred"] = bool(xr_diagnostics.get("passthrough_preferred", false))
	diagnostics["xr_requested_mode"] = str(
		xr_diagnostics.get("xr_requested_mode", OpenXRBootstrap.PRESENTATION_MODE_OPAQUE)
	)
	diagnostics["xr_active_mode"] = str(
		xr_diagnostics.get("xr_active_mode", OpenXRBootstrap.PRESENTATION_MODE_OPAQUE)
	)
	diagnostics["xr_passthrough_started"] = bool(xr_diagnostics.get("xr_passthrough_started", false))
	diagnostics["xr_passthrough_fallback_reason"] = str(
		xr_diagnostics.get("xr_passthrough_fallback_reason", "")
	)
	diagnostics["xr_passthrough_state_event"] = str(xr_diagnostics.get("xr_passthrough_state_event", ""))
	diagnostics["xr_passthrough_plugin_available"] = bool(
		xr_diagnostics.get("passthrough_plugin_available", false)
	)
	diagnostics["xr_render_model_plugin_available"] = bool(
		xr_diagnostics.get("render_model_plugin_available", false)
	)
	diagnostics["xr_passthrough_extension_available"] = bool(
		xr_diagnostics.get("passthrough_extension_available", false)
	)
	diagnostics["xr_display_refresh_rate"] = float(xr_diagnostics.get("display_refresh_rate", 0.0))
	diagnostics["xr_target_refresh_rate"] = float(xr_diagnostics.get("target_refresh_rate", 0.0))
	diagnostics["xr_vrs_enabled"] = bool(xr_diagnostics.get("vrs_enabled", false))
	if _flight_runtime_controller != null:
		diagnostics.merge(_flight_runtime_controller.get_runtime_diagnostics(), true)
	diagnostics["tutorial_visible"] = _panel_controller.is_tutorial_visible() if _panel_controller != null else false
	if _template_controller != null:
		diagnostics["active_template_id"] = _template_controller.get_active_template_id()
		diagnostics["active_template_name"] = str(
			_template_controller.get_active_template_summary().get("display_name", "")
		)
	return diagnostics


func _process(_delta: float) -> void:
	_maybe_push_runtime_diagnostics()


func _update_status_label() -> void:
	if _output_preview_label == null and _status_label == null:
		return
	var runtime_diagnostics := build_runtime_diagnostics()
	var mode_label := str(_session_profile.get("mode_label", "Passthrough Standalone"))
	var preset_label := str(_session_profile.get("preset_label", ""))
	var run_label := str(_session_profile.get("run_label", ""))
	var connection_mode := str(runtime_diagnostics.get("connection_mode", "auto"))
	var current_host := str(runtime_diagnostics.get("control_target_host", ""))
	if current_host.is_empty():
		current_host = str(runtime_diagnostics.get("server_host", ""))
		if current_host.is_empty():
			current_host = "searching..."
	var lines := PackedStringArray([
		"XR: %s" % str(runtime_diagnostics.get("xr_state", "xr_starting")),
		"Passthrough: %s" % ("on" if bool(runtime_diagnostics.get("xr_passthrough_enabled", false)) else "off"),
		"XR Mode: %s" % str(runtime_diagnostics.get("xr_active_mode", OpenXRBootstrap.PRESENTATION_MODE_OPAQUE)),
		"Refresh: %.0f Hz" % float(runtime_diagnostics.get("xr_display_refresh_rate", 0.0)),
		"Connect: %s (%s)" % [
			str(runtime_diagnostics.get("discovery_state", QuestConnectionState.STATE_XR_STARTING)),
			connection_mode,
		],
		"Server: %s" % current_host,
		"Control: %s" % (_control_client.get_connection_state() if _control_client != null else "unconfigured"),
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
		"Template: %s" % str(runtime_diagnostics.get("active_template_name", "")),
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
	var manual_server_host := str(runtime_diagnostics.get("manual_server_host", ""))
	if connection_mode == "manual" and not manual_server_host.is_empty():
		lines.append("Manual Host: %s" % manual_server_host)
	if not run_label.is_empty():
		lines.append("Run: %s" % run_label)
	if bool(_session_profile.get("stream_client_enabled", false)):
		lines.append("Stream App: %s" % str(_session_profile.get("stream_client_label", "Choose Stream App")))
	var latency_budget_ms := int(_session_profile.get("latency_budget_ms", 0))
	if latency_budget_ms > 0:
		lines.append("Latency Budget: <= %d ms" % latency_budget_ms)
	var observed_latency_ms := int(_session_profile.get("observed_latency_ms", 0))
	if observed_latency_ms > 0:
		lines.append("Observed Latency: %d ms" % observed_latency_ms)
	var focus_loss_events := int(_session_profile.get("focus_loss_events", 0))
	if focus_loss_events > 0:
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
	if _status_label != null:
		_status_label.text = "\n".join(lines)
	if _workflow_details_label != null:
		_workflow_details_label.text = _format_session_playbook(playbook)
	var outputs: Dictionary = _last_status.get("output_summary", {})
	if _output_preview_label != null:
		_output_preview_label.text = "Outputs: T %.2f | Y %.2f | P %.2f | R %.2f | AUX1 %.0f" % [
			float(outputs.get("throttle", 0.0)),
			float(outputs.get("yaw", 0.0)),
			float(outputs.get("pitch", 0.0)),
			float(outputs.get("roll", 0.0)),
			float(outputs.get("aux_button_1", 0.0)),
		]
	if _workflow_diagnostics_label != null:
		_workflow_diagnostics_label.text = _format_session_diagnostics(
			_last_status.get("session_diagnostics", {}),
			runtime_diagnostics
		)


func _maybe_push_runtime_diagnostics() -> void:
	if _control_client == null or not _control_client.is_socket_connected():
		return
	var now_usec := Time.get_ticks_usec()
	if now_usec - _last_runtime_diagnostics_push_usec < DIAGNOSTIC_PUSH_INTERVAL_USEC:
		return
	_push_runtime_diagnostics(false)


func _push_runtime_diagnostics(force: bool) -> void:
	if _control_client == null:
		return
	if not force and not _control_client.is_socket_connected():
		return
	if not _control_client.is_socket_connected():
		return
	_last_runtime_diagnostics_push_usec = Time.get_ticks_usec()
	control_message_requested.emit({
		"type": "quest_diagnostics",
		"diagnostics": build_runtime_diagnostics(),
	})


func _format_session_diagnostics(diagnostics: Dictionary, runtime_diagnostics: Dictionary) -> String:
	var lines := PackedStringArray()
	if diagnostics.is_empty():
		lines.append("Checklist: waiting for desktop status.")
	else:
		var summary := str(diagnostics.get("summary", ""))
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
