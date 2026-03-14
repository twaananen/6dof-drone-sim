extends Node3D

const SessionProfile = preload("res://scripts/workflow/session_profile.gd")

@onready var controller_reader: Node = $ControllerReader
@onready var telemetry_sender: Node = $TelemetrySender
@onready var control_client: Node = $ControlClient
@onready var preset_select: OptionButton = $CanvasLayer/Panel/VBox/PresetSelect
@onready var template_select: OptionButton = $CanvasLayer/Panel/VBox/TemplateSelect
@onready var status_label: Label = $CanvasLayer/Panel/VBox/StatusLabel
@onready var workflow_mode_select: OptionButton = $CanvasLayer/Panel/VBox/WorkflowModeSelect
@onready var workflow_details_label: Label = $CanvasLayer/Panel/VBox/WorkflowDetailsLabel
@onready var checklist_box: VBoxContainer = $CanvasLayer/Panel/VBox/ChecklistBox
@onready var stream_client_label: Label = $CanvasLayer/Panel/VBox/StreamClientLabel
@onready var stream_client_select: OptionButton = $CanvasLayer/Panel/VBox/StreamClientSelect
@onready var run_label_edit: LineEdit = $CanvasLayer/Panel/VBox/RunLabelEdit
@onready var latency_budget_spin: SpinBox = $CanvasLayer/Panel/VBox/LatencyBudgetSpin
@onready var observed_latency_spin: SpinBox = $CanvasLayer/Panel/VBox/ObservedLatencySpin
@onready var focus_loss_spin: SpinBox = $CanvasLayer/Panel/VBox/FocusLossSpin
@onready var operator_note_edit: TextEdit = $CanvasLayer/Panel/VBox/OperatorNoteEdit
@onready var apply_session_details_button: Button = $CanvasLayer/Panel/VBox/ApplySessionDetailsButton
@onready var calibrate_button: Button = $CanvasLayer/Panel/VBox/Buttons/CalibrateButton
@onready var recenter_button: Button = $CanvasLayer/Panel/VBox/Buttons/RecenterButton
@onready var snapshot_note_edit: TextEdit = $CanvasLayer/Panel/VBox/SnapshotNoteEdit
@onready var capture_snapshot_button: Button = $CanvasLayer/Panel/VBox/SnapshotButtons/CaptureSnapshotButton
@onready var report_issue_button: Button = $CanvasLayer/Panel/VBox/SnapshotButtons/ReportIssueButton
@onready var export_report_button: Button = $CanvasLayer/Panel/VBox/SnapshotButtons/ExportReportButton
@onready var sensitivity_slider: HSlider = $CanvasLayer/Panel/VBox/Tuning/SensitivitySlider
@onready var deadzone_slider: HSlider = $CanvasLayer/Panel/VBox/Tuning/DeadzoneSlider
@onready var expo_slider: HSlider = $CanvasLayer/Panel/VBox/Tuning/ExpoSlider
@onready var integrator_slider: HSlider = $CanvasLayer/Panel/VBox/Tuning/IntegratorSlider
@onready var output_preview_label: Label = $CanvasLayer/Panel/VBox/OutputPreviewLabel
@onready var workflow_diagnostics_label: Label = $CanvasLayer/Panel/VBox/WorkflowDiagnosticsLabel

var _active_template_name: String = ""
var _last_status: Dictionary = {}
var _session_profile: Dictionary = SessionProfile.new().to_dict()
var _updating_preset_select: bool = false
var _updating_workflow_select: bool = false
var _updating_stream_client_select: bool = false
var _updating_session_detail_controls: bool = false


func _ready() -> void:
	calibrate_button.pressed.connect(func(): controller_reader.request_calibration())
	recenter_button.pressed.connect(func(): controller_reader.request_recenter())
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
	control_client.connected.connect(_on_control_connected)
	control_client.disconnected.connect(_on_control_disconnected)
	control_client.message_received.connect(_on_control_message)
	_load_presets(_session_profile.get("presets", []))
	_load_workflow_modes(_session_profile.get("available_modes", []))
	_load_stream_clients(_session_profile.get("stream_clients", []))
	_load_session_details()
	_rebuild_manual_check_controls()
	_update_workflow_controls()
	_init_xr()


func _physics_process(_delta: float) -> void:
	telemetry_sender.send_state(controller_reader.read_state())
	_update_status_label()


func _init_xr() -> void:
	var xr_interface: XRInterface = XRServer.find_interface("OpenXR")
	if xr_interface == null:
		push_warning("OpenXR interface missing")
		return
	if not xr_interface.is_initialized():
		xr_interface.initialize()
	if xr_interface.is_initialized():
		get_viewport().use_xr = true


func _on_control_connected() -> void:
	control_client.send_message({
		"type": "hello",
		"client": "quest",
	})
	_update_workflow_controls()


func _on_control_disconnected() -> void:
	_last_status = {}
	_update_workflow_controls()
	_update_status_label()


func _on_control_message(message: Dictionary) -> void:
	match str(message.get("type", "")):
		"template_catalog":
			_load_catalog(message.get("templates", []))
		"session_profile":
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
	var lines := PackedStringArray([
		"Control: %s" % control_client.get_connection_state(),
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


func _update_workflow_controls() -> void:
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
	if diagnostics.is_empty():
		return "Checklist: waiting for desktop status."
	var lines := PackedStringArray()
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
