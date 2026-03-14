class_name SessionBaselineComparator
extends RefCounted

const SessionProfile = preload("res://scripts/workflow/session_profile.gd")
const SessionRunStore = preload("res://scripts/workflow/session_run_store.gd")


func build_comparison(
	profile: SessionProfile,
	runtime_status: Dictionary,
	history: Array
) -> Dictionary:
	var reference := _find_reference_snapshot(profile, history)
	if reference.is_empty():
		return _missing_reference(profile)

	var current_latency_ms := profile.observed_latency_ms
	if current_latency_ms <= 0:
		current_latency_ms = int(runtime_status.get("session_observed_latency_ms", 0))
	var current_focus_loss_events := profile.focus_loss_events
	if current_focus_loss_events <= 0:
		current_focus_loss_events = int(runtime_status.get("session_focus_loss_events", 0))
	var current_packet_drops := int(runtime_status.get("packets_dropped", 0))

	var reference_latency_ms := int(reference.get("observed_latency_ms", 0))
	var reference_focus_loss_events := int(reference.get("focus_loss_events", 0))
	var reference_packet_drops := int(reference.get("packets_dropped", 0))

	var has_latency_delta := current_latency_ms > 0 and reference_latency_ms > 0
	var latency_delta_ms := current_latency_ms - reference_latency_ms
	var focus_loss_delta := current_focus_loss_events - reference_focus_loss_events
	var packet_drop_delta := current_packet_drops - reference_packet_drops
	var severity := _comparison_severity(has_latency_delta, latency_delta_ms, focus_loss_delta, packet_drop_delta)
	var recommendations := _build_recommendations(
		profile,
		has_latency_delta,
		latency_delta_ms,
		focus_loss_delta,
		packet_drop_delta
	)

	return {
		"available": true,
		"summary": _build_summary(
			profile,
			reference,
			has_latency_delta,
			latency_delta_ms,
			focus_loss_delta,
			packet_drop_delta
		),
		"severity": severity,
		"reference_label": _reference_label(reference),
		"reference_snapshot": reference.duplicate(true),
		"latency_delta_ms": latency_delta_ms if has_latency_delta else 0,
		"has_latency_delta": has_latency_delta,
		"focus_loss_delta": focus_loss_delta,
		"packet_drop_delta": packet_drop_delta,
		"recommendations": recommendations,
	}


func _find_reference_snapshot(profile: SessionProfile, history: Array) -> Dictionary:
	var target_mode := profile.mode
	if profile.mode == SessionProfile.MODE_EXPERIMENTAL_STREAM:
		target_mode = SessionProfile.MODE_PASSTHROUGH_STANDALONE
	for entry in history:
		if typeof(entry) != TYPE_DICTIONARY:
			continue
		var normalized: Dictionary = entry.duplicate(true)
		if str(normalized.get("kind", SessionRunStore.KIND_CHECKPOINT)) != SessionRunStore.KIND_READY:
			continue
		if str(normalized.get("mode", "")) != target_mode:
			continue
		return normalized
	return {}


func _missing_reference(profile: SessionProfile) -> Dictionary:
	var summary := "Capture a ready comparison snapshot before judging this run."
	if profile.mode == SessionProfile.MODE_EXPERIMENTAL_STREAM:
		summary = "Capture a ready passthrough baseline snapshot before judging the Quest multitask experiment."
	return {
		"available": false,
		"summary": summary,
		"severity": "attention",
		"reference_label": "",
		"reference_snapshot": {},
		"latency_delta_ms": 0,
		"has_latency_delta": false,
		"focus_loss_delta": 0,
		"packet_drop_delta": 0,
		"recommendations": [summary],
	}


func _build_summary(
	profile: SessionProfile,
	reference: Dictionary,
	has_latency_delta: bool,
	latency_delta_ms: int,
	focus_loss_delta: int,
	packet_drop_delta: int
) -> String:
	var parts := PackedStringArray()
	if has_latency_delta:
		parts.append("latency %s ms" % _signed_value(latency_delta_ms))
	if focus_loss_delta != 0 or int(reference.get("focus_loss_events", 0)) > 0 or profile.focus_loss_events > 0:
		parts.append("focus %s" % _signed_value(focus_loss_delta))
	if packet_drop_delta != 0 or int(reference.get("packets_dropped", 0)) > 0:
		parts.append("drops %s" % _signed_value(packet_drop_delta))
	if parts.is_empty():
		return "Tracking close to %s." % _reference_label(reference)
	return "Vs %s: %s." % [
		_reference_label(reference),
		", ".join(parts),
	]


func _build_recommendations(
	profile: SessionProfile,
	has_latency_delta: bool,
	latency_delta_ms: int,
	focus_loss_delta: int,
	packet_drop_delta: int
) -> Array:
	var items: Array = []
	if profile.mode == SessionProfile.MODE_EXPERIMENTAL_STREAM and not has_latency_delta:
		items.append("Record observed latency so the multitask run can be compared against the baseline.")
	if has_latency_delta and latency_delta_ms > 20:
		items.append("Streaming adds %d ms over baseline; reduce stream quality or scene load before the next pass." % latency_delta_ms)
	if focus_loss_delta > 0:
		items.append("The multitask run lost focus %d more time(s) than the reference snapshot." % focus_loss_delta)
	if packet_drop_delta > 2:
		items.append("Packet drops increased by %d compared with the reference snapshot; inspect Wi-Fi stability." % packet_drop_delta)
	if items.is_empty():
		items.append("Current run is tracking close to the latest ready reference snapshot.")
	return items


func _comparison_severity(
	has_latency_delta: bool,
	latency_delta_ms: int,
	focus_loss_delta: int,
	packet_drop_delta: int
) -> String:
	if (has_latency_delta and latency_delta_ms > 35) or focus_loss_delta > 1 or packet_drop_delta > 5:
		return "warning"
	if (has_latency_delta and latency_delta_ms > 15) or focus_loss_delta > 0 or packet_drop_delta > 2:
		return "attention"
	return "ready"


func _reference_label(reference: Dictionary) -> String:
	var run_label := str(reference.get("run_label", ""))
	var preset_label := str(reference.get("preset_label", "Reference"))
	var captured_at := str(reference.get("captured_at_text", ""))
	var label := preset_label
	if not run_label.is_empty():
		label = "%s (%s)" % [preset_label, run_label]
	if not captured_at.is_empty():
		label = "%s @ %s" % [label, captured_at]
	return label


func _signed_value(value: int) -> String:
	if value > 0:
		return "+%d" % value
	return "%d" % value
