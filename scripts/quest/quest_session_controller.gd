extends Node

const SessionProfile = preload("res://scripts/workflow/session_profile.gd")

signal control_message_requested(message)
signal session_profile_changed(profile)

var preset_select: OptionButton
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
var snapshot_note_edit: TextEdit
var capture_snapshot_button: Button
var report_issue_button: Button
var export_report_button: Button
var workflow_diagnostics_label: Label

var _control_client: Node
var _session_profile: Dictionary = SessionProfile.new().to_dict()
var _last_status: Dictionary = {}
var _updating_preset_select: bool = false
var _updating_workflow_select: bool = false
var _updating_stream_client_select: bool = false
var _updating_session_detail_controls: bool = false


func configure(session_panel_root: Control, control_client: Node) -> bool:
	_control_client = control_client
	if session_panel_root == null:
		return true
	var base_path := "Panel/Margin/Scroll/VBox/"
	preset_select = _require_panel_node(session_panel_root, base_path + "PresetSelect") as OptionButton
	workflow_mode_select = _require_panel_node(session_panel_root, base_path + "WorkflowModeSelect") as OptionButton
	workflow_details_label = _require_panel_node(session_panel_root, base_path + "WorkflowDetailsLabel") as Label
	checklist_box = _require_panel_node(session_panel_root, base_path + "ChecklistBox") as VBoxContainer
	stream_client_label = _require_panel_node(session_panel_root, base_path + "StreamClientLabel") as Label
	stream_client_select = _require_panel_node(session_panel_root, base_path + "StreamClientSelect") as OptionButton
	run_label_edit = _require_panel_node(session_panel_root, base_path + "RunLabelEdit") as LineEdit
	latency_budget_spin = _require_panel_node(session_panel_root, base_path + "LatencyBudgetSpin") as SpinBox
	observed_latency_spin = _require_panel_node(session_panel_root, base_path + "ObservedLatencySpin") as SpinBox
	focus_loss_spin = _require_panel_node(session_panel_root, base_path + "FocusLossSpin") as SpinBox
	operator_note_edit = _require_panel_node(session_panel_root, base_path + "OperatorNoteEdit") as TextEdit
	apply_session_details_button = _require_panel_node(
		session_panel_root,
		base_path + "ApplySessionDetailsButton"
	) as Button
	snapshot_note_edit = _require_panel_node(session_panel_root, base_path + "SnapshotNoteEdit") as TextEdit
	capture_snapshot_button = _require_panel_node(
		session_panel_root,
		base_path + "SnapshotButtons/CaptureSnapshotButton"
	) as Button
	report_issue_button = _require_panel_node(
		session_panel_root,
		base_path + "SnapshotButtons/ReportIssueButton"
	) as Button
	export_report_button = _require_panel_node(
		session_panel_root,
		base_path + "SnapshotButtons/ExportReportButton"
	) as Button
	workflow_diagnostics_label = _require_panel_node(
		session_panel_root,
		base_path + "WorkflowDiagnosticsLabel"
	) as Label
	if not _has_bound_controls():
		return false
	_connect_controls()
	_load_presets(_session_profile.get("presets", []))
	_load_workflow_modes(_session_profile.get("available_modes", []))
	_load_stream_clients(_session_profile.get("stream_clients", []))
	_load_session_details()
	_rebuild_manual_check_controls()
	return true


func apply_session_profile(profile: Dictionary) -> void:
	_session_profile = profile.duplicate(true)
	_load_presets(_session_profile.get("presets", []))
	_load_workflow_modes(_session_profile.get("available_modes", []))
	_load_stream_clients(_session_profile.get("stream_clients", []))
	_load_session_details()
	_select_preset(str(_session_profile.get("preset_id", SessionProfile.PRESET_PASSTHROUGH_BASELINE)))
	_select_workflow_mode(str(_session_profile.get("mode", SessionProfile.MODE_PASSTHROUGH_STANDALONE)))
	_select_stream_client(str(_session_profile.get("stream_client", SessionProfile.STREAM_CLIENT_NONE)))
	_rebuild_manual_check_controls()
	session_profile_changed.emit(get_session_profile())


func apply_pc_status(status: Dictionary) -> void:
	_last_status = status.duplicate(true)


func get_session_profile() -> Dictionary:
	return _session_profile.duplicate(true)


func refresh_ui_enabled_state(control_connected: bool) -> void:
	if preset_select == null:
		return
	var stream_client_enabled := bool(_session_profile.get("stream_client_enabled", false))
	stream_client_label.visible = stream_client_enabled
	stream_client_select.visible = stream_client_enabled
	stream_client_select.disabled = (not stream_client_enabled) or (not control_connected)
	preset_select.disabled = not control_connected
	workflow_mode_select.disabled = not control_connected
	run_label_edit.editable = control_connected
	latency_budget_spin.editable = control_connected
	observed_latency_spin.editable = control_connected
	focus_loss_spin.editable = control_connected
	operator_note_edit.editable = control_connected
	apply_session_details_button.disabled = not control_connected
	snapshot_note_edit.editable = control_connected
	capture_snapshot_button.disabled = not control_connected
	report_issue_button.disabled = not control_connected
	export_report_button.disabled = not control_connected
	for child in checklist_box.get_children():
		if child is CheckBox:
			child.disabled = not control_connected


func format_workflow_hint_inputs() -> Dictionary:
	return {
		"workflow_hint": str(_session_profile.get("workflow_hint", "")),
		"playbook": _last_status.get("session_playbook", {}).duplicate(true),
	}


func _connect_controls() -> void:
	preset_select.item_selected.connect(_on_preset_selected)
	workflow_mode_select.item_selected.connect(_on_workflow_mode_selected)
	stream_client_select.item_selected.connect(_on_stream_client_selected)
	apply_session_details_button.pressed.connect(_on_apply_session_details_pressed)
	capture_snapshot_button.pressed.connect(_on_capture_snapshot_pressed)
	report_issue_button.pressed.connect(_on_report_issue_pressed)
	export_report_button.pressed.connect(_on_export_report_pressed)


func _load_presets(presets: Array) -> void:
	if preset_select == null:
		return
	_updating_preset_select = true
	preset_select.clear()
	if presets.is_empty():
		presets = SessionProfile.available_presets()
	for preset_info in presets:
		var value := str(preset_info.get("value", ""))
		var label := str(preset_info.get("label", value))
		preset_select.add_item(label)
		preset_select.set_item_metadata(preset_select.item_count - 1, value)
	_updating_preset_select = false


func _load_workflow_modes(modes: Array) -> void:
	if workflow_mode_select == null:
		return
	_updating_workflow_select = true
	workflow_mode_select.clear()
	if modes.is_empty():
		modes = SessionProfile.available_modes()
	for mode_info in modes:
		var value := str(mode_info.get("value", ""))
		var label := str(mode_info.get("label", value))
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
		var value := str(stream_client_info.get("value", ""))
		var label := str(stream_client_info.get("label", value))
		stream_client_select.add_item(label)
		stream_client_select.set_item_metadata(stream_client_select.item_count - 1, value)
	_updating_stream_client_select = false


func _on_preset_selected(index: int) -> void:
	if _updating_preset_select:
		return
	control_message_requested.emit({
		"type": "set_session_preset",
		"preset_id": str(preset_select.get_item_metadata(index)),
	})


func _on_workflow_mode_selected(index: int) -> void:
	if _updating_workflow_select:
		return
	control_message_requested.emit({
		"type": "set_session_mode",
		"mode": str(workflow_mode_select.get_item_metadata(index)),
	})


func _on_stream_client_selected(index: int) -> void:
	if _updating_stream_client_select:
		return
	control_message_requested.emit({
		"type": "set_stream_client",
		"stream_client": str(stream_client_select.get_item_metadata(index)),
	})


func _on_apply_session_details_pressed() -> void:
	if _updating_session_detail_controls:
		return
	control_message_requested.emit({
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
	_session_profile["manual_check_summary"] = "%d/%d workflow checks complete" % [completed, manual_check_items.size()] if manual_check_items.size() > 0 else ""
	control_message_requested.emit({
		"type": "set_manual_check",
		"check_id": check_id,
		"checked": pressed,
	})
	_rebuild_manual_check_controls()
	session_profile_changed.emit(get_session_profile())


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
		checkbox.disabled = _control_client == null or not _control_client.is_socket_connected()
		checkbox.toggled.connect(_on_manual_check_toggled.bind(check_id))
		checklist_box.add_child(checkbox)


func _on_capture_snapshot_pressed() -> void:
	if snapshot_note_edit == null:
		return
	var severity := str(_last_status.get("session_diagnostics", {}).get("severity", "attention"))
	var kind := "checkpoint"
	if severity == "ready":
		kind = "ready"
	control_message_requested.emit({
		"type": "capture_run_snapshot",
		"kind": kind,
		"origin": "quest",
		"note": snapshot_note_edit.text.strip_edges(),
	})
	snapshot_note_edit.clear()


func _on_report_issue_pressed() -> void:
	if snapshot_note_edit == null:
		return
	control_message_requested.emit({
		"type": "capture_run_snapshot",
		"kind": "issue",
		"origin": "quest",
		"note": snapshot_note_edit.text.strip_edges(),
	})
	snapshot_note_edit.clear()


func _on_export_report_pressed() -> void:
	if snapshot_note_edit == null:
		return
	control_message_requested.emit({
		"type": "export_session_report",
		"note": snapshot_note_edit.text.strip_edges(),
	})
	snapshot_note_edit.clear()


func _require_panel_node(quest_panel: Control, node_path: String) -> Node:
	var node := quest_panel.get_node_or_null(node_path)
	if node == null:
		QuestRuntimeLog.error("UI_BIND_MISSING_NODE", {
			"path": node_path,
			"error": "Quest panel missing node: %s" % node_path,
		})
	return node


func _has_bound_controls() -> bool:
	return preset_select != null \
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
		and workflow_diagnostics_label != null
