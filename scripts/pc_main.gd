extends Control

const MappingEngine = preload("res://scripts/mapping/mapping_engine.gd")
const MappingTemplate = preload("res://scripts/mapping/mapping_template.gd")
const TemplateSummaryFormatter = preload("res://scripts/mapping/template_summary_formatter.gd")
const FailsafeSupervisor = preload("res://scripts/mapping/failsafe_supervisor.gd")
const SourceDeriver = preload("res://scripts/telemetry/source_deriver.gd")
const TemplateManager = preload("res://scripts/ui/template_manager.gd")
const WorkflowEditorPanel = preload("res://scripts/ui/workflow_editor_panel.gd")
const WorkflowRunPanel = preload("res://scripts/ui/workflow_run_panel.gd")
const SessionBaselineComparator = preload("res://scripts/workflow/session_baseline_comparator.gd")
const SessionProfile = preload("res://scripts/workflow/session_profile.gd")
const SessionProfileStore = preload("res://scripts/workflow/session_profile_store.gd")
const SessionReportExporter = preload("res://scripts/workflow/session_report_exporter.gd")
const SessionRunStore = preload("res://scripts/workflow/session_run_store.gd")

@onready var telemetry_receiver: Node = $TelemetryReceiver
@onready var control_server: Node = $ControlServer
@onready var inspect_server: Node = $InspectServer
@onready var backend: Node = $LinuxGamepadBackend
@onready var discovery_beacon: Node = $DiscoveryBeacon
@onready var quest_status_panel: QuestStatusPanel = $VBox/StatusPanel
@onready var workflow_editor: WorkflowEditorPanel = $VBox/MainSplit/LeftColumnScroll/LeftColumn/WorkflowEditorPanel
@onready var workflow_run_panel: WorkflowRunPanel = $VBox/MainSplit/LeftColumnScroll/LeftColumn/WorkflowRunPanel
@onready var template_editor: TemplateEditor = $VBox/MainSplit/LeftColumnScroll/LeftColumn/TemplateEditor
@onready var raw_panel: TelemetryPanel = $VBox/MainSplit/Panels/RawPanel
@onready var derived_panel: TelemetryPanel = $VBox/MainSplit/Panels/DerivedPanel
@onready var output_panel: TelemetryPanel = $VBox/MainSplit/Panels/OutputPanel

var _source_deriver: SourceDeriver = SourceDeriver.new()
var _mapping_engine: MappingEngine = MappingEngine.new()
var _failsafe: FailsafeSupervisor = FailsafeSupervisor.new()
var _template_manager: TemplateManager = TemplateManager.new()
var _template_summary_formatter := TemplateSummaryFormatter.new()
var _session_baseline_comparator: SessionBaselineComparator = SessionBaselineComparator.new()
var _session_store: SessionProfileStore = SessionProfileStore.new()
var _session_report_exporter: SessionReportExporter = SessionReportExporter.new()
var _session_run_store: SessionRunStore = SessionRunStore.new()
var _session_profile: SessionProfile = SessionProfile.new()
var _session_run_history: Array = []
var _last_report_export: Dictionary = {}
var _active_template: MappingTemplate
var _active_template_summary_cache: Dictionary = {}
var _active_template_payload_cache: Dictionary = {}
var _runtime_template: MappingTemplate
var _last_timestamp_usec: int = 0
var _last_outputs: Dictionary = {}
var _was_failsafe_active: bool = true
var _last_control_active: bool = false
var _last_status_send_usec: int = 0
var _live_tuning_settings: Dictionary = {}
var _pending_raw_state: Dictionary = {}
var _pending_derived: Dictionary = {}
var _pending_outputs: Dictionary = {}
var _ui_dirty: bool = false
var _quest_runtime_diagnostics: Dictionary = {}


func _ready() -> void:
	telemetry_receiver.state_received.connect(_on_state_received)
	control_server.message_received.connect(_on_control_message)
	control_server.client_connected.connect(_send_initial_status)
	control_server.client_disconnected.connect(_on_control_client_disconnected)
	inspect_server.query_received.connect(_on_inspect_query)
	workflow_editor.profile_applied.connect(_on_session_profile_applied)
	workflow_editor.reload_requested.connect(_reload_session_profile)
	workflow_run_panel.snapshot_requested.connect(_on_snapshot_requested)
	workflow_run_panel.export_requested.connect(_on_export_requested)
	template_editor.template_applied.connect(_apply_template)
	template_editor.template_saved.connect(_on_template_saved)
	template_editor.template_deleted.connect(_on_template_deleted)
	_session_run_history = _session_run_store.load_history()
	workflow_run_panel.set_history(_session_run_history)
	workflow_run_panel.set_last_report_export(_last_report_export)
	_reload_session_profile()

	var template_ids: PackedStringArray = _template_manager.list_ids()
	if template_ids.size() > 0:
		var template: MappingTemplate = _template_manager.load_template(template_ids[0])
		if template != null:
			_apply_template(template)


func _process(_delta: float) -> void:
	if _active_template == null:
		return
	var status_payload := _build_status_payload()
	quest_status_panel.set_status(status_payload)
	workflow_editor.set_runtime_status(status_payload)
	workflow_run_panel.set_runtime_status(status_payload)
	if _ui_dirty:
		_ui_dirty = false
		raw_panel.set_payload("Raw Telemetry", _serialize_state_for_ui(_pending_raw_state))
		derived_panel.set_payload("Derived Sources", _pending_derived)
		output_panel.set_payload("Mapped Outputs", _pending_outputs)


func _on_state_received(state: Dictionary) -> void:
	var now_usec: int = Time.get_ticks_usec()
	if state.get("event_flags", 0) & RawControllerState.EVENT_SET_ORIGIN and bool(state.get("tracking_valid", false)):
		_source_deriver.calibrate_from_state(state)
		_mapping_engine.reset_state()
	if state.get("event_flags", 0) & RawControllerState.EVENT_CLEAR_ORIGIN:
		_source_deriver.reset_calibration()
		_mapping_engine.reset_state()

	_failsafe.note_state(state, now_usec)
	var dt: float = 0.0
	var timestamp_usec := int(state.get("timestamp_usec", 0))
	if _last_timestamp_usec > 0 and timestamp_usec > _last_timestamp_usec:
		dt = float(timestamp_usec - _last_timestamp_usec) / 1000000.0
	_last_timestamp_usec = timestamp_usec

	var derived: Dictionary = _source_deriver.derive_sources(state)
	var control_active := bool(state.get("control_active", false))
	if not control_active and _last_control_active:
		_mapping_engine.reset_state()
	var outputs: Dictionary
	if not _failsafe.update(now_usec):
		if _was_failsafe_active:
			_mapping_engine.reset_state()
			_was_failsafe_active = false
		outputs = _mapping_engine.process(derived, dt)
		if not control_active:
			outputs = _neutralize_motion_outputs(outputs)
	else:
		_was_failsafe_active = true
		_mapping_engine.reset_state()
		outputs = _mapping_engine.neutral_outputs()

	_last_control_active = control_active
	_last_outputs = outputs
	backend.push_state(outputs)

	_pending_raw_state = state
	_pending_derived = derived
	_pending_outputs = outputs
	_ui_dirty = true

	if now_usec - _last_status_send_usec > 100000:
		_send_status_update()
		_last_status_send_usec = now_usec


func _apply_template(template: MappingTemplate) -> void:
	_active_template = template
	_refresh_active_template_cache()
	_live_tuning_settings.clear()
	_rebuild_runtime_template()
	template_editor.set_template(template)
	_send_initial_status()


func _on_template_saved(template: MappingTemplate) -> void:
	_template_manager.refresh()
	_apply_template(template)


func _on_template_deleted(_template_id: String) -> void:
	_template_manager.refresh()
	_send_initial_status()


func _on_control_message(message: Dictionary) -> void:
	match str(message.get("type", "")):
		"hello":
			_quest_runtime_diagnostics = message.get("diagnostics", {}).duplicate(true)
			_send_initial_status()
		"quest_diagnostics":
			_quest_runtime_diagnostics = message.get("diagnostics", {}).duplicate(true)
			_send_status_update()
		"select_template":
			var template_id: String = str(message.get("template_id", ""))
			var template: MappingTemplate = _template_manager.load_template(template_id)
			if template != null:
				_apply_template(template)
		"duplicate_template":
			var duplicate := _template_manager.copy_to_user_template(str(message.get("template_id", "")))
			if duplicate != null:
				_apply_template(duplicate)
				_send_initial_status()
		"create_blank_template":
			var blank := _template_manager.create_blank_template(str(message.get("display_name", "New Template")))
			_apply_template(blank)
			_send_initial_status()
		"apply_template":
			var template := MappingTemplate.new()
			template.from_dict(message.get("template", {}))
			_apply_template(template)
		"save_template":
			var template := MappingTemplate.new()
			template.from_dict(message.get("template", {}))
			if _template_manager.save_user_template(template) == OK:
				_template_manager.refresh()
				_apply_template(template)
		"delete_template":
			if _template_manager.delete_user_template(str(message.get("template_id", ""))) == OK:
				_template_manager.refresh()
				var template_ids: PackedStringArray = _template_manager.list_ids()
				if not template_ids.is_empty():
					var fallback := _template_manager.load_template(template_ids[0])
					if fallback != null:
						_apply_template(fallback)
				_send_initial_status()
		"apply_tuning":
			_apply_global_tuning(message.get("settings", {}))
		"set_session_mode":
			_session_profile.set_mode(str(message.get("mode", "")))
			_session_profile.set_preset(SessionProfile.PRESET_CUSTOM)
			_persist_and_broadcast_session_profile()
		"set_session_preset":
			_session_profile.apply_preset(str(message.get("preset_id", "")))
			_persist_and_broadcast_session_profile()
		"set_session_details":
			_session_profile.apply_session_details(
				str(message.get("run_label", "")),
				int(message.get("latency_budget_ms", 0)),
				str(message.get("operator_note", "")),
				int(message.get("observed_latency_ms", 0)),
				int(message.get("focus_loss_events", 0))
			)
			_session_profile.set_preset(SessionProfile.PRESET_CUSTOM)
			_persist_and_broadcast_session_profile()
		"set_stream_client":
			_session_profile.set_stream_client(str(message.get("stream_client", "")))
			_session_profile.set_preset(SessionProfile.PRESET_CUSTOM)
			_persist_and_broadcast_session_profile()
		"set_manual_check":
			_session_profile.set_manual_check(
				str(message.get("check_id", "")),
				bool(message.get("checked", false))
			)
			_persist_and_broadcast_session_profile()
		"capture_run_snapshot":
			_capture_run_snapshot(
				str(message.get("kind", SessionRunStore.KIND_CHECKPOINT)),
				str(message.get("note", "")),
				str(message.get("origin", SessionRunStore.ORIGIN_QUEST))
			)
		"export_session_report":
			_export_session_report(str(message.get("note", "")))
		"inspect_tree_result", "inspect_node_result":
			if inspect_server != null:
				inspect_server.deliver_response(message)


func _on_inspect_query(message: Dictionary) -> void:
	if control_server.has_client():
		control_server.send_message(message)
	else:
		inspect_server.deliver_response({
			"request_id": str(message.get("request_id", "")),
			"ok": false,
			"error": "No Quest connected",
		})


func _on_control_client_disconnected() -> void:
	_quest_runtime_diagnostics = {}
	_send_status_update()


func _apply_global_tuning(settings: Dictionary) -> void:
	if _active_template == null:
		return
	_live_tuning_settings.merge(settings, true)
	_rebuild_runtime_template()
	_send_status_update()


func _rebuild_runtime_template() -> void:
	if _active_template == null:
		_runtime_template = null
		return
	_runtime_template = _active_template.with_global_tuning(_live_tuning_settings)
	_mapping_engine.set_template(_runtime_template)


func _send_initial_status() -> void:
	if not control_server.has_client():
		return
	control_server.send_message({
		"type": "hello_ack",
		"backend": "linux",
		"failsafe_timeout_ms": _failsafe.timeout_usec / 1000,
	})
	control_server.send_message({
		"type": "template_catalog",
		"templates": _template_manager.list_templates(),
	})
	_send_session_profile()
	_send_status_update()


func _send_session_profile() -> void:
	if not control_server.has_client():
		return
	control_server.send_message({
		"type": "session_profile",
		"profile": _session_profile.to_dict(),
	})


func _send_status_update() -> void:
	if not control_server.has_client():
		return
	control_server.send_message({
		"type": "active_template",
		"template_id": _active_template.template_id if _active_template != null else "",
		"template_summary": _active_template_summary(),
		"template": _active_template_payload(),
	})
	var status_payload := _build_status_payload()
	status_payload["type"] = "status"
	control_server.send_message(status_payload)


func _serialize_state_for_ui(state: Dictionary) -> Dictionary:
	return {
		"sequence": state.get("sequence", 0),
		"timestamp_usec": state.get("timestamp_usec", 0),
		"tracking_valid": state.get("tracking_valid", false),
		"control_active": state.get("control_active", false),
		"event_flags": state.get("event_flags", 0),
		"buttons": state.get("buttons", 0),
		"grip_position": str(state.get("grip_position", Vector3.ZERO)),
		"grip_orientation": str(state.get("grip_orientation", Quaternion.IDENTITY)),
		"linear_velocity": str(state.get("linear_velocity", Vector3.ZERO)),
		"angular_velocity": str(state.get("angular_velocity", Vector3.ZERO)),
		"trigger": state.get("trigger", 0.0),
		"grip": state.get("grip", 0.0),
		"thumbstick": str(state.get("thumbstick", Vector2.ZERO)),
	}


func _summarize_outputs(outputs: Dictionary) -> Dictionary:
	return {
		"throttle": snappedf(float(outputs.get("throttle", 0.0)), 0.01),
		"yaw": snappedf(float(outputs.get("yaw", 0.0)), 0.01),
		"pitch": snappedf(float(outputs.get("pitch", 0.0)), 0.01),
		"roll": snappedf(float(outputs.get("roll", 0.0)), 0.01),
		"aux_button_1": float(outputs.get("aux_button_1", 0.0)),
	}


func _build_status_payload() -> Dictionary:
	var payload := {
		"connected": control_server.has_client(),
		"template_id": _active_template.template_id if _active_template != null else "",
		"template_name": _active_template.display_name if _active_template != null else "",
		"template_slug": _active_template.slug if _active_template != null else "",
		"template_summary": _active_template_summary(),
		"template": _active_template_payload(),
		"failsafe_active": _failsafe.is_active(),
		"packets_received": telemetry_receiver.packets_received,
		"packets_dropped": telemetry_receiver.packets_dropped,
		"backend_available": backend.is_available(),
		"backend_name": "linux_gamepad",
		"session_preset_id": _session_profile.preset_id,
		"session_preset_label": _session_profile.get_preset_label(),
		"session_mode": _session_profile.mode,
		"session_mode_label": _session_profile.get_mode_label(),
		"session_stream_client": _session_profile.stream_client,
		"session_stream_client_label": _session_profile.get_stream_client_label(),
		"session_stream_client_enabled": _session_profile.supports_stream_client_selection(),
		"session_run_label": _session_profile.run_label,
		"session_latency_budget_ms": _session_profile.latency_budget_ms,
		"session_observed_latency_ms": _session_profile.observed_latency_ms,
		"session_focus_loss_events": _session_profile.focus_loss_events,
		"session_operator_note": _session_profile.operator_note,
		"session_manual_checks": _session_profile.manual_checks.duplicate(true),
		"session_manual_check_items": _session_profile.manual_check_items(),
		"session_manual_check_summary": _session_profile.get_manual_check_summary(),
		"workflow_hint": _session_profile.get_workflow_hint(),
		"output_summary": _summarize_outputs(_last_outputs),
		"last_outputs": _last_outputs,
		"control_active": bool(_pending_raw_state.get("control_active", false)),
		"last_report_export": _last_report_export.duplicate(true),
		"recent_run_snapshots": SessionRunStore.recent_entries(_session_run_history, 3),
		"quest_runtime_diagnostics": _quest_runtime_diagnostics.duplicate(true),
	}
	payload.merge(control_server.get_diagnostics(), true)
	payload.merge(discovery_beacon.get_diagnostics(), true)
	payload["session_diagnostics"] = _session_profile.build_diagnostics(payload)
	payload["session_playbook"] = _session_profile.build_operator_playbook(payload)
	payload["baseline_comparison"] = _session_baseline_comparator.build_comparison(
		_session_profile,
		payload,
		_session_run_history
	)
	return payload


func _active_template_summary() -> Dictionary:
	if _active_template == null:
		return {}
	return _active_template_summary_cache


func _active_template_payload() -> Dictionary:
	if _active_template == null:
		return {}
	return _active_template_payload_cache


func _refresh_active_template_cache() -> void:
	if _active_template == null:
		_active_template_summary_cache = {}
		_active_template_payload_cache = {}
		return
	_active_template_summary_cache = _template_summary_formatter.build_summary(_active_template)
	_active_template_payload_cache = _active_template.to_dict()


func _neutralize_motion_outputs(outputs: Dictionary) -> Dictionary:
	var neutralized := outputs.duplicate(true)
	for output_name in ["throttle", "yaw", "pitch", "roll"]:
		neutralized[output_name] = 0.0
	return neutralized


func _on_session_profile_applied(profile: SessionProfile) -> void:
	_session_profile = profile.duplicate_profile()
	_persist_and_broadcast_session_profile()


func _on_snapshot_requested(kind: String, note: String) -> void:
	_capture_run_snapshot(kind, note, SessionRunStore.ORIGIN_PC)


func _on_export_requested(note: String) -> void:
	_export_session_report(note)


func _reload_session_profile() -> void:
	_session_profile = _session_store.load_profile()
	workflow_editor.set_profile(_session_profile)
	workflow_run_panel.set_profile(_session_profile)
	workflow_run_panel.set_last_report_export(_last_report_export)
	_send_session_profile()
	_send_status_update()


func _persist_and_broadcast_session_profile() -> void:
	_session_store.save_profile(_session_profile)
	workflow_editor.set_profile(_session_profile)
	workflow_run_panel.set_profile(_session_profile)
	_send_session_profile()
	_send_status_update()


func _capture_run_snapshot(kind: String, note: String, origin: String) -> void:
	var status_payload := _build_status_payload()
	_session_run_history = _session_run_store.append_snapshot(
		_session_profile,
		status_payload,
		kind,
		origin,
		note
	)
	workflow_run_panel.set_history(_session_run_history)
	_send_status_update()


func _export_session_report(note: String = "") -> void:
	var status_payload := _build_status_payload()
	var export_info := _session_report_exporter.export_report(
		_session_profile,
		status_payload,
		_session_run_history,
		note
	)
	if bool(export_info.get("ok", false)):
		_last_report_export = {
			"report_name": export_info.get("report_name", ""),
			"summary": export_info.get("summary", ""),
			"severity": export_info.get("severity", "attention"),
			"snapshot_count": export_info.get("snapshot_count", 0),
			"exported_at_unix": export_info.get("exported_at_unix", 0),
			"exported_at_text": export_info.get("exported_at_text", ""),
			"markdown_user_path": export_info.get("markdown_user_path", ""),
			"json_user_path": export_info.get("json_user_path", ""),
			"markdown_path": export_info.get("markdown_path", ""),
			"json_path": export_info.get("json_path", ""),
		}
	else:
		_last_report_export = {
			"report_name": export_info.get("report_name", ""),
			"summary": "Export failed: %s" % error_string(int(export_info.get("error", ERR_CANT_CREATE))),
			"severity": "warning",
			"snapshot_count": 0,
			"exported_at_unix": int(Time.get_unix_time_from_system()),
			"exported_at_text": Time.get_datetime_string_from_unix_time(
				int(Time.get_unix_time_from_system()),
				false
			),
		}
	workflow_run_panel.set_last_report_export(_last_report_export)
	_send_status_update()
