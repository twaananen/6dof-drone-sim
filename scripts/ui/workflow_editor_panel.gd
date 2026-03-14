class_name WorkflowEditorPanel
extends PanelContainer

const SessionProfile = preload("res://scripts/workflow/session_profile.gd")

signal profile_applied(profile)
signal reload_requested()

@onready var preset_select: OptionButton = $VBox/Toolbar/PresetSelect
@onready var apply_preset_button: Button = $VBox/Toolbar/ApplyPresetButton
@onready var reload_button: Button = $VBox/Toolbar/ReloadButton
@onready var mode_select: OptionButton = $VBox/Form/ModeSelect
@onready var stream_client_label: Label = $VBox/Form/StreamClientLabel
@onready var stream_client_select: OptionButton = $VBox/Form/StreamClientSelect
@onready var run_label_edit: LineEdit = $VBox/Form/RunLabelEdit
@onready var latency_budget_spin: SpinBox = $VBox/Form/LatencyBudgetSpin
@onready var observed_latency_spin: SpinBox = $VBox/Form/ObservedLatencySpin
@onready var focus_loss_spin: SpinBox = $VBox/Form/FocusLossSpin
@onready var note_edit: TextEdit = $VBox/NoteEdit
@onready var checklist_box: VBoxContainer = $VBox/ChecklistBox
@onready var apply_button: Button = $VBox/Buttons/ApplyButton
@onready var summary_label: Label = $VBox/SummaryLabel

var _profile: SessionProfile = SessionProfile.new()
var _runtime_status: Dictionary = {}
var _updating_controls: bool = false
var _manual_checks_state: Dictionary = {}


func _ready() -> void:
	_load_presets()
	_load_modes()
	_load_stream_clients()
	apply_preset_button.pressed.connect(_on_apply_preset_pressed)
	reload_button.pressed.connect(func(): reload_requested.emit())
	apply_button.pressed.connect(_on_apply_pressed)
	mode_select.item_selected.connect(_on_mode_selected)
	stream_client_select.item_selected.connect(_on_stream_client_selected)
	run_label_edit.text_changed.connect(func(_text: String): _mark_custom_profile())
	latency_budget_spin.value_changed.connect(func(_value: float): _mark_custom_profile())
	observed_latency_spin.value_changed.connect(func(_value: float): _mark_custom_profile())
	focus_loss_spin.value_changed.connect(func(_value: float): _mark_custom_profile())
	note_edit.text_changed.connect(_mark_custom_profile)
	set_profile(_profile)


func set_profile(profile: SessionProfile) -> void:
	_profile = profile.duplicate_profile()
	_manual_checks_state = _profile.manual_checks.duplicate(true)
	_updating_controls = true
	_select_option_by_metadata(preset_select, _profile.preset_id)
	_select_option_by_metadata(mode_select, _profile.mode)
	_select_option_by_metadata(stream_client_select, _profile.stream_client)
	run_label_edit.text = _profile.run_label
	latency_budget_spin.value = _profile.latency_budget_ms
	observed_latency_spin.value = _profile.observed_latency_ms
	focus_loss_spin.value = _profile.focus_loss_events
	note_edit.text = _profile.operator_note
	_updating_controls = false
	_rebuild_manual_check_controls()
	_update_stream_client_controls()
	_refresh_summary()


func set_runtime_status(runtime_status: Dictionary) -> void:
	_runtime_status = runtime_status.duplicate(true)
	_refresh_summary()


func _on_apply_preset_pressed() -> void:
	var preset_id: String = str(_selected_metadata(preset_select, SessionProfile.PRESET_PASSTHROUGH_BASELINE))
	var profile := SessionProfile.new()
	profile.apply_preset(preset_id)
	set_profile(profile)


func _on_apply_pressed() -> void:
	var profile := _profile_from_controls()
	_profile = profile.duplicate_profile()
	profile_applied.emit(profile)
	_refresh_summary()


func _on_mode_selected(_index: int) -> void:
	if _updating_controls:
		return
	var selected_mode := str(_selected_metadata(mode_select, SessionProfile.MODE_PASSTHROUGH_STANDALONE))
	_manual_checks_state = SessionProfile.normalize_manual_checks_for_mode(selected_mode, _manual_checks_state)
	_rebuild_manual_check_controls()
	_mark_custom_profile()
	_update_stream_client_controls()


func _on_stream_client_selected(_index: int) -> void:
	if _updating_controls:
		return
	_mark_custom_profile()


func _mark_custom_profile() -> void:
	if _updating_controls:
		return
	_select_option_by_metadata(preset_select, SessionProfile.PRESET_CUSTOM)
	_update_stream_client_controls()
	_refresh_summary()


func _load_presets() -> void:
	preset_select.clear()
	for preset_info in SessionProfile.available_presets():
		preset_select.add_item(str(preset_info.get("label", "")))
		preset_select.set_item_metadata(preset_select.item_count - 1, preset_info.get("value", ""))


func _load_modes() -> void:
	mode_select.clear()
	for mode_info in SessionProfile.available_modes():
		var label := str(mode_info.get("label", ""))
		if mode_info.get("experimental", false):
			label += " [exp]"
		mode_select.add_item(label)
		mode_select.set_item_metadata(mode_select.item_count - 1, mode_info.get("value", ""))


func _load_stream_clients() -> void:
	stream_client_select.clear()
	for stream_client_info in SessionProfile.available_stream_clients():
		stream_client_select.add_item(str(stream_client_info.get("label", "")))
		stream_client_select.set_item_metadata(
			stream_client_select.item_count - 1,
			stream_client_info.get("value", "")
		)


func _profile_from_controls() -> SessionProfile:
	var profile := SessionProfile.new()
	profile.set_preset(str(_selected_metadata(preset_select, SessionProfile.PRESET_CUSTOM)))
	profile.set_mode(str(_selected_metadata(mode_select, SessionProfile.MODE_PASSTHROUGH_STANDALONE)))
	if profile.supports_stream_client_selection():
		profile.set_stream_client(str(_selected_metadata(stream_client_select, SessionProfile.STREAM_CLIENT_NONE)))
	else:
		profile.set_stream_client(SessionProfile.STREAM_CLIENT_NONE)
	profile.run_label = run_label_edit.text.strip_edges()
	profile.latency_budget_ms = maxi(int(round(latency_budget_spin.value)), 0)
	profile.observed_latency_ms = maxi(int(round(observed_latency_spin.value)), 0)
	profile.focus_loss_events = maxi(int(round(focus_loss_spin.value)), 0)
	profile.operator_note = note_edit.text.strip_edges()
	profile.manual_checks = SessionProfile.normalize_manual_checks_for_mode(profile.mode, _manual_checks_state)
	return profile


func _update_stream_client_controls() -> void:
	var selected_mode := str(_selected_metadata(mode_select, SessionProfile.MODE_PASSTHROUGH_STANDALONE))
	var stream_enabled := selected_mode == SessionProfile.MODE_EXPERIMENTAL_STREAM
	stream_client_label.visible = stream_enabled
	stream_client_select.visible = stream_enabled
	stream_client_select.disabled = not stream_enabled


func _refresh_summary() -> void:
	var preview_profile := _profile_from_controls() if is_node_ready() else _profile
	var diagnostics := preview_profile.build_diagnostics(_runtime_status)
	var playbook := preview_profile.build_operator_playbook(_runtime_status)
	var lines := PackedStringArray()
	lines.append("Preset: %s" % preview_profile.get_preset_label())
	if not preview_profile.run_label.is_empty():
		lines.append("Run: %s" % preview_profile.run_label)
	lines.append("Checklist: %s" % str(diagnostics.get("summary", "")))
	lines.append("Phase: %s" % str(playbook.get("phase_label", "Setup")))
	if preview_profile.latency_budget_ms > 0:
		lines.append("Latency Budget: <= %d ms" % preview_profile.latency_budget_ms)
	if preview_profile.observed_latency_ms > 0:
		lines.append("Observed Latency: %d ms" % preview_profile.observed_latency_ms)
	if preview_profile.focus_loss_events > 0 or preview_profile.mode == SessionProfile.MODE_EXPERIMENTAL_STREAM:
		lines.append("Focus Loss Events: %d" % preview_profile.focus_loss_events)
	var manual_check_summary := preview_profile.get_manual_check_summary()
	if not manual_check_summary.is_empty():
		lines.append("Manual Checks: %s" % manual_check_summary)
	var workflow_hint := preview_profile.get_workflow_hint()
	if not workflow_hint.is_empty():
		lines.append("Hint: %s" % workflow_hint)
	var next_actions: Array = playbook.get("next_actions", [])
	for index in range(mini(next_actions.size(), 2)):
		lines.append("Next: %s" % str(next_actions[index]))
	var debug_actions: Array = playbook.get("debug_actions", [])
	if not debug_actions.is_empty():
		lines.append("Debug: %s" % str(debug_actions[0]))
	summary_label.text = "\n".join(lines)


func _rebuild_manual_check_controls() -> void:
	for child in checklist_box.get_children():
		child.queue_free()
	var selected_mode := str(_selected_metadata(mode_select, _profile.mode))
	for check_info in SessionProfile.available_manual_checks_for_mode(selected_mode):
		var check_id := str(check_info.get("id", ""))
		var checkbox := CheckBox.new()
		checkbox.text = str(check_info.get("label", ""))
		checkbox.tooltip_text = str(check_info.get("detail", ""))
		checkbox.button_pressed = bool(_manual_checks_state.get(check_id, false))
		checkbox.toggled.connect(_on_manual_check_toggled.bind(check_id))
		checklist_box.add_child(checkbox)


func _on_manual_check_toggled(pressed: bool, check_id: String) -> void:
	_manual_checks_state[check_id] = pressed
	_mark_custom_profile()


func _selected_metadata(select: OptionButton, fallback: String) -> Variant:
	if select.selected < 0 or select.selected >= select.item_count:
		return fallback
	return select.get_item_metadata(select.selected)


func _select_option_by_metadata(select: OptionButton, value: Variant) -> void:
	for index in range(select.item_count):
		if select.get_item_metadata(index) == value:
			select.select(index)
			return
	if select.item_count > 0:
		select.select(0)
