class_name SessionReportExporter
extends RefCounted

const SessionBaselineComparator = preload("res://scripts/workflow/session_baseline_comparator.gd")
const SessionRunStore = preload("res://scripts/workflow/session_run_store.gd")

const DEFAULT_REPORT_DIR := "user://workflow/reports"

var report_dir: String = DEFAULT_REPORT_DIR
var max_snapshots: int = 8


func _init(next_report_dir: String = DEFAULT_REPORT_DIR, next_max_snapshots: int = 8) -> void:
	report_dir = next_report_dir
	max_snapshots = maxi(next_max_snapshots, 1)


func export_report(
	profile,
	runtime_status: Dictionary,
	history: Array,
	report_note: String = ""
) -> Dictionary:
	_ensure_report_dir()
	var payload := build_export_payload(profile, runtime_status, history, report_note)
	var report_name := str(payload.get("report_name", "session_report"))
	var markdown_path := "%s/%s.md" % [report_dir, report_name]
	var json_path := "%s/%s.json" % [report_dir, report_name]
	var markdown_file := FileAccess.open(markdown_path, FileAccess.WRITE)
	if markdown_file == null:
		return {
			"ok": false,
			"error": FileAccess.get_open_error(),
			"report_name": report_name,
		}
	markdown_file.store_string(build_markdown(payload))
	markdown_file.close()

	var json_file := FileAccess.open(json_path, FileAccess.WRITE)
	if json_file == null:
		return {
			"ok": false,
			"error": FileAccess.get_open_error(),
			"report_name": report_name,
			"markdown_path": markdown_path,
			"markdown_user_path": markdown_path,
		}
	json_file.store_string(JSON.stringify(payload, "\t"))
	json_file.close()

	payload["ok"] = true
	payload["markdown_user_path"] = markdown_path
	payload["json_user_path"] = json_path
	payload["markdown_path"] = ProjectSettings.globalize_path(markdown_path)
	payload["json_path"] = ProjectSettings.globalize_path(json_path)
	return payload


func build_export_payload(
	profile,
	runtime_status: Dictionary,
	history: Array,
	report_note: String = ""
) -> Dictionary:
	var diagnostics: Dictionary = runtime_status.get("session_diagnostics", {})
	if diagnostics.is_empty():
		diagnostics = profile.build_diagnostics(runtime_status)
	var playbook: Dictionary = runtime_status.get("session_playbook", {})
	if playbook.is_empty():
		playbook = profile.build_operator_playbook(runtime_status)
	var baseline_comparison: Dictionary = runtime_status.get("baseline_comparison", {})
	if baseline_comparison.is_empty():
		baseline_comparison = SessionBaselineComparator.new().build_comparison(profile, runtime_status, history)
	var timestamp_unix := int(Time.get_unix_time_from_system())
	var timestamp_usec := Time.get_ticks_usec()
	var recent_snapshots := SessionRunStore.recent_entries(history, max_snapshots)
	var report_name := _build_report_name(profile, timestamp_unix, timestamp_usec)
	var severity := str(diagnostics.get("severity", "attention"))
	return {
		"report_name": report_name,
		"exported_at_unix": timestamp_unix,
		"exported_at_text": Time.get_datetime_string_from_unix_time(timestamp_unix, false),
		"report_note": report_note.strip_edges(),
		"snapshot_count": recent_snapshots.size(),
		"run_label": profile.run_label,
		"preset_id": profile.preset_id,
		"preset_label": profile.get_preset_label(),
		"mode": profile.mode,
		"mode_label": profile.get_mode_label(),
		"stream_client": profile.stream_client,
		"stream_client_label": profile.get_stream_client_label(),
		"latency_budget_ms": profile.latency_budget_ms,
		"observed_latency_ms": profile.observed_latency_ms,
		"focus_loss_events": profile.focus_loss_events,
		"operator_note": profile.operator_note,
		"workflow_hint": profile.get_workflow_hint(),
		"manual_check_summary": profile.get_manual_check_summary(),
		"manual_check_items": profile.manual_check_items(),
		"diagnostics": diagnostics.duplicate(true),
		"playbook": playbook.duplicate(true),
		"baseline_comparison": baseline_comparison.duplicate(true),
		"runtime_status": _compact_runtime_status(runtime_status),
		"recent_snapshots": recent_snapshots,
		"recommended_focus": _recommended_focus_items(diagnostics),
		"summary": "%s | %s | %d snapshots" % [
			profile.get_preset_label(),
			severity.to_upper(),
			recent_snapshots.size(),
		],
		"severity": severity,
	}


func build_markdown(payload: Dictionary) -> String:
	var lines := PackedStringArray()
	lines.append("# Session Report")
	lines.append("")
	lines.append("- Exported: %s" % str(payload.get("exported_at_text", "")))
	lines.append("- Run: %s" % _fallback_text(str(payload.get("run_label", "")), "Unnamed pass"))
	lines.append("- Preset: %s" % str(payload.get("preset_label", "Custom Workflow")))
	lines.append("- Workflow: %s" % str(payload.get("mode_label", "Passthrough Standalone")))
	var stream_client := str(payload.get("stream_client_label", ""))
	if str(payload.get("stream_client", "")) != "none":
		lines.append("- Stream App: %s" % stream_client)
	var latency_budget_ms := int(payload.get("latency_budget_ms", 0))
	if latency_budget_ms > 0:
		lines.append("- Latency Budget: <= %d ms" % latency_budget_ms)
	var observed_latency_ms := int(payload.get("observed_latency_ms", 0))
	if observed_latency_ms > 0:
		lines.append("- Observed Latency: %d ms" % observed_latency_ms)
	lines.append("- Focus Loss Events: %d" % int(payload.get("focus_loss_events", 0)))
	lines.append("- Diagnostics: %s" % str(payload.get("summary", "")))
	lines.append("")

	var report_note := str(payload.get("report_note", ""))
	if not report_note.is_empty():
		lines.append("## Export Note")
		lines.append("")
		lines.append(report_note)
		lines.append("")

	var operator_note := str(payload.get("operator_note", ""))
	if not operator_note.is_empty():
		lines.append("## Operator Note")
		lines.append("")
		lines.append(operator_note)
		lines.append("")

	var workflow_hint := str(payload.get("workflow_hint", ""))
	if not workflow_hint.is_empty():
		lines.append("## Workflow Hint")
		lines.append("")
		lines.append(workflow_hint)
		lines.append("")

	var playbook: Dictionary = payload.get("playbook", {})
	if not playbook.is_empty():
		lines.append("## Workflow Playbook")
		lines.append("")
		lines.append("- Headline: %s" % str(playbook.get("headline", "")))
		lines.append("- Phase: %s" % str(playbook.get("phase_label", "")))
		lines.append("- Summary: %s" % str(playbook.get("summary", "")))
		for step in playbook.get("steps", []):
			lines.append("- %s [%s] %s: %s" % [
				str(step.get("state", "attention")).to_upper(),
				str(step.get("role", "Operator")),
				str(step.get("label", "")),
				str(step.get("detail", "")),
			])
		var next_actions: Array = playbook.get("next_actions", [])
		if not next_actions.is_empty():
			lines.append("")
			lines.append("### Next Actions")
			lines.append("")
			for action in next_actions:
				lines.append("- %s" % str(action))
		var debug_actions: Array = playbook.get("debug_actions", [])
		if not debug_actions.is_empty():
			lines.append("")
			lines.append("### Debug Actions")
			lines.append("")
			for action in debug_actions:
				lines.append("- %s" % str(action))
		lines.append("")

	lines.append("## Runtime Status")
	lines.append("")
	for item in _runtime_lines(payload.get("runtime_status", {})):
		lines.append("- %s" % item)
	lines.append("")

	lines.append("## Diagnostics")
	lines.append("")
	var diagnostics: Dictionary = payload.get("diagnostics", {})
	lines.append("- Summary: %s" % str(diagnostics.get("summary", "")))
	lines.append("- Severity: %s" % str(diagnostics.get("severity", "attention")).to_upper())
	for item in diagnostics.get("items", []):
		lines.append("- %s: %s" % [
			str(item.get("state", "ready")).to_upper(),
			str(item.get("label", "")),
		])
	lines.append("")

	lines.append("## Manual Checklist")
	lines.append("")
	lines.append("- %s" % _fallback_text(str(payload.get("manual_check_summary", "")), "No manual checks configured."))
	for item in payload.get("manual_check_items", []):
		lines.append("- [%s] %s" % [
			"x" if bool(item.get("checked", false)) else " ",
			str(item.get("label", "")),
		])
	lines.append("")

	var recommended_focus: Array = payload.get("recommended_focus", [])
	if not recommended_focus.is_empty():
		lines.append("## Recommended Focus")
		lines.append("")
		for label in recommended_focus:
			lines.append("- %s" % str(label))
		lines.append("")

	var baseline_comparison: Dictionary = payload.get("baseline_comparison", {})
	if not baseline_comparison.is_empty():
		lines.append("## Baseline Comparison")
		lines.append("")
		lines.append("- Summary: %s" % str(baseline_comparison.get("summary", "")))
		lines.append("- Severity: %s" % str(baseline_comparison.get("severity", "attention")).to_upper())
		var reference_label := str(baseline_comparison.get("reference_label", ""))
		if not reference_label.is_empty():
			lines.append("- Reference: %s" % reference_label)
		if bool(baseline_comparison.get("has_latency_delta", false)):
			lines.append("- Latency Delta: %d ms" % int(baseline_comparison.get("latency_delta_ms", 0)))
		lines.append("- Focus Loss Delta: %d" % int(baseline_comparison.get("focus_loss_delta", 0)))
		lines.append("- Packet Drop Delta: %d" % int(baseline_comparison.get("packet_drop_delta", 0)))
		var recommendations: Array = baseline_comparison.get("recommendations", [])
		if not recommendations.is_empty():
			lines.append("")
			lines.append("### Comparison Actions")
			lines.append("")
			for recommendation in recommendations:
				lines.append("- %s" % str(recommendation))
		lines.append("")

	lines.append("## Recent Snapshots")
	lines.append("")
	var snapshots: Array = payload.get("recent_snapshots", [])
	if snapshots.is_empty():
		lines.append("- No snapshots captured yet.")
	else:
		for snapshot in snapshots:
			lines.append("### %s | %s | %s" % [
				str(snapshot.get("captured_at_text", "")),
				str(snapshot.get("kind", "checkpoint")).to_upper(),
				_fallback_text(str(snapshot.get("run_label", "")), "Unnamed pass"),
			])
			lines.append("")
			lines.append("- Origin: %s" % str(snapshot.get("origin", "pc")).to_upper())
			lines.append("- Preset: %s" % str(snapshot.get("preset_label", "Custom Workflow")))
			lines.append("- Diagnostics: %s" % str(snapshot.get("diagnostics_summary", "")))
			lines.append("- Failsafe: %s" % ("active" if bool(snapshot.get("failsafe_active", false)) else "clear"))
			lines.append("- Packets: %d received / %d dropped" % [
				int(snapshot.get("packets_received", 0)),
				int(snapshot.get("packets_dropped", 0)),
			])
			var snapshot_observed_latency_ms := int(snapshot.get("observed_latency_ms", 0))
			if snapshot_observed_latency_ms > 0:
				lines.append("- Observed Latency: %d ms" % snapshot_observed_latency_ms)
			lines.append("- Focus Loss Events: %d" % int(snapshot.get("focus_loss_events", 0)))
			var output_summary: Dictionary = snapshot.get("output_summary", {})
			lines.append("- Outputs: T %.2f | Y %.2f | P %.2f | R %.2f" % [
				float(output_summary.get("throttle", 0.0)),
				float(output_summary.get("yaw", 0.0)),
				float(output_summary.get("pitch", 0.0)),
				float(output_summary.get("roll", 0.0)),
			])
			var note := str(snapshot.get("note", ""))
			if not note.is_empty():
				lines.append("- Note: %s" % note)
			lines.append("")
	return "\n".join(lines).strip_edges() + "\n"


func _compact_runtime_status(runtime_status: Dictionary) -> Dictionary:
	return {
		"connected": bool(runtime_status.get("connected", false)),
		"template_name": str(runtime_status.get("template_name", "")),
		"backend_available": bool(runtime_status.get("backend_available", false)),
		"backend_name": str(runtime_status.get("backend_name", "")),
		"failsafe_active": bool(runtime_status.get("failsafe_active", false)),
		"packets_received": int(runtime_status.get("packets_received", 0)),
		"packets_dropped": int(runtime_status.get("packets_dropped", 0)),
		"session_observed_latency_ms": int(runtime_status.get("session_observed_latency_ms", 0)),
		"session_focus_loss_events": int(runtime_status.get("session_focus_loss_events", 0)),
		"output_summary": runtime_status.get("output_summary", {}).duplicate(true),
	}


func _runtime_lines(runtime_status: Dictionary) -> Array:
	var output_summary: Dictionary = runtime_status.get("output_summary", {})
	var backend_status := "offline"
	if bool(runtime_status.get("backend_available", false)):
		backend_status = "%s ready" % _fallback_text(str(runtime_status.get("backend_name", "")), "backend")
	return [
		"Control link: %s" % ("connected" if bool(runtime_status.get("connected", false)) else "disconnected"),
		"Template: %s" % _fallback_text(str(runtime_status.get("template_name", "")), "None selected"),
		"Backend: %s" % backend_status,
		"Failsafe: %s" % ("active" if bool(runtime_status.get("failsafe_active", false)) else "clear"),
		"Packets: %d received / %d dropped" % [
			int(runtime_status.get("packets_received", 0)),
			int(runtime_status.get("packets_dropped", 0)),
		],
		"Observed Latency: %d ms" % int(runtime_status.get("session_observed_latency_ms", 0)),
		"Focus Loss Events: %d" % int(runtime_status.get("session_focus_loss_events", 0)),
		"Outputs: T %.2f | Y %.2f | P %.2f | R %.2f" % [
			float(output_summary.get("throttle", 0.0)),
			float(output_summary.get("yaw", 0.0)),
			float(output_summary.get("pitch", 0.0)),
			float(output_summary.get("roll", 0.0)),
		],
	]


func _recommended_focus_items(diagnostics: Dictionary) -> Array:
	var focus: Array = []
	for item in diagnostics.get("items", []):
		var state := str(item.get("state", "ready"))
		if state == "attention" or state == "warning":
			focus.append(str(item.get("label", "")))
		if focus.size() >= 4:
			break
	return focus


func _build_report_name(profile, timestamp_unix: int, timestamp_usec: int = 0) -> String:
	var run_fragment := _sanitize_fragment(profile.run_label)
	if run_fragment.is_empty():
		run_fragment = _sanitize_fragment(profile.preset_id)
	if run_fragment.is_empty():
		run_fragment = "session"
	if timestamp_usec <= 0:
		timestamp_usec = Time.get_ticks_usec()
	return "session_report_%s_%d_%d" % [run_fragment, timestamp_unix, timestamp_usec]


func _sanitize_fragment(value: String) -> String:
	var lowered := value.to_lower().strip_edges()
	if lowered.is_empty():
		return ""
	var regex := RegEx.new()
	regex.compile("[^a-z0-9]+")
	var sanitized := regex.sub(lowered, "_", true)
	while sanitized.begins_with("_"):
		sanitized = sanitized.substr(1)
	while sanitized.ends_with("_"):
		sanitized = sanitized.substr(0, sanitized.length() - 1)
	return sanitized.left(32)


func _fallback_text(value: String, fallback: String) -> String:
	if value.is_empty():
		return fallback
	return value


func _ensure_report_dir() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(report_dir))
