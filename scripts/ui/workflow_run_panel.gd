class_name WorkflowRunPanel
extends PanelContainer

const SessionProfile = preload("res://scripts/workflow/session_profile.gd")
const SessionRunStore = preload("res://scripts/workflow/session_run_store.gd")

signal snapshot_requested(kind, note)
signal export_requested(note)

@onready var current_summary_label: Label = $VBox/CurrentSummary
@onready var note_edit: TextEdit = $VBox/NoteEdit
@onready var capture_button: Button = $VBox/Buttons/CaptureButton
@onready var issue_button: Button = $VBox/Buttons/IssueButton
@onready var export_button: Button = $VBox/Buttons/ExportButton
@onready var export_status_label: Label = $VBox/ExportStatus
@onready var history_label: RichTextLabel = $VBox/History

var _profile: SessionProfile = SessionProfile.new()
var _runtime_status: Dictionary = {}
var _history: Array = []
var _last_report_export: Dictionary = {}


func _ready() -> void:
	capture_button.pressed.connect(_on_capture_pressed)
	issue_button.pressed.connect(_on_issue_pressed)
	export_button.pressed.connect(_on_export_pressed)
	_refresh()


func set_profile(profile: SessionProfile) -> void:
	_profile = profile.duplicate_profile()
	_refresh()


func set_runtime_status(runtime_status: Dictionary) -> void:
	_runtime_status = runtime_status.duplicate(true)
	_refresh()


func set_history(entries: Array) -> void:
	_history.clear()
	for entry in entries:
		if typeof(entry) == TYPE_DICTIONARY:
			_history.append(entry.duplicate(true))
	_refresh()


func set_last_report_export(export_info: Dictionary) -> void:
	_last_report_export = export_info.duplicate(true)
	_refresh()


func _on_capture_pressed() -> void:
	snapshot_requested.emit(_default_snapshot_kind(), note_edit.text.strip_edges())
	note_edit.clear()


func _on_issue_pressed() -> void:
	snapshot_requested.emit(SessionRunStore.KIND_ISSUE, note_edit.text.strip_edges())
	note_edit.clear()


func _on_export_pressed() -> void:
	export_requested.emit(note_edit.text.strip_edges())
	note_edit.clear()


func _default_snapshot_kind() -> String:
	var diagnostics: Dictionary = _runtime_status.get("session_diagnostics", {})
	if str(diagnostics.get("severity", "")) == "ready":
		return SessionRunStore.KIND_READY
	return SessionRunStore.KIND_CHECKPOINT


func _refresh() -> void:
	var lines := PackedStringArray()
	var playbook := _profile.build_operator_playbook(_runtime_status)
	lines.append("Run: %s" % (_profile.run_label if not _profile.run_label.is_empty() else "Unnamed pass"))
	lines.append("Preset: %s" % _profile.get_preset_label())
	lines.append("Workflow: %s" % _profile.get_mode_label())
	lines.append("Phase: %s" % str(playbook.get("phase_label", "Setup")))
	var diagnostics: Dictionary = _runtime_status.get("session_diagnostics", {})
	var diagnostics_summary := str(diagnostics.get("summary", "Waiting for live workflow diagnostics."))
	lines.append("Live Status: %s" % diagnostics_summary)
	if _profile.latency_budget_ms > 0:
		lines.append("Latency Budget: <= %d ms" % _profile.latency_budget_ms)
	if _profile.observed_latency_ms > 0:
		lines.append("Observed Latency: %d ms" % _profile.observed_latency_ms)
	if _profile.focus_loss_events > 0 or _profile.mode == SessionProfile.MODE_EXPERIMENTAL_STREAM:
		lines.append("Focus Loss Events: %d" % _profile.focus_loss_events)
	var manual_check_summary := _profile.get_manual_check_summary()
	if not manual_check_summary.is_empty():
		lines.append("Manual Checks: %s" % manual_check_summary)
	var packets_received := int(_runtime_status.get("packets_received", 0))
	var packets_dropped := int(_runtime_status.get("packets_dropped", 0))
	lines.append("Packets: %d received / %d dropped" % [packets_received, packets_dropped])
	var outputs: Dictionary = _runtime_status.get("output_summary", {})
	if not outputs.is_empty():
		lines.append("Outputs: T %.2f | Y %.2f | P %.2f | R %.2f" % [
			float(outputs.get("throttle", 0.0)),
			float(outputs.get("yaw", 0.0)),
			float(outputs.get("pitch", 0.0)),
			float(outputs.get("roll", 0.0)),
		])
	var baseline_comparison: Dictionary = _runtime_status.get("baseline_comparison", {})
	if not baseline_comparison.is_empty():
		lines.append("Compare: %s" % str(baseline_comparison.get("summary", "")))
		var recommendations: Array = baseline_comparison.get("recommendations", [])
		if not recommendations.is_empty():
			lines.append("Compare Next: %s" % str(recommendations[0]))
	var next_actions: Array = playbook.get("next_actions", [])
	for index in range(mini(next_actions.size(), 2)):
		lines.append("Next: %s" % str(next_actions[index]))
	var debug_actions: Array = playbook.get("debug_actions", [])
	if not debug_actions.is_empty():
		lines.append("Debug: %s" % str(debug_actions[0]))
	current_summary_label.text = "\n".join(lines)

	var history_lines := PackedStringArray()
	if _history.is_empty():
		history_lines.append("No snapshots yet. Capture a checkpoint before changing templates or workflow mode.")
	else:
		for index in range(mini(_history.size(), 6)):
			history_lines.append(_format_entry(_history[index]))
	history_label.text = "\n\n".join(history_lines)

	var export_summary := str(_last_report_export.get("summary", ""))
	if export_summary.is_empty():
		export_status_label.text = "No report exported yet. Generate one after a headset pass or issue capture."
	else:
		var export_path := str(_last_report_export.get("markdown_user_path", ""))
		if export_path.is_empty():
			export_path = str(_last_report_export.get("markdown_path", ""))
		export_status_label.text = "Last Export: %s\n%s" % [
			str(_last_report_export.get("exported_at_text", "")),
			export_summary,
		]
		if not export_path.is_empty():
			export_status_label.text += "\n%s" % export_path


func _format_entry(entry: Dictionary) -> String:
	var header := "%s | %s | %s" % [
		str(entry.get("captured_at_text", "")),
		_kind_label(str(entry.get("kind", SessionRunStore.KIND_CHECKPOINT))),
		str(entry.get("run_label", "Unnamed pass")),
	]
	var lines := PackedStringArray([header])
	lines.append("%s via %s" % [
		str(entry.get("preset_label", "Passthrough Baseline")),
		_origin_label(str(entry.get("origin", SessionRunStore.ORIGIN_PC))),
	])
	var diagnostics_summary := str(entry.get("diagnostics_summary", ""))
	if not diagnostics_summary.is_empty():
		lines.append(diagnostics_summary)
	var observed_latency_ms := int(entry.get("observed_latency_ms", 0))
	if observed_latency_ms > 0:
		lines.append("Observed Latency: %d ms" % observed_latency_ms)
	var focus_loss_events := int(entry.get("focus_loss_events", 0))
	if focus_loss_events > 0:
		lines.append("Focus Loss Events: %d" % focus_loss_events)
	var note := str(entry.get("note", ""))
	if not note.is_empty():
		lines.append("Note: %s" % note)
	lines.append("Packets %d/%d dropped | Failsafe %s" % [
		int(entry.get("packets_received", 0)),
		int(entry.get("packets_dropped", 0)),
		"active" if bool(entry.get("failsafe_active", false)) else "clear",
	])
	return "\n".join(lines)


func _kind_label(kind: String) -> String:
	match kind:
		SessionRunStore.KIND_READY:
			return "READY"
		SessionRunStore.KIND_ISSUE:
			return "ISSUE"
		_:
			return "CHECKPOINT"


func _origin_label(origin: String) -> String:
	if origin == SessionRunStore.ORIGIN_QUEST:
		return "Quest"
	return "Desktop"
