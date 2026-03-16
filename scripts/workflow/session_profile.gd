class_name SessionProfile
extends RefCounted

const MODE_PASSTHROUGH_STANDALONE := "passthrough_standalone"
const MODE_EXPERIMENTAL_STREAM := "experimental_stream"
const MODE_DESKTOP_BENCH := "desktop_bench"

const PRESET_CUSTOM := "custom"
const PRESET_PASSTHROUGH_BASELINE := "passthrough_baseline"
const PRESET_STEAM_LINK_MULTITASK := "steam_link_multitask"
const PRESET_VIRTUAL_DESKTOP_MULTITASK := "virtual_desktop_multitask"
const PRESET_DESKTOP_BENCH := "desktop_bench"

const PLAYBOOK_PHASE_SETUP := "setup"
const PLAYBOOK_PHASE_VALIDATE := "validate"
const PLAYBOOK_PHASE_DEBUG := "debug"
const PLAYBOOK_PHASE_READY := "ready"

const STREAM_CLIENT_NONE := "none"
const STREAM_CLIENT_STEAM_LINK := "steam_link"
const STREAM_CLIENT_VIRTUAL_DESKTOP := "virtual_desktop"

const _MODE_DEFAULT := MODE_PASSTHROUGH_STANDALONE
const _MODE_ENTRIES := {
	MODE_PASSTHROUGH_STANDALONE: {
		"label": "Passthrough Standalone",
		"experimental": false,
		"workflow_hint": "Recommended. Run the controller app on Quest and view the sim on a monitor through passthrough.",
	},
	MODE_EXPERIMENTAL_STREAM: {
		"label": "Experimental Stream",
		"experimental": true,
		"workflow_hint": "Quest multitasking experiment. Expect focus and latency issues while validating side-by-side streaming.",
	},
	MODE_DESKTOP_BENCH: {
		"label": "Desktop Bench",
		"experimental": false,
		"workflow_hint": "Desktop-only debug mode for verifying templates, failsafe behavior, and backend output without XR.",
	},
}
const _STREAM_CLIENT_DEFAULT := STREAM_CLIENT_NONE
const _STREAM_CLIENT_ENTRIES := {
	STREAM_CLIENT_NONE: {
		"label": "Choose Stream App",
		"detail": "Pick the Quest multitasking client you want to validate.",
	},
	STREAM_CLIENT_STEAM_LINK: {
		"label": "Steam Link",
		"detail": "Best first experiment when the simulator already runs on a nearby gaming PC.",
	},
	STREAM_CLIENT_VIRTUAL_DESKTOP: {
		"label": "Virtual Desktop",
		"detail": "Useful when testing pinned windows or comparing alternate streaming latency behavior.",
	},
}
const _MANUAL_CHECK_ENTRIES := {
	MODE_PASSTHROUGH_STANDALONE: [
		{
			"id": "passthrough_view_ready",
			"label": "Passthrough view and monitor ready",
			"detail": "Confirm the Quest passthrough view is clear and the simulator monitor is visible.",
		},
		{
			"id": "controller_calibrated",
			"label": "Flight origin set",
			"detail": "Set a fresh flight origin for this session before evaluating mappings.",
		},
		{
			"id": "template_response_verified",
			"label": "Template response verified",
			"detail": "Move the controller and confirm mapped outputs respond as expected.",
		},
	],
	MODE_EXPERIMENTAL_STREAM: [
		{
			"id": "stream_window_visible",
			"label": "Stream window visible",
			"detail": "Open Steam Link or Virtual Desktop beside the controller app.",
		},
		{
			"id": "multitask_layout_stable",
			"label": "Multitask layout stays stable",
			"detail": "Pinned windows remain visible while moving around the headset UI.",
		},
		{
			"id": "input_focus_verified",
			"label": "Input focus verified",
			"detail": "Controller input still reaches the sim after switching apps.",
		},
		{
			"id": "latency_checked",
			"label": "Latency measured",
			"detail": "Measure stick-to-screen latency against the session budget.",
		},
	],
	MODE_DESKTOP_BENCH: [
		{
			"id": "backend_injection_verified",
			"label": "Backend injection verified",
			"detail": "Confirm the desktop backend or virtual gamepad sink is active.",
		},
		{
			"id": "template_response_verified",
			"label": "Template response verified",
			"detail": "Move the controller and confirm mapped outputs respond as expected.",
		},
		{
			"id": "failsafe_recovery_tested",
			"label": "Failsafe recovery tested",
			"detail": "Pause telemetry, confirm neutral outputs, then restore telemetry and recover control.",
		},
	],
}
const _PRESET_DEFAULT := PRESET_PASSTHROUGH_BASELINE
const _PRESET_ENTRIES := {
	PRESET_CUSTOM: {
		"label": "Custom Workflow",
		"detail": "Manual workflow edits that no longer match one of the suggested presets.",
		"mode": MODE_PASSTHROUGH_STANDALONE,
		"stream_client": STREAM_CLIENT_NONE,
		"run_label": "Custom workflow",
		"latency_budget_ms": 0,
		"operator_note": "",
	},
	PRESET_PASSTHROUGH_BASELINE: {
		"label": "Passthrough Baseline",
		"detail": "Lowest-latency baseline with the simulator on a monitor and the controller app on Quest.",
		"mode": MODE_PASSTHROUGH_STANDALONE,
		"stream_client": STREAM_CLIENT_NONE,
		"run_label": "Baseline passthrough",
		"latency_budget_ms": 25,
		"operator_note": "Capture the lowest-latency baseline before changing templates or adding streaming.",
	},
	PRESET_STEAM_LINK_MULTITASK: {
		"label": "Steam Link Multitask",
		"detail": "Quest multitasking experiment with Steam Link streaming the simulator beside the controller app.",
		"mode": MODE_EXPERIMENTAL_STREAM,
		"stream_client": STREAM_CLIENT_STEAM_LINK,
		"run_label": "Steam Link multitask",
		"latency_budget_ms": 70,
		"operator_note": "Pin Steam Link beside the controller app and compare stick-to-screen latency against passthrough.",
	},
	PRESET_VIRTUAL_DESKTOP_MULTITASK: {
		"label": "Virtual Desktop Multitask",
		"detail": "Quest multitasking experiment with Virtual Desktop for pinned-window or alternate latency checks.",
		"mode": MODE_EXPERIMENTAL_STREAM,
		"stream_client": STREAM_CLIENT_VIRTUAL_DESKTOP,
		"run_label": "Virtual Desktop multitask",
		"latency_budget_ms": 80,
		"operator_note": "Use a pinned Virtual Desktop window to compare focus behavior and latency against Steam Link.",
	},
	PRESET_DESKTOP_BENCH: {
		"label": "Desktop Bench",
		"detail": "Desktop-only validation of mappings, outputs, and backend behavior without XR focus.",
		"mode": MODE_DESKTOP_BENCH,
		"stream_client": STREAM_CLIENT_NONE,
		"run_label": "Desktop bench",
		"latency_budget_ms": 0,
		"operator_note": "Use this mode for template debugging, backend validation, and regression checks without the headset.",
	},
}

var mode: String = _MODE_DEFAULT
var stream_client: String = _STREAM_CLIENT_DEFAULT
var preset_id: String = _PRESET_DEFAULT
var run_label: String = "Baseline passthrough"
var latency_budget_ms: int = 25
var observed_latency_ms: int = 0
var focus_loss_events: int = 0
var operator_note: String = ""
var manual_checks: Dictionary = {}


func _init() -> void:
	manual_checks = normalize_manual_checks_for_mode(mode)


func set_mode(next_mode: String) -> void:
	mode = normalize_mode(next_mode)
	if not supports_stream_client_selection():
		stream_client = STREAM_CLIENT_NONE
	manual_checks = normalize_manual_checks_for_mode(mode, manual_checks)


func set_stream_client(next_stream_client: String) -> void:
	stream_client = normalize_stream_client(next_stream_client)


func set_preset(next_preset_id: String) -> void:
	preset_id = normalize_preset(next_preset_id)


func apply_preset(next_preset_id: String) -> void:
	var entry := _preset_entry(next_preset_id)
	set_preset(next_preset_id)
	set_mode(str(entry.get("mode", _MODE_DEFAULT)))
	set_stream_client(str(entry.get("stream_client", _STREAM_CLIENT_DEFAULT)))
	run_label = str(entry.get("run_label", ""))
	latency_budget_ms = maxi(int(entry.get("latency_budget_ms", 0)), 0)
	observed_latency_ms = 0
	focus_loss_events = 0
	operator_note = str(entry.get("operator_note", ""))
	manual_checks = normalize_manual_checks_for_mode(mode)


func apply_session_details(
	next_run_label: String,
	next_latency_budget_ms: int,
	next_operator_note: String,
	next_observed_latency_ms: int = 0,
	next_focus_loss_events: int = 0
) -> void:
	run_label = next_run_label.strip_edges()
	latency_budget_ms = maxi(next_latency_budget_ms, 0)
	observed_latency_ms = maxi(next_observed_latency_ms, 0)
	focus_loss_events = maxi(next_focus_loss_events, 0)
	operator_note = next_operator_note.strip_edges()


func get_mode_label() -> String:
	return str(_mode_entry(mode).get("label", "Unknown"))


func get_stream_client_label() -> String:
	return str(_stream_client_entry(stream_client).get("label", "Choose Stream App"))


func get_preset_label() -> String:
	return str(_preset_entry(preset_id).get("label", "Custom Workflow"))


func is_experimental() -> bool:
	return bool(_mode_entry(mode).get("experimental", false))


func supports_stream_client_selection() -> bool:
	return mode == MODE_EXPERIMENTAL_STREAM


func set_manual_check(check_id: String, checked: bool) -> void:
	if not has_manual_check(check_id):
		return
	manual_checks[check_id] = checked


func has_manual_check(check_id: String) -> bool:
	return manual_checks.has(check_id)


func get_manual_check_progress() -> Dictionary:
	var total := manual_checks.size()
	var completed := 0
	for checked in manual_checks.values():
		if bool(checked):
			completed += 1
	return {
		"completed": completed,
		"total": total,
		"remaining": maxi(total - completed, 0),
	}


func get_manual_check_summary() -> String:
	var progress := get_manual_check_progress()
	var total := int(progress.get("total", 0))
	if total <= 0:
		return ""
	return "%d/%d workflow checks complete" % [
		int(progress.get("completed", 0)),
		total,
	]


func get_workflow_hint() -> String:
	var hint: String = str(_mode_entry(mode).get("workflow_hint", ""))
	if supports_stream_client_selection():
		var detail: String = str(_stream_client_entry(stream_client).get("detail", ""))
		if not detail.is_empty():
			hint = "%s %s" % [hint, detail]
	if latency_budget_ms > 0:
		hint = "%s Target latency: <= %d ms." % [hint, latency_budget_ms]
	if operator_note.is_empty():
		return hint
	return "%s Note: %s" % [hint, operator_note]


func build_diagnostics(runtime_status: Dictionary) -> Dictionary:
	var connected := bool(runtime_status.get("connected", false))
	var backend_available := bool(runtime_status.get("backend_available", false))
	var failsafe_active := bool(runtime_status.get("failsafe_active", false))
	var packets_received := int(runtime_status.get("packets_received", 0))
	var packets_dropped := int(runtime_status.get("packets_dropped", 0))
	var output_summary: Dictionary = runtime_status.get("output_summary", {})
	var output_activity := _max_output_activity(output_summary)
	var items: Array = []
	var manual_progress := get_manual_check_progress()

	match mode:
		MODE_EXPERIMENTAL_STREAM:
			if stream_client == STREAM_CLIENT_NONE:
				items.append(_diagnostic_item(
					"Pick Steam Link or Virtual Desktop before starting the multitasking experiment.",
					"attention"
				))
			else:
				var stream_label := "%s selected for the Quest multitasking experiment." % get_stream_client_label()
				if latency_budget_ms > 0:
					stream_label = "%s Target latency <= %d ms." % [stream_label, latency_budget_ms]
				items.append(_diagnostic_item(
					stream_label,
					"ready"
				))
		MODE_DESKTOP_BENCH:
			items.append(_diagnostic_item(
				"Desktop bench mode keeps the mapping and backend loop active without requiring XR focus.",
				"ready"
			))
		_:
			items.append(_diagnostic_item(
				"Passthrough standalone remains the lowest-latency baseline workflow.",
				"ready"
			))

	items.append(_diagnostic_item(
		"Control link %s." % ("connected" if connected else "disconnected"),
		"ready" if connected else "warning"
	))
	items.append(_diagnostic_item(
		"Backend %s." % ("ready for gamepad injection" if backend_available else "offline"),
		"ready" if backend_available else "warning"
	))
	items.append(_diagnostic_item(
		"Failsafe %s." % ("active; controller output is neutralized" if failsafe_active else "clear"),
		"warning" if failsafe_active else "ready"
	))

	if packets_received <= 0:
		items.append(_diagnostic_item(
			"Waiting for fresh telemetry from the Quest controller.",
			"attention" if connected else "warning"
		))
	elif packets_dropped > 0:
		items.append(_diagnostic_item(
			"Telemetry is flowing, but %d packets were dropped." % packets_dropped,
			"attention"
		))
	else:
		items.append(_diagnostic_item(
			"Telemetry is flowing without packet drops.",
			"ready"
		))

	items.append(_diagnostic_item(
		"Mapped outputs %s." % ("responding" if output_activity > 0.05 else "still neutral"),
		"ready" if output_activity > 0.05 else "attention"
	))
	if latency_budget_ms > 0:
		if observed_latency_ms <= 0:
			items.append(_diagnostic_item(
				"Observed latency has not been captured against the %d ms budget." % latency_budget_ms,
				"attention" if mode == MODE_EXPERIMENTAL_STREAM else "ready"
			))
		elif observed_latency_ms > latency_budget_ms:
			items.append(_diagnostic_item(
				"Observed latency %d ms exceeds the %d ms target." % [
					observed_latency_ms,
					latency_budget_ms,
				],
				"attention"
			))
		else:
			items.append(_diagnostic_item(
				"Observed latency %d ms is within the %d ms target." % [
					observed_latency_ms,
					latency_budget_ms,
				],
				"ready"
			))
	if focus_loss_events > 0:
		items.append(_diagnostic_item(
			"Input focus was lost %d time(s) during this pass." % focus_loss_events,
			"warning"
		))
	elif mode == MODE_EXPERIMENTAL_STREAM:
		items.append(_diagnostic_item(
			"No input-focus losses recorded for this pass.",
			"ready"
		))
	for check_info in manual_check_items():
		items.append(_diagnostic_item(
			str(check_info.get("label", "")),
			"ready" if bool(check_info.get("checked", false)) else "attention"
		))
	if int(manual_progress.get("total", 0)) > 0:
		items.append(_diagnostic_item(
			get_manual_check_summary(),
			"ready" if int(manual_progress.get("remaining", 0)) == 0 else "attention"
		))

	if not operator_note.is_empty():
		items.append(_diagnostic_item("Operator note: %s" % operator_note, "ready"))

	return {
		"summary": _build_summary(
			connected,
			backend_available,
			failsafe_active,
			packets_received,
			packets_dropped,
			output_activity,
			observed_latency_ms,
			focus_loss_events,
			int(manual_progress.get("remaining", 0)),
			int(manual_progress.get("total", 0))
		),
		"severity": _max_severity(items),
		"items": items,
	}


func build_operator_playbook(runtime_status: Dictionary) -> Dictionary:
	var diagnostics: Dictionary = runtime_status.get("session_diagnostics", {})
	if diagnostics.is_empty():
		diagnostics = build_diagnostics(runtime_status)
	var next_actions := _build_next_actions(runtime_status)
	var debug_actions := _build_debug_actions(runtime_status)
	var phase := _determine_playbook_phase(runtime_status, diagnostics, next_actions, debug_actions)
	return {
		"headline": _playbook_headline(),
		"phase": phase,
		"phase_label": _playbook_phase_label(phase),
		"summary": str(diagnostics.get("summary", "")),
		"steps": _build_playbook_steps(runtime_status),
		"next_actions": next_actions,
		"debug_actions": debug_actions,
	}


func to_dict() -> Dictionary:
	return {
		"preset_id": preset_id,
		"preset_label": get_preset_label(),
		"mode": mode,
		"mode_label": get_mode_label(),
		"experimental": is_experimental(),
		"stream_client": stream_client,
		"stream_client_label": get_stream_client_label(),
		"stream_client_enabled": supports_stream_client_selection(),
		"run_label": run_label,
		"latency_budget_ms": latency_budget_ms,
		"observed_latency_ms": observed_latency_ms,
		"focus_loss_events": focus_loss_events,
		"workflow_hint": get_workflow_hint(),
		"operator_note": operator_note,
		"manual_checks": manual_checks.duplicate(true),
		"manual_check_items": manual_check_items(),
		"manual_check_summary": get_manual_check_summary(),
		"presets": available_presets(),
		"stream_clients": available_stream_clients(),
		"available_modes": available_modes(),
	}


func from_dict(data: Dictionary) -> void:
	set_preset(str(data.get("preset_id", _PRESET_DEFAULT)))
	set_mode(str(data.get("mode", _MODE_DEFAULT)))
	set_stream_client(str(data.get("stream_client", _STREAM_CLIENT_DEFAULT)))
	run_label = str(data.get("run_label", _preset_entry(preset_id).get("run_label", "")))
	latency_budget_ms = maxi(int(data.get("latency_budget_ms", _preset_entry(preset_id).get("latency_budget_ms", 0))), 0)
	observed_latency_ms = maxi(int(data.get("observed_latency_ms", 0)), 0)
	focus_loss_events = maxi(int(data.get("focus_loss_events", 0)), 0)
	operator_note = str(data.get("operator_note", ""))
	manual_checks = normalize_manual_checks_for_mode(mode, data.get("manual_checks", {}))


func duplicate_profile() -> SessionProfile:
	var copy = get_script().new()
	copy.from_dict(to_dict())
	return copy


static func available_modes() -> Array:
	var items: Array = []
	for mode_name in [
		MODE_PASSTHROUGH_STANDALONE,
		MODE_EXPERIMENTAL_STREAM,
		MODE_DESKTOP_BENCH,
	]:
		var entry: Dictionary = _MODE_ENTRIES[mode_name]
		items.append({
			"value": mode_name,
			"label": entry["label"],
			"experimental": entry["experimental"],
		})
	return items


static func available_presets() -> Array:
	var items: Array = []
	for preset_name in [
		PRESET_PASSTHROUGH_BASELINE,
		PRESET_STEAM_LINK_MULTITASK,
		PRESET_VIRTUAL_DESKTOP_MULTITASK,
		PRESET_DESKTOP_BENCH,
		PRESET_CUSTOM,
	]:
		var entry: Dictionary = _PRESET_ENTRIES[preset_name]
		items.append({
			"value": preset_name,
			"label": entry["label"],
			"detail": entry["detail"],
		})
	return items


static func available_stream_clients() -> Array:
	var items: Array = []
	for stream_client_name in [
		STREAM_CLIENT_NONE,
		STREAM_CLIENT_STEAM_LINK,
		STREAM_CLIENT_VIRTUAL_DESKTOP,
	]:
		var entry: Dictionary = _STREAM_CLIENT_ENTRIES[stream_client_name]
		items.append({
			"value": stream_client_name,
			"label": entry["label"],
			"detail": entry["detail"],
		})
	return items


func manual_check_items() -> Array:
	var items: Array = []
	for check_info in available_manual_checks_for_mode(mode):
		var item: Dictionary = check_info.duplicate(true)
		var check_id := str(item.get("id", ""))
		item["checked"] = bool(manual_checks.get(check_id, false))
		items.append(item)
	return items


static func available_manual_checks_for_mode(mode_name: String) -> Array:
	var items: Array = []
	for check_info in _MANUAL_CHECK_ENTRIES.get(normalize_mode(mode_name), []):
		items.append(check_info.duplicate(true))
	return items


static func normalize_manual_checks_for_mode(mode_name: String, candidate_checks: Dictionary = {}) -> Dictionary:
	var normalized: Dictionary = {}
	for check_info in available_manual_checks_for_mode(mode_name):
		var check_id := str(check_info.get("id", ""))
		normalized[check_id] = bool(candidate_checks.get(check_id, false))
	return normalized


static func normalize_mode(candidate: String) -> String:
	if candidate in _MODE_ENTRIES:
		return candidate
	return _MODE_DEFAULT


static func normalize_stream_client(candidate: String) -> String:
	if candidate in _STREAM_CLIENT_ENTRIES:
		return candidate
	return _STREAM_CLIENT_DEFAULT


static func normalize_preset(candidate: String) -> String:
	if candidate in _PRESET_ENTRIES:
		return candidate
	return _PRESET_DEFAULT


static func _mode_entry(mode_name: String) -> Dictionary:
	return _MODE_ENTRIES.get(normalize_mode(mode_name), _MODE_ENTRIES[_MODE_DEFAULT])


static func _stream_client_entry(stream_client_name: String) -> Dictionary:
	return _STREAM_CLIENT_ENTRIES.get(
		normalize_stream_client(stream_client_name),
		_STREAM_CLIENT_ENTRIES[_STREAM_CLIENT_DEFAULT]
	)


static func _preset_entry(next_preset_id: String) -> Dictionary:
	return _PRESET_ENTRIES.get(normalize_preset(next_preset_id), _PRESET_ENTRIES[_PRESET_DEFAULT])


func _build_playbook_steps(runtime_status: Dictionary) -> Array:
	match mode:
		MODE_EXPERIMENTAL_STREAM:
			return _build_experimental_stream_steps(runtime_status)
		MODE_DESKTOP_BENCH:
			return _build_desktop_bench_steps(runtime_status)
		_:
			return _build_passthrough_steps(runtime_status)


func _build_passthrough_steps(runtime_status: Dictionary) -> Array:
	var connected := bool(runtime_status.get("connected", false))
	var backend_available := bool(runtime_status.get("backend_available", false))
	var output_activity := _max_output_activity(runtime_status.get("output_summary", {}))
	var packets_received := int(runtime_status.get("packets_received", 0))
	var failsafe_active := bool(runtime_status.get("failsafe_active", false))
	return [
		_playbook_step(
			"Stage passthrough + monitor view",
			"Quest",
			"Keep the simulator monitor visible through passthrough before comparing mappings.",
			"ready" if bool(manual_checks.get("passthrough_view_ready", false)) else "attention"
		),
		_playbook_step(
			"Calibrate and restore a live control path",
			"Quest",
			"Set flight origin, clear failsafe, and confirm telemetry reaches the desktop runtime.",
			_playbook_state(
				(connected and backend_available and packets_received > 0) and not failsafe_active and bool(manual_checks.get("controller_calibrated", false)),
				not connected or not backend_available or failsafe_active
			)
		),
		_playbook_step(
			"Verify mapped response",
			"Operator",
			"Move the controller and confirm the selected template responds with visible outputs.",
			_playbook_state(
				output_activity > 0.05 and bool(manual_checks.get("template_response_verified", false)),
				false
			)
		),
	]


func _build_experimental_stream_steps(runtime_status: Dictionary) -> Array:
	var connected := bool(runtime_status.get("connected", false))
	var backend_available := bool(runtime_status.get("backend_available", false))
	var packets_received := int(runtime_status.get("packets_received", 0))
	var packets_dropped := int(runtime_status.get("packets_dropped", 0))
	var output_activity := _max_output_activity(runtime_status.get("output_summary", {}))
	var latency_ok := latency_budget_ms <= 0 or (observed_latency_ms > 0 and observed_latency_ms <= latency_budget_ms)
	return [
		_playbook_step(
			"Stage the multitask layout",
			"Quest",
			"Pin %s beside the controller app and keep both panes visible while moving around the headset UI." % _streaming_target_label(),
			_playbook_state(
				stream_client != STREAM_CLIENT_NONE
				and bool(manual_checks.get("stream_window_visible", false))
				and bool(manual_checks.get("multitask_layout_stable", false)),
				false
			)
		),
		_playbook_step(
			"Keep the simulator control path alive",
			"Desktop",
			"After app switching, the simulator should still receive mapped outputs without packet loss or failsafe trips.",
			_playbook_state(
				connected
				and backend_available
				and packets_received > 0
				and packets_dropped <= 0
				and output_activity > 0.05
				and bool(manual_checks.get("input_focus_verified", false)),
				not connected or not backend_available or bool(runtime_status.get("failsafe_active", false))
			)
		),
		_playbook_step(
			"Validate latency and focus stability",
			"Operator",
			"Capture stick-to-screen latency, then repeat app switches until focus remains stable.",
			_playbook_state(
				latency_ok
				and observed_latency_ms > 0
				and focus_loss_events <= 0
				and bool(manual_checks.get("latency_checked", false)),
				focus_loss_events > 0 or (latency_budget_ms > 0 and observed_latency_ms > latency_budget_ms)
			)
		),
	]


func _build_desktop_bench_steps(runtime_status: Dictionary) -> Array:
	var backend_available := bool(runtime_status.get("backend_available", false))
	var output_activity := _max_output_activity(runtime_status.get("output_summary", {}))
	return [
		_playbook_step(
			"Verify backend injection",
			"Desktop",
			"Keep the backend ready so mapped outputs can be inspected without putting on the headset.",
			_playbook_state(
				backend_available and bool(manual_checks.get("backend_injection_verified", false)),
				not backend_available
			)
		),
		_playbook_step(
			"Exercise the active template",
			"Operator",
			"Move the controller or replay input until the template produces visible yaw, pitch, roll, or throttle changes.",
			_playbook_state(
				output_activity > 0.05 and bool(manual_checks.get("template_response_verified", false)),
				false
			)
		),
		_playbook_step(
			"Run failsafe recovery",
			"Operator",
			"Pause telemetry, confirm neutral outputs, then restore telemetry and recover control cleanly.",
			"ready" if bool(manual_checks.get("failsafe_recovery_tested", false)) else "attention"
		),
	]


func _build_next_actions(runtime_status: Dictionary) -> Array:
	var connected := bool(runtime_status.get("connected", false))
	var backend_available := bool(runtime_status.get("backend_available", false))
	var failsafe_active := bool(runtime_status.get("failsafe_active", false))
	var packets_received := int(runtime_status.get("packets_received", 0))
	var packets_dropped := int(runtime_status.get("packets_dropped", 0))
	var output_activity := _max_output_activity(runtime_status.get("output_summary", {}))
	var actions: Array = []
	match mode:
		MODE_EXPERIMENTAL_STREAM:
			if stream_client == STREAM_CLIENT_NONE:
				_append_unique(actions, "Select Steam Link or Virtual Desktop before starting the Quest multitasking pass.")
			elif not bool(manual_checks.get("stream_window_visible", false)):
				_append_unique(actions, "Open %s beside the controller app and confirm the stream window stays visible." % _streaming_target_label())
			if not bool(manual_checks.get("multitask_layout_stable", false)):
				_append_unique(actions, "Reposition the multitask layout until both the controller app and stream window remain visible.")
			if not bool(manual_checks.get("input_focus_verified", false)):
				_append_unique(actions, "Switch between apps and confirm the simulator still receives control input after refocusing.")
			if latency_budget_ms > 0 and (observed_latency_ms <= 0 or not bool(manual_checks.get("latency_checked", false))):
				_append_unique(actions, "Measure stick-to-screen latency and record the observed value for this pass.")
		MODE_DESKTOP_BENCH:
			if not bool(manual_checks.get("backend_injection_verified", false)):
				_append_unique(actions, "Confirm the backend or virtual gamepad sink is active before exercising templates.")
			if not bool(manual_checks.get("template_response_verified", false)):
				_append_unique(actions, "Move the controller and verify the active template responds on the desktop output preview.")
			if not bool(manual_checks.get("failsafe_recovery_tested", false)):
				_append_unique(actions, "Pause telemetry once to confirm failsafe recovery before continuing bench validation.")
		_:
			if not bool(manual_checks.get("passthrough_view_ready", false)):
				_append_unique(actions, "Stage the passthrough view so the simulator monitor is visible from the headset.")
			if not bool(manual_checks.get("controller_calibrated", false)):
				_append_unique(actions, "Set a fresh flight origin before judging the current passthrough mapping.")
			if not bool(manual_checks.get("template_response_verified", false)):
				_append_unique(actions, "Move the controller and confirm the active template responds as expected.")
	if not connected:
		_append_unique(actions, "Reconnect the Quest control channel before continuing this workflow.")
	if not backend_available:
		_append_unique(actions, "Bring the desktop backend online so the simulator receives mapped outputs.")
	if failsafe_active:
		_append_unique(actions, "Clear telemetry loss or tracking issues before judging this workflow.")
	if packets_received <= 0:
		_append_unique(actions, "Move the controller to confirm fresh telemetry reaches the desktop runtime.")
	if packets_dropped > 0:
		_append_unique(actions, "Reduce packet drops before capturing the next snapshot or report.")
	if output_activity <= 0.05:
		_append_unique(actions, "Inspect the active template or live tuning until mapped outputs stop staying neutral.")
	if latency_budget_ms > 0 and observed_latency_ms > latency_budget_ms:
		_append_unique(actions, "Reduce latency until the pass is back within the %d ms budget." % latency_budget_ms)
	if focus_loss_events > 0:
		_append_unique(actions, "Stabilize app switching or repin the stream window to eliminate focus losses.")
	if actions.is_empty():
		actions.append("Capture a ready snapshot and export the session report for this pass.")
	return actions.slice(0, 4)


func _build_debug_actions(runtime_status: Dictionary) -> Array:
	var actions: Array = []
	if not bool(runtime_status.get("connected", false)):
		_append_unique(actions, "Restart the Quest control client/server path if the TCP control channel will not reconnect.")
	if not bool(runtime_status.get("backend_available", false)):
		_append_unique(actions, "Check the desktop gamepad backend before validating any simulator behavior.")
	if bool(runtime_status.get("failsafe_active", false)):
		_append_unique(actions, "Inspect tracking validity, calibration, and telemetry freshness because failsafe is forcing neutral output.")
	if int(runtime_status.get("packets_dropped", 0)) > 0:
		_append_unique(actions, "Inspect Wi-Fi quality and local network load; dropped packets will mask multitask regressions.")
	if _max_output_activity(runtime_status.get("output_summary", {})) <= 0.05:
		_append_unique(actions, "Review template selection and live tuning because outputs are still neutral.")
	if latency_budget_ms > 0 and observed_latency_ms > latency_budget_ms:
		_append_unique(actions, "Lower stream quality, refresh rate, or scene load until latency returns under budget.")
	if focus_loss_events > 0:
		_append_unique(actions, "Repin the stream window and minimize app switching until focus losses stop.")
	return actions.slice(0, 3)


func _determine_playbook_phase(
	runtime_status: Dictionary,
	diagnostics: Dictionary,
	next_actions: Array,
	debug_actions: Array
) -> String:
	if str(diagnostics.get("severity", "ready")) == "warning" or not debug_actions.is_empty():
		return PLAYBOOK_PHASE_DEBUG
	if next_actions.size() == 1 and str(next_actions[0]) == "Capture a ready snapshot and export the session report for this pass.":
		return PLAYBOOK_PHASE_READY
	if not bool(runtime_status.get("connected", false)) or not bool(runtime_status.get("backend_available", false)):
		return PLAYBOOK_PHASE_SETUP
	if mode == MODE_EXPERIMENTAL_STREAM and stream_client == STREAM_CLIENT_NONE:
		return PLAYBOOK_PHASE_SETUP
	if int(get_manual_check_progress().get("remaining", 0)) > 0:
		return PLAYBOOK_PHASE_SETUP
	return PLAYBOOK_PHASE_VALIDATE


func _build_summary(
	connected: bool,
	backend_available: bool,
	failsafe_active: bool,
	packets_received: int,
	packets_dropped: int,
	output_activity: float,
	next_observed_latency_ms: int,
	next_focus_loss_events: int,
	manual_checks_remaining: int,
	manual_checks_total: int
) -> String:
	if not connected:
		return "Reconnect the Quest control channel before continuing this workflow."
	if not backend_available:
		return "The desktop backend is offline, so the simulator will not receive mapped inputs."
	if failsafe_active:
		return "Failsafe is active; clear telemetry loss before judging this workflow."
	if packets_received <= 0:
		return "Move the controller to confirm telemetry reaches the desktop runtime."
	if mode == MODE_EXPERIMENTAL_STREAM and stream_client == STREAM_CLIENT_NONE:
		return "Pick a Quest multitasking client before validating the experimental stream workflow."
	if packets_dropped > 0:
		return "Telemetry is flowing, but packet drops suggest the experiment needs stability work."
	if output_activity <= 0.05:
		return "Telemetry is healthy; move the controller to confirm mapped outputs respond."
	if next_focus_loss_events > 0:
		return "Input focus was lost %d time(s); stabilize app switching before continuing." % next_focus_loss_events
	if manual_checks_total > 0 and manual_checks_remaining > 0:
		return "Finish the remaining workflow checklist items (%d/%d) before the next pass." % [
			manual_checks_total - manual_checks_remaining,
			manual_checks_total,
		]
	if latency_budget_ms > 0 and next_observed_latency_ms <= 0 and mode == MODE_EXPERIMENTAL_STREAM:
		return "Measure observed latency against the session budget before concluding the multitasking pass."
	if latency_budget_ms > 0 and next_observed_latency_ms > latency_budget_ms:
		return "Observed latency %d ms exceeds the %d ms budget for this workflow." % [
			next_observed_latency_ms,
			latency_budget_ms,
		]
	match mode:
		MODE_EXPERIMENTAL_STREAM:
			if latency_budget_ms > 0 and next_observed_latency_ms > 0:
				return "%s experiment looks ready for another Quest multitasking pass. Observed %d ms vs target <= %d ms." % [
					get_stream_client_label(),
					next_observed_latency_ms,
					latency_budget_ms,
				]
			if latency_budget_ms > 0:
				return "%s experiment looks ready for another Quest multitasking pass. Target <= %d ms." % [
					get_stream_client_label(),
					latency_budget_ms,
				]
			return "%s experiment looks ready for another Quest multitasking pass." % get_stream_client_label()
		MODE_DESKTOP_BENCH:
			return "Desktop bench mode is ready for backend and mapping validation."
		_:
			return "Passthrough standalone looks ready for the current simulator session."


func _max_output_activity(output_summary: Dictionary) -> float:
	var maximum := 0.0
	for key in ["throttle", "yaw", "pitch", "roll"]:
		maximum = maxf(maximum, absf(float(output_summary.get(key, 0.0))))
	return maximum


func _playbook_step(label: String, role: String, detail: String, state: String) -> Dictionary:
	return {
		"label": label,
		"role": role,
		"detail": detail,
		"state": state,
	}


func _playbook_state(is_ready: bool, is_warning: bool) -> String:
	if is_warning:
		return "warning"
	if is_ready:
		return "ready"
	return "attention"


func _playbook_headline() -> String:
	match mode:
		MODE_EXPERIMENTAL_STREAM:
			return "%s multitask playbook" % _streaming_target_label()
		MODE_DESKTOP_BENCH:
			return "Desktop bench playbook"
		_:
			return "Passthrough baseline playbook"


func _playbook_phase_label(phase: String) -> String:
	match phase:
		PLAYBOOK_PHASE_SETUP:
			return "Setup"
		PLAYBOOK_PHASE_VALIDATE:
			return "Validate"
		PLAYBOOK_PHASE_DEBUG:
			return "Debug"
		_:
			return "Ready"


func _streaming_target_label() -> String:
	if stream_client == STREAM_CLIENT_NONE:
		return "the stream client"
	return get_stream_client_label()


func _append_unique(items: Array, value: String) -> void:
	if value.is_empty():
		return
	if not items.has(value):
		items.append(value)


func _diagnostic_item(label: String, state: String) -> Dictionary:
	return {
		"label": label,
		"state": state,
	}


func _max_severity(items: Array) -> String:
	var severity := "ready"
	for item in items:
		var item_state := str(item.get("state", "ready"))
		if _severity_rank(item_state) > _severity_rank(severity):
			severity = item_state
	return severity


func _severity_rank(level: String) -> int:
	match level:
		"warning":
			return 2
		"attention":
			return 1
		_:
			return 0
