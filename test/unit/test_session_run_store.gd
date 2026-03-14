extends "res://addons/gut/test.gd"

const SessionProfile = preload("res://scripts/workflow/session_profile.gd")
const SessionRunStore = preload("res://scripts/workflow/session_run_store.gd")

var _history_path: String = ""


func before_each() -> void:
	_history_path = "user://workflow/test_session_run_store_%d.json" % Time.get_ticks_usec()


func after_each() -> void:
	var absolute_path := ProjectSettings.globalize_path(_history_path)
	if FileAccess.file_exists(_history_path):
		DirAccess.remove_absolute(absolute_path)


func test_append_snapshot_persists_compact_run_history_entry() -> void:
	var store := SessionRunStore.new(_history_path)
	var profile := SessionProfile.new()
	profile.apply_preset(SessionProfile.PRESET_STEAM_LINK_MULTITASK)
	profile.observed_latency_ms = 68
	profile.focus_loss_events = 1
	for check_info in profile.manual_check_items():
		profile.set_manual_check(str(check_info.get("id", "")), true)

	var history := store.append_snapshot(profile, {
		"connected": true,
		"backend_available": true,
		"failsafe_active": false,
		"packets_received": 52,
		"packets_dropped": 1,
		"output_summary": {
			"throttle": 0.2,
			"yaw": 0.1,
			"pitch": 0.3,
			"roll": 0.0,
		},
	}, SessionRunStore.KIND_READY, SessionRunStore.ORIGIN_QUEST, "Pinned-window pass")

	assert_eq(history.size(), 1)
	assert_eq(history[0]["kind"], SessionRunStore.KIND_READY)
	assert_eq(history[0]["origin"], SessionRunStore.ORIGIN_QUEST)
	assert_eq(history[0]["preset_label"], "Steam Link Multitask")
	assert_eq(history[0]["diagnostics_severity"], "warning")
	assert_eq(history[0]["observed_latency_ms"], 68)
	assert_eq(history[0]["focus_loss_events"], 1)
	assert_eq(history[0]["note"], "Pinned-window pass")
	assert_eq(history[0]["packets_dropped"], 1)


func test_store_limits_history_to_most_recent_entries() -> void:
	var store := SessionRunStore.new(_history_path, 2)
	var profile := SessionProfile.new()
	profile.apply_preset(SessionProfile.PRESET_DESKTOP_BENCH)

	store.append_snapshot(profile, {"connected": true}, SessionRunStore.KIND_CHECKPOINT, SessionRunStore.ORIGIN_PC, "First")
	store.append_snapshot(profile, {"connected": true}, SessionRunStore.KIND_ISSUE, SessionRunStore.ORIGIN_PC, "Second")
	store.append_snapshot(profile, {"connected": true}, SessionRunStore.KIND_READY, SessionRunStore.ORIGIN_QUEST, "Third")
	var history := store.load_history()

	assert_eq(history.size(), 2)
	assert_eq(history[0]["note"], "Third")
	assert_eq(history[0]["kind"], SessionRunStore.KIND_READY)
	assert_eq(history[1]["note"], "Second")
	assert_eq(history[1]["kind"], SessionRunStore.KIND_ISSUE)
