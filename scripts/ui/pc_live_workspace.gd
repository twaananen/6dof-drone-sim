class_name PcLiveWorkspace
extends Control

const SessionRunStore = preload("res://scripts/workflow/session_run_store.gd")

signal snapshot_requested(kind, note)
signal export_requested(note)

@onready var template_name_label: Label = $Margin/Scroll/VBox/HeroCard/HeroVBox/TemplateNameLabel
@onready var template_meta_label: Label = $Margin/Scroll/VBox/HeroCard/HeroVBox/TemplateMetaLabel
@onready var template_summary_label: Label = $Margin/Scroll/VBox/HeroCard/HeroVBox/TemplateSummaryLabel
@onready var input_status_label: Label = $Margin/Scroll/VBox/TopRow/InputsCard/InputsVBox/InputStatusLabel
@onready var analog_label: Label = $Margin/Scroll/VBox/TopRow/InputsCard/InputsVBox/AnalogLabel
@onready var buttons_label: Label = $Margin/Scroll/VBox/TopRow/InputsCard/InputsVBox/ButtonsLabel
@onready var output_summary_label: Label = $Margin/Scroll/VBox/TopRow/OutputsCard/OutputsVBox/OutputSummaryLabel
@onready var throttle_bar: ProgressBar = $Margin/Scroll/VBox/TopRow/OutputsCard/OutputsVBox/ThrottleAxis/ThrottleBar
@onready var yaw_bar: ProgressBar = $Margin/Scroll/VBox/TopRow/OutputsCard/OutputsVBox/YawAxis/YawBar
@onready var pitch_bar: ProgressBar = $Margin/Scroll/VBox/TopRow/OutputsCard/OutputsVBox/PitchAxis/PitchBar
@onready var roll_bar: ProgressBar = $Margin/Scroll/VBox/TopRow/OutputsCard/OutputsVBox/RollAxis/RollBar
@onready var workflow_phase_label: Label = $Margin/Scroll/VBox/BottomRow/WorkflowCard/WorkflowVBox/WorkflowPhaseLabel
@onready var workflow_summary_label: Label = $Margin/Scroll/VBox/BottomRow/WorkflowCard/WorkflowVBox/WorkflowSummaryLabel
@onready var next_actions_label: Label = $Margin/Scroll/VBox/BottomRow/WorkflowCard/WorkflowVBox/NextActionsLabel
@onready var checklist_label: Label = $Margin/Scroll/VBox/BottomRow/WorkflowCard/WorkflowVBox/ChecklistLabel
@onready var note_edit: LineEdit = $Margin/Scroll/VBox/ActionsCard/ActionsVBox/NoteEdit
@onready var snapshot_button: Button = $Margin/Scroll/VBox/ActionsCard/ActionsVBox/Buttons/SnapshotButton
@onready var issue_button: Button = $Margin/Scroll/VBox/ActionsCard/ActionsVBox/Buttons/IssueButton
@onready var export_button: Button = $Margin/Scroll/VBox/ActionsCard/ActionsVBox/Buttons/ExportButton
@onready var last_snapshot_label: Label = $Margin/Scroll/VBox/BottomRow/RecentCard/RecentVBox/LastSnapshotLabel
@onready var export_summary_label: Label = $Margin/Scroll/VBox/BottomRow/RecentCard/RecentVBox/ExportSummaryLabel


func _ready() -> void:
	snapshot_button.pressed.connect(func(): _emit_snapshot(SessionRunStore.KIND_CHECKPOINT))
	issue_button.pressed.connect(func(): _emit_snapshot(SessionRunStore.KIND_ISSUE))
	export_button.pressed.connect(_on_export_pressed)


func set_data(live_data: Dictionary) -> void:
	var template_summary: Dictionary = live_data.get("template_summary", {})
	template_name_label.text = str(live_data.get("template_name", "No template"))
	template_meta_label.text = "%s  |  %s" % [
		str(template_summary.get("control_scheme_label", "Control Scheme")),
		str(template_summary.get("difficulty_label", "Difficulty")),
	]
	template_summary_label.text = str(template_summary.get("summary", "Choose a template to start evaluating mapped outputs."))

	var input_summary: Dictionary = live_data.get("input_summary", {})
	input_status_label.text = "Tracking %s | Control %s | Origin %s" % [
		"OK" if bool(input_summary.get("tracking_valid", false)) else "Lost",
		"Active" if bool(input_summary.get("control_active", false)) else "Paused",
		str(input_summary.get("origin_event", "none")),
	]
	analog_label.text = "Trigger %.2f | Grip %.2f | Stick %.2f, %.2f" % [
		float(input_summary.get("trigger", 0.0)),
		float(input_summary.get("grip", 0.0)),
		float(input_summary.get("thumbstick_x", 0.0)),
		float(input_summary.get("thumbstick_y", 0.0)),
	]
	buttons_label.text = "Buttons: %s" % str(input_summary.get("buttons_summary", "No buttons pressed"))

	var outputs: Dictionary = live_data.get("output_summary", {})
	output_summary_label.text = "Aux 1: %.0f | Failsafe %s" % [
		float(outputs.get("aux_button_1", 0.0)),
		"Active" if bool(live_data.get("failsafe_active", false)) else "Clear",
	]
	_set_axis_bar(throttle_bar, "Throttle", float(outputs.get("throttle", 0.0)))
	_set_axis_bar(yaw_bar, "Yaw", float(outputs.get("yaw", 0.0)))
	_set_axis_bar(pitch_bar, "Pitch", float(outputs.get("pitch", 0.0)))
	_set_axis_bar(roll_bar, "Roll", float(outputs.get("roll", 0.0)))

	workflow_phase_label.text = "Phase: %s" % str(live_data.get("phase_label", "Setup"))
	workflow_summary_label.text = str(live_data.get("workflow_summary", "Waiting for runtime status."))
	checklist_label.text = "Checklist: %s" % str(live_data.get("manual_check_summary", "No manual checks yet."))

	var next_actions: Array = live_data.get("next_actions", [])
	if next_actions.is_empty():
		next_actions_label.text = "Next: Capture a ready snapshot when the pass looks clean."
	else:
		var lines := PackedStringArray()
		for action in next_actions:
			lines.append("• %s" % str(action))
		next_actions_label.text = "\n".join(lines)

	var latest_snapshot: Dictionary = live_data.get("latest_snapshot", {})
	if latest_snapshot.is_empty():
		last_snapshot_label.text = "No snapshot captured yet."
	else:
		last_snapshot_label.text = "%s\n%s" % [
			str(latest_snapshot.get("captured_at_text", "")),
			str(latest_snapshot.get("diagnostics_summary", "")),
		]

	var export_info: Dictionary = live_data.get("last_report_export", {})
	if export_info.is_empty():
		export_summary_label.text = "No report exported yet."
	else:
		export_summary_label.text = "%s\n%s" % [
			str(export_info.get("exported_at_text", "")),
			str(export_info.get("summary", "")),
		]


func _set_axis_bar(bar: ProgressBar, label: String, value: float) -> void:
	bar.min_value = 0.0
	bar.max_value = 100.0
	bar.value = clampf((value + 1.0) * 50.0, 0.0, 100.0)
	bar.show_percentage = false
	bar.tooltip_text = "%s %.2f" % [label, value]
	var title := bar.get_parent().get_node("Header/%sValue" % label) as Label
	title.text = "%.2f" % value


func _emit_snapshot(kind: String) -> void:
	snapshot_requested.emit(kind, note_edit.text.strip_edges())
	note_edit.clear()


func _on_export_pressed() -> void:
	export_requested.emit(note_edit.text.strip_edges())
	note_edit.clear()
