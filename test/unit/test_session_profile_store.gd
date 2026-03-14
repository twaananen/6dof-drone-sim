extends "res://addons/gut/test.gd"

const SessionProfile = preload("res://scripts/workflow/session_profile.gd")
const SessionProfileStore = preload("res://scripts/workflow/session_profile_store.gd")

var _profile_path: String = ""


func before_each() -> void:
	_profile_path = "user://workflow/test_session_profile_store_%d.json" % Time.get_ticks_usec()


func after_each() -> void:
	var absolute_path := ProjectSettings.globalize_path(_profile_path)
	if FileAccess.file_exists(_profile_path):
		DirAccess.remove_absolute(absolute_path)


func test_store_round_trips_profile_fields() -> void:
	var store := SessionProfileStore.new(_profile_path)
	var profile := SessionProfile.new()
	profile.apply_preset(SessionProfile.PRESET_VIRTUAL_DESKTOP_MULTITASK)
	profile.run_label = "Quest pinned-window latency pass"
	profile.latency_budget_ms = 88
	profile.observed_latency_ms = 73
	profile.focus_loss_events = 1
	profile.operator_note = "Validate focus behavior before comparing against Steam Link."
	profile.set_manual_check("stream_window_visible", true)
	profile.set_manual_check("latency_checked", true)

	var save_result := store.save_profile(profile)
	var loaded := store.load_profile()

	assert_eq(save_result, OK)
	assert_eq(loaded.preset_id, SessionProfile.PRESET_VIRTUAL_DESKTOP_MULTITASK)
	assert_eq(loaded.mode, SessionProfile.MODE_EXPERIMENTAL_STREAM)
	assert_eq(loaded.stream_client, SessionProfile.STREAM_CLIENT_VIRTUAL_DESKTOP)
	assert_eq(loaded.run_label, "Quest pinned-window latency pass")
	assert_eq(loaded.latency_budget_ms, 88)
	assert_eq(loaded.observed_latency_ms, 73)
	assert_eq(loaded.focus_loss_events, 1)
	assert_eq(loaded.operator_note, "Validate focus behavior before comparing against Steam Link.")
	assert_true(bool(loaded.manual_checks.get("stream_window_visible", false)))
	assert_true(bool(loaded.manual_checks.get("latency_checked", false)))


func test_store_returns_default_profile_when_file_is_missing() -> void:
	var store := SessionProfileStore.new(_profile_path)
	var loaded := store.load_profile()

	assert_eq(loaded.preset_id, SessionProfile.PRESET_PASSTHROUGH_BASELINE)
	assert_eq(loaded.mode, SessionProfile.MODE_PASSTHROUGH_STANDALONE)
