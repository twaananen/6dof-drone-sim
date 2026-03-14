class_name SessionRunStore
extends RefCounted

const SessionProfile = preload("res://scripts/workflow/session_profile.gd")

const DEFAULT_HISTORY_PATH := "user://workflow/run_history.json"
const KIND_CHECKPOINT := "checkpoint"
const KIND_READY := "ready"
const KIND_ISSUE := "issue"
const ORIGIN_PC := "pc"
const ORIGIN_QUEST := "quest"

var history_path: String = DEFAULT_HISTORY_PATH
var max_entries: int = 24


func _init(next_history_path: String = DEFAULT_HISTORY_PATH, next_max_entries: int = 24) -> void:
	history_path = next_history_path
	max_entries = maxi(next_max_entries, 1)


func load_history() -> Array:
	_ensure_parent_dir()
	if not FileAccess.file_exists(history_path):
		return []

	var file := FileAccess.open(history_path, FileAccess.READ)
	if file == null:
		return []
	var text := file.get_as_text()
	file.close()

	var json := JSON.new()
	if json.parse(text) != OK:
		return []

	var raw_entries: Array = []
	if typeof(json.data) == TYPE_ARRAY:
		raw_entries = json.data
	elif typeof(json.data) == TYPE_DICTIONARY:
		raw_entries = json.data.get("entries", [])

	var entries: Array = []
	for raw_entry in raw_entries:
		if typeof(raw_entry) == TYPE_DICTIONARY:
			entries.append(_normalize_entry(raw_entry))
	return _truncate_history(entries)


func save_history(entries: Array) -> Error:
	_ensure_parent_dir()
	var file := FileAccess.open(history_path, FileAccess.WRITE)
	if file == null:
		return FileAccess.get_open_error()
	file.store_string(JSON.stringify(_truncate_history(entries), "\t"))
	file.close()
	return OK


func append_snapshot(
	profile: SessionProfile,
	runtime_status: Dictionary,
	kind: String = KIND_CHECKPOINT,
	origin: String = ORIGIN_PC,
	note: String = ""
) -> Array:
	var history := load_history()
	history.push_front(build_snapshot(profile, runtime_status, kind, origin, note))
	save_history(history)
	return load_history()


static func build_snapshot(
	profile: SessionProfile,
	runtime_status: Dictionary,
	kind: String = KIND_CHECKPOINT,
	origin: String = ORIGIN_PC,
	note: String = ""
) -> Dictionary:
	var diagnostics: Dictionary = runtime_status.get("session_diagnostics", {})
	if diagnostics.is_empty():
		diagnostics = profile.build_diagnostics(runtime_status)
	var output_summary: Dictionary = runtime_status.get("output_summary", {}).duplicate(true)
	var timestamp_unix := int(Time.get_unix_time_from_system())
	return {
		"id": "%d" % Time.get_ticks_usec(),
		"captured_at_unix": timestamp_unix,
		"captured_at_text": Time.get_datetime_string_from_unix_time(timestamp_unix, false),
		"kind": normalize_kind(kind),
		"origin": normalize_origin(origin),
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
		"manual_check_summary": profile.get_manual_check_summary(),
		"workflow_hint": profile.get_workflow_hint(),
		"note": note.strip_edges(),
		"diagnostics_summary": str(diagnostics.get("summary", "")),
		"diagnostics_severity": str(diagnostics.get("severity", "attention")),
		"connected": bool(runtime_status.get("connected", false)),
		"backend_available": bool(runtime_status.get("backend_available", false)),
		"failsafe_active": bool(runtime_status.get("failsafe_active", false)),
		"packets_received": int(runtime_status.get("packets_received", 0)),
		"packets_dropped": int(runtime_status.get("packets_dropped", 0)),
		"output_summary": output_summary,
	}


static func recent_entries(entries: Array, limit: int = 3) -> Array:
	var subset: Array = []
	for index in range(mini(limit, entries.size())):
		subset.append(_normalize_entry(entries[index]))
	return subset


static func normalize_kind(kind: String) -> String:
	match kind:
		KIND_READY, KIND_ISSUE:
			return kind
		_:
			return KIND_CHECKPOINT


static func normalize_origin(origin: String) -> String:
	if origin == ORIGIN_QUEST:
		return ORIGIN_QUEST
	return ORIGIN_PC


static func _normalize_entry(entry: Dictionary) -> Dictionary:
	var normalized_output_summary: Dictionary = {}
	if typeof(entry.get("output_summary", {})) == TYPE_DICTIONARY:
		normalized_output_summary = entry.get("output_summary", {}).duplicate(true)
	var normalized := {
		"id": str(entry.get("id", "")),
		"captured_at_unix": int(entry.get("captured_at_unix", 0)),
		"captured_at_text": str(entry.get("captured_at_text", "")),
		"kind": normalize_kind(str(entry.get("kind", KIND_CHECKPOINT))),
		"origin": normalize_origin(str(entry.get("origin", ORIGIN_PC))),
		"run_label": str(entry.get("run_label", "")),
		"preset_id": str(entry.get("preset_id", SessionProfile.PRESET_PASSTHROUGH_BASELINE)),
		"preset_label": str(entry.get("preset_label", "Passthrough Baseline")),
		"mode": str(entry.get("mode", SessionProfile.MODE_PASSTHROUGH_STANDALONE)),
		"mode_label": str(entry.get("mode_label", "Passthrough Standalone")),
		"stream_client": str(entry.get("stream_client", SessionProfile.STREAM_CLIENT_NONE)),
		"stream_client_label": str(entry.get("stream_client_label", "Choose Stream App")),
		"latency_budget_ms": int(entry.get("latency_budget_ms", 0)),
		"observed_latency_ms": int(entry.get("observed_latency_ms", 0)),
		"focus_loss_events": int(entry.get("focus_loss_events", 0)),
		"manual_check_summary": str(entry.get("manual_check_summary", "")),
		"workflow_hint": str(entry.get("workflow_hint", "")),
		"note": str(entry.get("note", "")),
		"diagnostics_summary": str(entry.get("diagnostics_summary", "")),
		"diagnostics_severity": str(entry.get("diagnostics_severity", "attention")),
		"connected": bool(entry.get("connected", false)),
		"backend_available": bool(entry.get("backend_available", false)),
		"failsafe_active": bool(entry.get("failsafe_active", false)),
		"packets_received": int(entry.get("packets_received", 0)),
		"packets_dropped": int(entry.get("packets_dropped", 0)),
		"output_summary": normalized_output_summary,
	}
	if normalized["captured_at_text"].is_empty() and normalized["captured_at_unix"] > 0:
		normalized["captured_at_text"] = Time.get_datetime_string_from_unix_time(
			normalized["captured_at_unix"],
			false
		)
	return normalized


func _truncate_history(entries: Array) -> Array:
	var truncated: Array = []
	for index in range(mini(max_entries, entries.size())):
		if typeof(entries[index]) == TYPE_DICTIONARY:
			truncated.append(_normalize_entry(entries[index]))
	return truncated


func _ensure_parent_dir() -> void:
	var parent_dir := history_path.get_base_dir()
	if parent_dir.is_empty():
		return
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(parent_dir))
