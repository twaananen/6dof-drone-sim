class_name PcSessionWorkspace
extends Control

const SessionProfile = preload("res://scripts/workflow/session_profile.gd")

signal profile_applied(profile)
signal reload_requested()
signal snapshot_requested(kind, note)
signal export_requested(note)

@onready var phase_label: Label = $Margin/Scroll/VBox/HeroCard/HeroVBox/PhaseLabel
@onready var summary_label: Label = $Margin/Scroll/VBox/HeroCard/HeroVBox/SummaryLabel
@onready var next_actions_label: Label = $Margin/Scroll/VBox/Columns/RightColumn/PlaybookCard/PlaybookVBox/NextActionsLabel
@onready var debug_actions_label: Label = $Margin/Scroll/VBox/Columns/RightColumn/PlaybookCard/PlaybookVBox/DebugActionsLabel
@onready var workflow_editor: WorkflowEditorPanel = $Margin/Scroll/VBox/Columns/WorkflowEditorPanel
@onready var workflow_run_panel: WorkflowRunPanel = $Margin/Scroll/VBox/Columns/RightColumn/WorkflowRunPanel


func _ready() -> void:
	workflow_editor.profile_applied.connect(func(profile): profile_applied.emit(profile))
	workflow_editor.reload_requested.connect(func(): reload_requested.emit())
	workflow_run_panel.snapshot_requested.connect(func(kind, note): snapshot_requested.emit(kind, note))
	workflow_run_panel.export_requested.connect(func(note): export_requested.emit(note))


func set_data(session_data: Dictionary) -> void:
	var profile := session_data.get("profile") as SessionProfile
	if profile != null:
		workflow_editor.set_profile(profile)
		workflow_run_panel.set_profile(profile)
	var runtime_status: Dictionary = session_data.get("runtime_status", {})
	workflow_editor.set_runtime_status(runtime_status)
	workflow_run_panel.set_runtime_status(runtime_status)
	workflow_run_panel.set_history(session_data.get("history", []))
	workflow_run_panel.set_last_report_export(session_data.get("last_report_export", {}))

	var playbook: Dictionary = runtime_status.get("session_playbook", {})
	phase_label.text = "Phase: %s" % str(playbook.get("phase_label", "Setup"))
	summary_label.text = str(runtime_status.get("workflow_hint", runtime_status.get("session_diagnostics", {}).get("summary", "Waiting for session details.")))
	next_actions_label.text = _join_list(playbook.get("next_actions", []), "No next actions yet.")
	debug_actions_label.text = _join_list(playbook.get("debug_actions", []), "No debug actions right now.")


func _join_list(items: Array, empty_text: String) -> String:
	if items.is_empty():
		return empty_text
	var lines := PackedStringArray()
	for item in items:
		lines.append("• %s" % str(item))
	return "\n".join(lines)
