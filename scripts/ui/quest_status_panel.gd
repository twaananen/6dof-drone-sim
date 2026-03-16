class_name QuestStatusPanel
extends PanelContainer

@onready var title_label: Label = $VBox/Title
@onready var payload_label: Label = $VBox/Payload


func set_status(status: Dictionary) -> void:
	title_label.text = "Quest Status"
	var lines := PackedStringArray([
		"Connected: %s" % ("yes" if status.get("connected", false) else "no"),
		"Workflow: %s" % str(status.get("session_mode_label", "Passthrough Standalone")),
		"Preset: %s" % str(status.get("session_preset_label", "Passthrough Baseline")),
		"Template: %s" % str(status.get("template_name", "")),
		"Control: %s" % ("active" if bool(status.get("control_active", false)) else "paused"),
		"Failsafe: %s" % ("active" if status.get("failsafe_active", true) else "clear"),
		"Backend: %s" % ("ready" if status.get("backend_available", false) else "offline"),
		"Packets: %d received / %d dropped" % [
			int(status.get("packets_received", 0)),
			int(status.get("packets_dropped", 0)),
		],
		"Beacon: %d broadcast(s)" % int(status.get("beacon_packets_sent", 0)),
	])
	var quest_runtime: Dictionary = status.get("quest_runtime_diagnostics", {})
	if not quest_runtime.is_empty():
		lines.append("Quest XR: %s" % str(quest_runtime.get("xr_state", "xr_starting")))
		lines.append("Quest Connect: %s" % str(quest_runtime.get("discovery_state", "xr_starting")))
		var quest_host := str(quest_runtime.get("control_target_host", ""))
		if not quest_host.is_empty():
			lines.append("Quest Target: %s" % quest_host)
		lines.append("Quest Discovery: %d beacon(s), %d invalid" % [
			int(quest_runtime.get("beacon_packets_received", 0)),
			int(quest_runtime.get("discovery_invalid_packets", 0)),
		])
		lines.append("Quest Telemetry: %d sent / %d errors" % [
			int(quest_runtime.get("telemetry_packets_sent", 0)),
			int(quest_runtime.get("telemetry_send_errors", 0)),
		])
		lines.append("Quest Control: %s" % ("active" if bool(quest_runtime.get("control_active", false)) else "paused"))
		lines.append("Quest Input: tracking %s | grip %.2f | trigger %.2f" % [
			"ok" if bool(quest_runtime.get("tracking_valid", false)) else "lost",
			float(quest_runtime.get("right_grip_value", 0.0)),
			float(quest_runtime.get("right_trigger_value", 0.0)),
		])
		lines.append("Quest Buttons: %s | A %s | Stick %.2f, %.2f" % [
			str(quest_runtime.get("right_buttons_hex", "0x0000")),
			"down" if bool(quest_runtime.get("right_button_south_pressed", false)) else "up",
			float(quest_runtime.get("right_thumbstick_x", 0.0)),
			float(quest_runtime.get("right_thumbstick_y", 0.0)),
		])
		var origin_event := str(quest_runtime.get("last_origin_event", "none"))
		if origin_event != "none":
			lines.append("Quest Origin Event: %s" % origin_event)
		var xr_error := str(quest_runtime.get("xr_error", ""))
		if not xr_error.is_empty():
			lines.append("Quest XR Error: %s" % xr_error)
		var discovery_error := str(quest_runtime.get("discovery_error", ""))
		if not discovery_error.is_empty():
			lines.append("Quest Error: %s" % discovery_error)
	var run_label: String = str(status.get("session_run_label", ""))
	if not run_label.is_empty():
		lines.append("Run: %s" % run_label)
	if status.get("session_stream_client_enabled", false):
		lines.append("Stream App: %s" % str(status.get("session_stream_client_label", "Choose Stream App")))
	var latency_budget_ms := int(status.get("session_latency_budget_ms", 0))
	if latency_budget_ms > 0:
		lines.append("Latency Budget: <= %d ms" % latency_budget_ms)
	var observed_latency_ms := int(status.get("session_observed_latency_ms", 0))
	if observed_latency_ms > 0:
		lines.append("Observed Latency: %d ms" % observed_latency_ms)
	var focus_loss_events := int(status.get("session_focus_loss_events", 0))
	if focus_loss_events > 0 or bool(status.get("session_stream_client_enabled", false)):
		lines.append("Focus Loss Events: %d" % focus_loss_events)
	var manual_check_summary: String = str(status.get("session_manual_check_summary", ""))
	if not manual_check_summary.is_empty():
		lines.append("Manual Checks: %s" % manual_check_summary)
	var workflow_hint: String = str(status.get("workflow_hint", ""))
	if not workflow_hint.is_empty():
		lines.append("Hint: %s" % workflow_hint)
	var operator_note: String = str(status.get("session_operator_note", ""))
	if not operator_note.is_empty():
		lines.append("Note: %s" % operator_note)
	var diagnostics: Dictionary = status.get("session_diagnostics", {})
	var diagnostics_summary: String = str(diagnostics.get("summary", ""))
	if not diagnostics_summary.is_empty():
		lines.append("Session: %s" % diagnostics_summary)
	var baseline_comparison: Dictionary = status.get("baseline_comparison", {})
	var comparison_summary := str(baseline_comparison.get("summary", ""))
	if not comparison_summary.is_empty():
		lines.append("Compare: %s" % comparison_summary)
	var playbook: Dictionary = status.get("session_playbook", {})
	if not playbook.is_empty():
		lines.append("Phase: %s" % str(playbook.get("phase_label", "Setup")))
		var next_actions: Array = playbook.get("next_actions", [])
		for index in range(mini(next_actions.size(), 2)):
			lines.append("Next: %s" % str(next_actions[index]))
		var debug_actions: Array = playbook.get("debug_actions", [])
		if not debug_actions.is_empty():
			lines.append("Debug: %s" % str(debug_actions[0]))
	var recent_snapshots: Array = status.get("recent_run_snapshots", [])
	if not recent_snapshots.is_empty():
		var latest_snapshot: Dictionary = recent_snapshots[0]
		lines.append("Last Snapshot: %s %s" % [
			str(latest_snapshot.get("captured_at_text", "")),
			str(latest_snapshot.get("diagnostics_summary", "")),
		])
	for item in status.get("session_manual_check_items", []):
		var marker := "[x]" if bool(item.get("checked", false)) else "[ ]"
		lines.append("%s %s" % [marker, str(item.get("label", ""))])
	var outputs: Dictionary = status.get("last_outputs", {})
	if not outputs.is_empty():
		lines.append("Outputs: T %.2f | Y %.2f | P %.2f | R %.2f | AUX1 %.0f" % [
			float(outputs.get("throttle", 0.0)),
			float(outputs.get("yaw", 0.0)),
			float(outputs.get("pitch", 0.0)),
			float(outputs.get("roll", 0.0)),
			float(outputs.get("aux_button_1", 0.0)),
		])
	payload_label.text = "\n".join(lines)
