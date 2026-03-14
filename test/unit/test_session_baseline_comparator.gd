extends "res://addons/gut/test.gd"

const SessionBaselineComparator = preload("res://scripts/workflow/session_baseline_comparator.gd")
const SessionProfile = preload("res://scripts/workflow/session_profile.gd")
const SessionRunStore = preload("res://scripts/workflow/session_run_store.gd")


func test_experimental_stream_compares_against_ready_passthrough_baseline() -> void:
	var comparator := SessionBaselineComparator.new()
	var baseline_profile := SessionProfile.new()
	baseline_profile.apply_preset(SessionProfile.PRESET_PASSTHROUGH_BASELINE)
	baseline_profile.observed_latency_ms = 24
	for check_info in baseline_profile.manual_check_items():
		baseline_profile.set_manual_check(str(check_info.get("id", "")), true)
	var baseline_status := {
		"connected": true,
		"backend_available": true,
		"failsafe_active": false,
		"packets_received": 80,
		"packets_dropped": 0,
		"output_summary": {
			"throttle": 0.2,
			"yaw": 0.1,
			"pitch": 0.3,
			"roll": 0.0,
		},
	}
	var history := [
		SessionRunStore.build_snapshot(
			baseline_profile,
			baseline_status,
			SessionRunStore.KIND_READY,
			SessionRunStore.ORIGIN_QUEST,
			"Baseline pass"
		),
	]

	var stream_profile := SessionProfile.new()
	stream_profile.apply_preset(SessionProfile.PRESET_STEAM_LINK_MULTITASK)
	stream_profile.observed_latency_ms = 72
	stream_profile.focus_loss_events = 1
	var comparison := comparator.build_comparison(stream_profile, {
		"packets_dropped": 3,
		"session_observed_latency_ms": 72,
		"session_focus_loss_events": 1,
	}, history)

	assert_true(bool(comparison.get("available", false)))
	assert_eq(comparison["severity"], "warning")
	assert_eq(comparison["latency_delta_ms"], 48)
	assert_eq(comparison["focus_loss_delta"], 1)
	assert_eq(comparison["packet_drop_delta"], 3)
	assert_string_contains(str(comparison["summary"]), "Passthrough Baseline")
	assert_string_contains(str(comparison["summary"]), "latency +48 ms")
	assert_string_contains(str(comparison["recommendations"][0]), "reduce stream quality")


func test_missing_baseline_requests_ready_reference_snapshot() -> void:
	var comparator := SessionBaselineComparator.new()
	var stream_profile := SessionProfile.new()
	stream_profile.apply_preset(SessionProfile.PRESET_VIRTUAL_DESKTOP_MULTITASK)

	var comparison := comparator.build_comparison(stream_profile, {}, [])

	assert_false(bool(comparison.get("available", true)))
	assert_eq(comparison["severity"], "attention")
	assert_string_contains(str(comparison["summary"]), "passthrough baseline snapshot")
