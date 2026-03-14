extends "res://addons/gut/test.gd"

const SessionProfile = preload("res://scripts/workflow/session_profile.gd")


func test_unknown_mode_falls_back_to_passthrough() -> void:
	var profile := SessionProfile.new()
	profile.set_mode("unknown_mode")

	assert_eq(profile.mode, SessionProfile.MODE_PASSTHROUGH_STANDALONE)
	assert_false(profile.is_experimental())
	assert_eq(profile.preset_id, SessionProfile.PRESET_PASSTHROUGH_BASELINE)


func test_workflow_hint_includes_operator_note() -> void:
	var profile := SessionProfile.new()
	profile.set_mode(SessionProfile.MODE_EXPERIMENTAL_STREAM)
	profile.set_stream_client(SessionProfile.STREAM_CLIENT_STEAM_LINK)
	profile.latency_budget_ms = 72
	profile.operator_note = "Measure Quest multitask latency after Steam Link starts."

	var payload := profile.to_dict()

	assert_eq(payload["mode_label"], "Experimental Stream")
	assert_true(payload["experimental"])
	assert_string_contains(payload["workflow_hint"], "Steam Link")
	assert_string_contains(payload["workflow_hint"], "72")
	assert_true(payload["stream_client_enabled"])


func test_apply_session_details_trims_text_and_clamps_latency() -> void:
	var profile := SessionProfile.new()
	profile.apply_preset(SessionProfile.PRESET_STEAM_LINK_MULTITASK)

	profile.apply_session_details(
		"  Quest multitask pass  ",
		-4,
		"  Capture focus loss after app switch.  ",
		91,
		-3
	)

	assert_eq(profile.run_label, "Quest multitask pass")
	assert_eq(profile.latency_budget_ms, 0)
	assert_eq(profile.observed_latency_ms, 91)
	assert_eq(profile.focus_loss_events, 0)
	assert_eq(profile.operator_note, "Capture focus loss after app switch.")


func test_unknown_stream_client_falls_back_to_choose_stream_app() -> void:
	var profile := SessionProfile.new()
	profile.set_mode(SessionProfile.MODE_EXPERIMENTAL_STREAM)
	profile.set_stream_client("moonlight")

	var payload := profile.to_dict()

	assert_eq(profile.stream_client, SessionProfile.STREAM_CLIENT_NONE)
	assert_eq(payload["stream_client_label"], "Choose Stream App")


func test_switching_away_from_stream_mode_clears_stream_client() -> void:
	var profile := SessionProfile.new()
	profile.apply_preset(SessionProfile.PRESET_STEAM_LINK_MULTITASK)

	profile.set_mode(SessionProfile.MODE_DESKTOP_BENCH)

	assert_eq(profile.stream_client, SessionProfile.STREAM_CLIENT_NONE)


func test_mode_switch_rebuilds_manual_checks_for_new_workflow() -> void:
	var profile := SessionProfile.new()

	profile.set_manual_check("passthrough_view_ready", true)
	profile.set_mode(SessionProfile.MODE_EXPERIMENTAL_STREAM)

	assert_false(profile.has_manual_check("passthrough_view_ready"))
	assert_true(profile.has_manual_check("stream_window_visible"))
	assert_eq(profile.get_manual_check_summary(), "0/4 workflow checks complete")


func test_experimental_stream_diagnostics_call_out_missing_stream_app() -> void:
	var profile := SessionProfile.new()
	profile.set_mode(SessionProfile.MODE_EXPERIMENTAL_STREAM)

	var diagnostics := profile.build_diagnostics({
		"connected": true,
		"backend_available": true,
		"packets_received": 24,
		"packets_dropped": 0,
		"output_summary": {
			"throttle": 0.2,
			"yaw": 0.1,
			"pitch": 0.0,
			"roll": 0.0,
		},
	})

	assert_eq(diagnostics["severity"], "attention")
	assert_string_contains(diagnostics["summary"], "Pick a Quest multitasking client")


func test_experimental_stream_requires_manual_checklist_before_ready() -> void:
	var profile := SessionProfile.new()
	profile.apply_preset(SessionProfile.PRESET_STEAM_LINK_MULTITASK)

	var runtime_status := {
		"connected": true,
		"backend_available": true,
		"packets_received": 48,
		"packets_dropped": 0,
		"output_summary": {
			"throttle": 0.2,
			"yaw": 0.1,
			"pitch": 0.3,
			"roll": 0.0,
		},
	}
	var blocked := profile.build_diagnostics(runtime_status)
	for check_info in profile.manual_check_items():
		profile.set_manual_check(str(check_info.get("id", "")), true)
	profile.observed_latency_ms = 58
	var ready := profile.build_diagnostics(runtime_status)

	assert_eq(blocked["severity"], "attention")
	assert_string_contains(blocked["summary"], "workflow checklist items")
	assert_eq(ready["severity"], "ready")
	assert_string_contains(ready["summary"], "Steam Link experiment looks ready")
	assert_string_contains(ready["summary"], "58")


func test_experimental_stream_diagnostics_become_ready_when_session_is_healthy() -> void:
	var profile := SessionProfile.new()
	profile.apply_preset(SessionProfile.PRESET_VIRTUAL_DESKTOP_MULTITASK)
	profile.observed_latency_ms = 62
	for check_info in profile.manual_check_items():
		profile.set_manual_check(str(check_info.get("id", "")), true)

	var diagnostics := profile.build_diagnostics({
		"connected": true,
		"backend_available": true,
		"packets_received": 48,
		"packets_dropped": 0,
		"output_summary": {
			"throttle": 0.2,
			"yaw": 0.1,
			"pitch": 0.3,
			"roll": 0.0,
		},
	})

	assert_eq(diagnostics["severity"], "ready")
	assert_string_contains(diagnostics["summary"], "Virtual Desktop experiment looks ready")
	assert_string_contains(diagnostics["summary"], "62")


func test_experimental_stream_diagnostics_require_observed_latency_measurement() -> void:
	var profile := SessionProfile.new()
	profile.apply_preset(SessionProfile.PRESET_STEAM_LINK_MULTITASK)
	for check_info in profile.manual_check_items():
		profile.set_manual_check(str(check_info.get("id", "")), true)

	var diagnostics := profile.build_diagnostics({
		"connected": true,
		"backend_available": true,
		"packets_received": 48,
		"packets_dropped": 0,
		"output_summary": {
			"throttle": 0.2,
			"yaw": 0.1,
			"pitch": 0.3,
			"roll": 0.0,
		},
	})

	assert_eq(diagnostics["severity"], "attention")
	assert_string_contains(diagnostics["summary"], "Measure observed latency")


func test_experimental_stream_playbook_prioritizes_multitask_setup_actions() -> void:
	var profile := SessionProfile.new()
	profile.apply_preset(SessionProfile.PRESET_STEAM_LINK_MULTITASK)

	var playbook := profile.build_operator_playbook({
		"connected": true,
		"backend_available": true,
		"packets_received": 48,
		"packets_dropped": 0,
		"output_summary": {
			"throttle": 0.2,
			"yaw": 0.1,
			"pitch": 0.3,
			"roll": 0.0,
		},
	})

	assert_eq(playbook["phase"], SessionProfile.PLAYBOOK_PHASE_SETUP)
	assert_string_contains(playbook["headline"], "Steam Link")
	assert_string_contains(str(playbook["next_actions"][0]), "Open Steam Link")
	assert_string_contains(str(playbook["next_actions"][1]), "Reposition the multitask layout")


func test_experimental_stream_playbook_switches_to_debug_for_latency_and_focus_regressions() -> void:
	var profile := SessionProfile.new()
	profile.apply_preset(SessionProfile.PRESET_STEAM_LINK_MULTITASK)
	profile.observed_latency_ms = 96
	profile.focus_loss_events = 2
	for check_info in profile.manual_check_items():
		profile.set_manual_check(str(check_info.get("id", "")), true)

	var playbook := profile.build_operator_playbook({
		"connected": true,
		"backend_available": true,
		"packets_received": 48,
		"packets_dropped": 0,
		"output_summary": {
			"throttle": 0.2,
			"yaw": 0.1,
			"pitch": 0.3,
			"roll": 0.0,
		},
	})

	assert_eq(playbook["phase"], SessionProfile.PLAYBOOK_PHASE_DEBUG)
	assert_string_contains(str(playbook["next_actions"][0]), "Reduce latency")
	assert_string_contains(str(playbook["debug_actions"][0]), "Lower stream quality")
	assert_string_contains(str(playbook["debug_actions"][1]), "Repin the stream window")


func test_latency_budget_and_focus_loss_are_called_out_in_diagnostics() -> void:
	var profile := SessionProfile.new()
	profile.apply_preset(SessionProfile.PRESET_STEAM_LINK_MULTITASK)
	profile.observed_latency_ms = 95
	profile.focus_loss_events = 2
	for check_info in profile.manual_check_items():
		profile.set_manual_check(str(check_info.get("id", "")), true)

	var diagnostics := profile.build_diagnostics({
		"connected": true,
		"backend_available": true,
		"packets_received": 48,
		"packets_dropped": 0,
		"output_summary": {
			"throttle": 0.2,
			"yaw": 0.1,
			"pitch": 0.3,
			"roll": 0.0,
		},
	})

	assert_eq(diagnostics["severity"], "warning")
	assert_string_contains(diagnostics["summary"], "Input focus was lost 2 time(s)")
	var found_latency_item := false
	for item in diagnostics.get("items", []):
		if str(item.get("label", "")).contains("95 ms exceeds the 70 ms target"):
			found_latency_item = true
			break
	assert_true(found_latency_item)


func test_failsafe_forces_warning_summary() -> void:
	var profile := SessionProfile.new()
	profile.apply_preset(SessionProfile.PRESET_STEAM_LINK_MULTITASK)

	var diagnostics := profile.build_diagnostics({
		"connected": true,
		"backend_available": true,
		"failsafe_active": true,
		"packets_received": 48,
		"packets_dropped": 0,
		"output_summary": {
			"throttle": 0.2,
			"yaw": 0.1,
			"pitch": 0.3,
			"roll": 0.0,
		},
	})

	assert_eq(diagnostics["severity"], "warning")
	assert_string_contains(diagnostics["summary"], "Failsafe is active")


func test_available_modes_marks_stream_mode_experimental() -> void:
	var modes := SessionProfile.available_modes()
	var experimental_entry := {}
	for mode_info in modes:
		if mode_info.get("value", "") == SessionProfile.MODE_EXPERIMENTAL_STREAM:
			experimental_entry = mode_info
			break

	assert_false(experimental_entry.is_empty())
	assert_eq(experimental_entry["label"], "Experimental Stream")
	assert_true(experimental_entry["experimental"])


func test_available_stream_clients_include_steam_link_and_virtual_desktop() -> void:
	var stream_clients := SessionProfile.available_stream_clients()
	var labels := PackedStringArray()
	for stream_client in stream_clients:
		labels.append(str(stream_client.get("label", "")))

	assert_true(labels.has("Steam Link"))
	assert_true(labels.has("Virtual Desktop"))


func test_available_presets_include_stream_workflows() -> void:
	var presets := SessionProfile.available_presets()
	var labels := PackedStringArray()
	for preset in presets:
		labels.append(str(preset.get("label", "")))

	assert_true(labels.has("Passthrough Baseline"))
	assert_true(labels.has("Steam Link Multitask"))
	assert_true(labels.has("Virtual Desktop Multitask"))


func test_to_dict_includes_manual_check_items() -> void:
	var profile := SessionProfile.new()
	profile.apply_preset(SessionProfile.PRESET_DESKTOP_BENCH)
	profile.set_manual_check("backend_injection_verified", true)

	var payload := profile.to_dict()
	var items: Array = payload["manual_check_items"]

	assert_eq(payload["manual_check_summary"], "1/3 workflow checks complete")
	assert_eq(items.size(), 3)
	assert_true(bool(items[0].has("checked")))
