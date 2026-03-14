extends "res://addons/gut/test.gd"

const SessionProfile = preload("res://scripts/workflow/session_profile.gd")
const SessionReportExporter = preload("res://scripts/workflow/session_report_exporter.gd")
const SessionRunStore = preload("res://scripts/workflow/session_run_store.gd")

var _report_dir: String = ""
var _created_paths: Array = []


func before_each() -> void:
	_report_dir = "user://workflow/test_reports_%d" % Time.get_ticks_usec()
	_created_paths.clear()


func after_each() -> void:
	for path in _created_paths:
		var absolute_path := ProjectSettings.globalize_path(str(path))
		if FileAccess.file_exists(str(path)):
			DirAccess.remove_absolute(absolute_path)
	var absolute_report_dir := ProjectSettings.globalize_path(_report_dir)
	if DirAccess.dir_exists_absolute(absolute_report_dir):
		DirAccess.remove_absolute(absolute_report_dir)


func test_export_report_writes_markdown_and_json_files() -> void:
	var exporter := SessionReportExporter.new(_report_dir)
	var profile := SessionProfile.new()
	profile.apply_preset(SessionProfile.PRESET_STEAM_LINK_MULTITASK)
	profile.run_label = "Quest Stream Pass"
	profile.operator_note = "Capture latency and focus behavior after switching apps."
	profile.observed_latency_ms = 64
	profile.focus_loss_events = 1
	profile.set_manual_check("stream_window_visible", true)
	profile.set_manual_check("input_focus_verified", true)
	var runtime_status := {
		"connected": true,
		"backend_available": true,
		"backend_name": "linux_gamepad",
		"template_name": "rate_direct",
		"failsafe_active": false,
		"packets_received": 96,
		"packets_dropped": 2,
		"output_summary": {
			"throttle": 0.22,
			"yaw": 0.14,
			"pitch": 0.31,
			"roll": -0.08,
		},
	}
	runtime_status["session_diagnostics"] = profile.build_diagnostics(runtime_status)
	var history := [
		SessionRunStore.build_snapshot(
			profile,
			runtime_status,
			SessionRunStore.KIND_READY,
			SessionRunStore.ORIGIN_QUEST,
			"Pinned window stayed visible."
		),
	]

	var export_info := exporter.export_report(profile, runtime_status, history, "Export after Quest multitask pass.")
	_created_paths.append(export_info.get("markdown_user_path", ""))
	_created_paths.append(export_info.get("json_user_path", ""))

	assert_true(bool(export_info.get("ok", false)))
	assert_eq(export_info["severity"], "warning")
	assert_true(FileAccess.file_exists(export_info["markdown_path"]))
	assert_true(FileAccess.file_exists(export_info["json_path"]))

	var markdown_file := FileAccess.open(export_info["markdown_path"], FileAccess.READ)
	assert_not_null(markdown_file)
	var markdown_text := markdown_file.get_as_text()
	markdown_file.close()

	assert_string_contains(markdown_text, "# Session Report")
	assert_string_contains(markdown_text, "Steam Link Multitask")
	assert_string_contains(markdown_text, "Quest Stream Pass")
	assert_string_contains(markdown_text, "Observed Latency: 64 ms")
	assert_string_contains(markdown_text, "Focus Loss Events: 1")
	assert_string_contains(markdown_text, "## Workflow Playbook")
	assert_string_contains(markdown_text, "## Baseline Comparison")
	assert_string_contains(markdown_text, "### Next Actions")
	assert_string_contains(markdown_text, "Steam Link multitask playbook")
	assert_string_contains(markdown_text, "Pinned window stayed visible.")
	assert_string_contains(markdown_text, "Export after Quest multitask pass.")


func test_build_export_payload_limits_focus_items_to_attention_and_warning() -> void:
	var exporter := SessionReportExporter.new(_report_dir)
	var profile := SessionProfile.new()
	profile.apply_preset(SessionProfile.PRESET_DESKTOP_BENCH)
	var runtime_status := {
		"connected": false,
		"backend_available": false,
		"backend_name": "linux_gamepad",
		"template_name": "",
		"failsafe_active": true,
		"packets_received": 0,
		"packets_dropped": 0,
		"output_summary": {},
	}

	var payload := exporter.build_export_payload(profile, runtime_status, [], "")
	var recommended_focus: Array = payload.get("recommended_focus", [])

	assert_true(recommended_focus.size() > 0)
	assert_true(recommended_focus.size() <= 4)
	assert_eq(payload["snapshot_count"], 0)
	assert_eq(payload["severity"], "warning")


func test_build_report_name_adds_unique_suffix_to_avoid_overwrites() -> void:
	var exporter := SessionReportExporter.new(_report_dir)
	var profile := SessionProfile.new()
	profile.run_label = "Quest Stream Pass"

	var first_name := exporter._build_report_name(profile, 1234567890, 1001)
	var second_name := exporter._build_report_name(profile, 1234567890, 1002)

	assert_ne(first_name, second_name)
	assert_string_contains(first_name, "quest_stream_pass")
	assert_string_contains(second_name, "quest_stream_pass")
