class_name TemplateStructuredEditor
extends Control

const MappingTemplate = preload("res://scripts/mapping/mapping_template.gd")
const TemplateSummaryFormatter = preload("res://scripts/mapping/template_summary_formatter.gd")

const SOURCES := [
	"trigger",
	"grip",
	"thumbstick_x",
	"thumbstick_y",
	"swing_pitch_deg",
	"swing_yaw_deg",
	"twist_roll_deg",
	"pose_pitch_deg",
	"pose_yaw_deg",
	"pose_roll_deg",
	"pos_x_m",
	"pos_y_m",
	"pos_z_m",
	"angvel_x_rad_s",
	"angvel_y_rad_s",
	"angvel_z_rad_s",
	"linvel_x_m_s",
	"linvel_y_m_s",
	"linvel_z_m_s",
	"radius_xyz_m",
	"radius_xz_m",
	"button_south",
	"button_east",
	"button_west",
	"button_north",
	"button_thumbstick",
	"button_menu",
]

signal apply_requested(template)
signal save_requested(template)

var _template: MappingTemplate = MappingTemplate.new()
var _updating: bool = false
var _current_output_name: String = "throttle"
var _current_binding_index: int = -1

@onready var display_name_edit: LineEdit = $Margin/Scroll/VBox/MetaGrid/DisplayNameEdit
@onready var slug_edit: LineEdit = $Margin/Scroll/VBox/MetaGrid/SlugEdit
@onready var summary_edit: TextEdit = $Margin/Scroll/VBox/SummaryEdit
@onready var control_scheme_select: OptionButton = $Margin/Scroll/VBox/MetaGrid/ControlSchemeSelect
@onready var difficulty_select: OptionButton = $Margin/Scroll/VBox/MetaGrid/DifficultySelect
@onready var beta_recommended_edit: LineEdit = $Margin/Scroll/VBox/RecommendationsGrid/BetaRecommendedEdit
@onready var beta_acceptable_edit: LineEdit = $Margin/Scroll/VBox/RecommendationsGrid/BetaAcceptableEdit
@onready var beta_avoid_edit: LineEdit = $Margin/Scroll/VBox/RecommendationsGrid/BetaAvoidEdit
@onready var beta_notes_edit: TextEdit = $Margin/Scroll/VBox/BetaNotesEdit
@onready var liftoff_recommended_edit: LineEdit = $Margin/Scroll/VBox/RecommendationsGrid/LiftoffRecommendedEdit
@onready var liftoff_acceptable_edit: LineEdit = $Margin/Scroll/VBox/RecommendationsGrid/LiftoffAcceptableEdit
@onready var liftoff_avoid_edit: LineEdit = $Margin/Scroll/VBox/RecommendationsGrid/LiftoffAvoidEdit
@onready var liftoff_notes_edit: TextEdit = $Margin/Scroll/VBox/LiftoffNotesEdit
@onready var assists_recommended_edit: LineEdit = $Margin/Scroll/VBox/RecommendationsGrid/AssistsRecommendedEdit
@onready var assists_optional_edit: LineEdit = $Margin/Scroll/VBox/RecommendationsGrid/AssistsOptionalEdit
@onready var assists_avoid_edit: LineEdit = $Margin/Scroll/VBox/RecommendationsGrid/AssistsAvoidEdit
@onready var assists_notes_edit: TextEdit = $Margin/Scroll/VBox/AssistsNotesEdit
@onready var warnings_edit: TextEdit = $Margin/Scroll/VBox/WarningsEdit
@onready var usage_tips_edit: TextEdit = $Margin/Scroll/VBox/UsageTipsEdit
@onready var output_select: OptionButton = $Margin/Scroll/VBox/OutputToolbar/OutputSelect
@onready var add_binding_button: Button = $Margin/Scroll/VBox/OutputToolbar/AddBindingButton
@onready var remove_binding_button: Button = $Margin/Scroll/VBox/OutputToolbar/RemoveBindingButton
@onready var binding_list: ItemList = $Margin/Scroll/VBox/BindingList
@onready var source_select: OptionButton = $Margin/Scroll/VBox/BindingGrid/SourceSelect
@onready var mode_select: OptionButton = $Margin/Scroll/VBox/BindingGrid/ModeSelect
@onready var range_min_spin: SpinBox = $Margin/Scroll/VBox/BindingGrid/RangeMinSpin
@onready var range_max_spin: SpinBox = $Margin/Scroll/VBox/BindingGrid/RangeMaxSpin
@onready var weight_spin: SpinBox = $Margin/Scroll/VBox/BindingGrid/WeightSpin
@onready var invert_check: CheckBox = $Margin/Scroll/VBox/BindingGrid/InvertCheck
@onready var smoothing_spin: SpinBox = $Margin/Scroll/VBox/BindingGrid/SmoothingSpin
@onready var curve_select: OptionButton = $Margin/Scroll/VBox/BindingGrid/CurveSelect
@onready var deadzone_spin: SpinBox = $Margin/Scroll/VBox/OutputGrid/DeadzoneSpin
@onready var expo_spin: SpinBox = $Margin/Scroll/VBox/OutputGrid/ExpoSpin
@onready var sensitivity_spin: SpinBox = $Margin/Scroll/VBox/OutputGrid/SensitivitySpin
@onready var invert_output_check: CheckBox = $Margin/Scroll/VBox/OutputGrid/InvertOutputCheck
@onready var output_min_spin: SpinBox = $Margin/Scroll/VBox/OutputGrid/OutputMinSpin
@onready var output_max_spin: SpinBox = $Margin/Scroll/VBox/OutputGrid/OutputMaxSpin
@onready var apply_button: Button = $Margin/Scroll/VBox/ActionBar/ApplyButton
@onready var save_button: Button = $Margin/Scroll/VBox/ActionBar/SaveButton


func _ready() -> void:
	_load_selects()
	_connect_controls()
	set_template(_template)


func set_template(template: MappingTemplate) -> void:
	_template = template.duplicate_template()
	_updating = true
	display_name_edit.text = _template.display_name
	slug_edit.text = _template.slug
	summary_edit.text = _template.summary
	_select_metadata(control_scheme_select, _template.control_scheme)
	_select_metadata(difficulty_select, _template.difficulty)
	_set_recommendation_fields(_template.betaflight_recommendation, "beta")
	_set_recommendation_fields(_template.liftoff_recommendation, "liftoff")
	_set_assist_fields(_template.liftoff_assists)
	warnings_edit.text = "\n".join(_template.warnings)
	usage_tips_edit.text = "\n".join(_template.usage_tips)
	_current_output_name = MappingTemplate.OUTPUT_NAMES[0]
	output_select.select(0)
	_updating = false
	_refresh_output_fields()


func get_template() -> MappingTemplate:
	_commit_all_fields()
	return _template.duplicate_template()


func _load_selects() -> void:
	output_select.clear()
	for output_name in MappingTemplate.OUTPUT_NAMES:
		output_select.add_item(str(TemplateSummaryFormatter.OUTPUT_LABELS.get(output_name, output_name)))
		output_select.set_item_metadata(output_select.item_count - 1, output_name)
	control_scheme_select.clear()
	for item in MappingTemplate.control_scheme_options():
		control_scheme_select.add_item(str(TemplateSummaryFormatter.CONTROL_SCHEME_LABELS.get(item, item.capitalize())))
		control_scheme_select.set_item_metadata(control_scheme_select.item_count - 1, item)
	difficulty_select.clear()
	for item in MappingTemplate.difficulty_options():
		difficulty_select.add_item(str(TemplateSummaryFormatter.DIFFICULTY_LABELS.get(item, item.capitalize())))
		difficulty_select.set_item_metadata(difficulty_select.item_count - 1, item)
	source_select.clear()
	for item in SOURCES:
		source_select.add_item(str(TemplateSummaryFormatter.SOURCE_LABELS.get(item, item)))
		source_select.set_item_metadata(source_select.item_count - 1, item)
	mode_select.clear()
	for item in MappingTemplate.DEFAULT_MODES:
		mode_select.add_item(item.capitalize())
		mode_select.set_item_metadata(mode_select.item_count - 1, item)
	curve_select.clear()
	for item in MappingTemplate.DEFAULT_CURVES:
		curve_select.add_item(item.replace("_", " ").capitalize())
		curve_select.set_item_metadata(curve_select.item_count - 1, item)


func _connect_controls() -> void:
	output_select.item_selected.connect(_on_output_selected)
	add_binding_button.pressed.connect(_on_add_binding_pressed)
	remove_binding_button.pressed.connect(_on_remove_binding_pressed)
	binding_list.item_selected.connect(_on_binding_selected)
	apply_button.pressed.connect(func(): apply_requested.emit(get_template()))
	save_button.pressed.connect(func(): save_requested.emit(get_template()))
	for edit in [
		display_name_edit,
		slug_edit,
		beta_recommended_edit,
		beta_acceptable_edit,
		beta_avoid_edit,
		liftoff_recommended_edit,
		liftoff_acceptable_edit,
		liftoff_avoid_edit,
		assists_recommended_edit,
		assists_optional_edit,
		assists_avoid_edit,
	]:
		edit.text_changed.connect(_on_meta_changed)
	for edit in [summary_edit, beta_notes_edit, liftoff_notes_edit, assists_notes_edit, warnings_edit, usage_tips_edit]:
		edit.text_changed.connect(func(): _on_meta_changed(""))
	control_scheme_select.item_selected.connect(func(_idx: int): _on_meta_changed(""))
	difficulty_select.item_selected.connect(func(_idx: int): _on_meta_changed(""))
	for control in [range_min_spin, range_max_spin, weight_spin, smoothing_spin, deadzone_spin, expo_spin, sensitivity_spin, output_min_spin, output_max_spin]:
		control.value_changed.connect(_on_binding_or_output_changed)
	invert_check.toggled.connect(func(_pressed: bool): _on_binding_or_output_changed(0.0))
	invert_output_check.toggled.connect(func(_pressed: bool): _on_binding_or_output_changed(0.0))
	source_select.item_selected.connect(func(_idx: int): _on_binding_or_output_changed(0.0))
	mode_select.item_selected.connect(func(_idx: int): _on_binding_or_output_changed(0.0))
	curve_select.item_selected.connect(func(_idx: int): _on_binding_or_output_changed(0.0))


func _on_meta_changed(_value: Variant) -> void:
	if _updating:
		return
	_commit_meta_fields()


func _on_binding_or_output_changed(_value: Variant) -> void:
	if _updating:
		return
	_commit_output_fields()
	_commit_binding_fields()
	_refresh_binding_list()


func _on_output_selected(index: int) -> void:
	if _updating:
		return
	_commit_output_fields()
	_commit_binding_fields()
	_current_output_name = str(output_select.get_item_metadata(index))
	_refresh_output_fields()


func _on_add_binding_pressed() -> void:
	_template.outputs[_current_output_name]["bindings"].append(MappingTemplate.default_binding())
	_refresh_output_fields()
	binding_list.select(binding_list.item_count - 1)
	_on_binding_selected(binding_list.item_count - 1)


func _on_remove_binding_pressed() -> void:
	var bindings: Array = _template.outputs[_current_output_name]["bindings"]
	if _current_binding_index < 0 or _current_binding_index >= bindings.size():
		return
	bindings.remove_at(_current_binding_index)
	_current_binding_index = clampi(_current_binding_index - 1, -1, bindings.size() - 1)
	_refresh_output_fields()


func _on_binding_selected(index: int) -> void:
	_current_binding_index = index
	_refresh_binding_fields()


func _commit_all_fields() -> void:
	_commit_meta_fields()
	_commit_output_fields()
	_commit_binding_fields()


func _commit_meta_fields() -> void:
	_template.display_name = display_name_edit.text.strip_edges()
	_template.slug = slug_edit.text.strip_edges()
	_template.summary = summary_edit.text.strip_edges()
	_template.control_scheme = str(_selected_metadata(control_scheme_select, _template.control_scheme))
	_template.difficulty = str(_selected_metadata(difficulty_select, _template.difficulty))
	_template.betaflight_recommendation = _build_recommendation("beta")
	_template.liftoff_recommendation = _build_recommendation("liftoff")
	_template.liftoff_assists = {
		"recommended": _split_lines_or_csv(assists_recommended_edit.text),
		"optional": _split_lines_or_csv(assists_optional_edit.text),
		"avoid": _split_lines_or_csv(assists_avoid_edit.text),
		"notes": assists_notes_edit.text.strip_edges(),
	}
	_template.warnings = _split_multiline(warnings_edit.text)
	_template.usage_tips = _split_multiline(usage_tips_edit.text)


func _commit_output_fields() -> void:
	var output: Dictionary = _template.outputs[_current_output_name]
	output["deadzone"] = deadzone_spin.value
	output["expo"] = expo_spin.value
	output["sensitivity"] = sensitivity_spin.value
	output["invert_output"] = invert_output_check.button_pressed
	output["output_min"] = output_min_spin.value
	output["output_max"] = output_max_spin.value


func _commit_binding_fields() -> void:
	var bindings: Array = _template.outputs[_current_output_name]["bindings"]
	if _current_binding_index < 0 or _current_binding_index >= bindings.size():
		return
	var binding: Dictionary = bindings[_current_binding_index]
	binding["source"] = str(_selected_metadata(source_select, "trigger"))
	binding["mode"] = str(_selected_metadata(mode_select, "absolute"))
	binding["range_min"] = range_min_spin.value
	binding["range_max"] = range_max_spin.value
	binding["weight"] = weight_spin.value
	binding["invert"] = invert_check.button_pressed
	binding["smoothing"] = smoothing_spin.value
	binding["curve"] = str(_selected_metadata(curve_select, "linear"))


func _refresh_output_fields() -> void:
	_updating = true
	_refresh_binding_list()
	var output: Dictionary = _template.outputs[_current_output_name]
	deadzone_spin.value = float(output.get("deadzone", 0.0))
	expo_spin.value = float(output.get("expo", 0.0))
	sensitivity_spin.value = float(output.get("sensitivity", 1.0))
	invert_output_check.button_pressed = bool(output.get("invert_output", false))
	output_min_spin.value = float(output.get("output_min", -1.0))
	output_max_spin.value = float(output.get("output_max", 1.0))
	_updating = false
	_refresh_binding_fields()


func _refresh_binding_list() -> void:
	binding_list.clear()
	var bindings: Array = _template.outputs[_current_output_name]["bindings"]
	for binding in bindings:
		var source_id := str(binding.get("source", ""))
		var source_label := str(TemplateSummaryFormatter.SOURCE_LABELS.get(source_id, source_id))
		var mode_label := str(binding.get("mode", "")).capitalize()
		binding_list.add_item("%s [%s]" % [source_label, mode_label])
	remove_binding_button.disabled = bindings.is_empty()
	if bindings.is_empty():
		_current_binding_index = -1
	elif _current_binding_index < 0 or _current_binding_index >= bindings.size():
		_current_binding_index = 0
	if _current_binding_index >= 0 and _current_binding_index < binding_list.item_count:
		binding_list.select(_current_binding_index)


func _refresh_binding_fields() -> void:
	_updating = true
	var bindings: Array = _template.outputs[_current_output_name]["bindings"]
	var has_binding := _current_binding_index >= 0 and _current_binding_index < bindings.size()
	if not has_binding:
		source_select.disabled = true
		mode_select.disabled = true
		range_min_spin.editable = false
		range_max_spin.editable = false
		weight_spin.editable = false
		invert_check.disabled = true
		smoothing_spin.editable = false
		curve_select.disabled = true
		_updating = false
		return
	var binding: Dictionary = bindings[_current_binding_index]
	source_select.disabled = false
	mode_select.disabled = false
	range_min_spin.editable = true
	range_max_spin.editable = true
	weight_spin.editable = true
	invert_check.disabled = false
	smoothing_spin.editable = true
	curve_select.disabled = false
	_select_metadata(source_select, str(binding.get("source", "trigger")))
	_select_metadata(mode_select, str(binding.get("mode", "absolute")))
	range_min_spin.value = float(binding.get("range_min", -1.0))
	range_max_spin.value = float(binding.get("range_max", 1.0))
	weight_spin.value = float(binding.get("weight", 1.0))
	invert_check.button_pressed = bool(binding.get("invert", false))
	smoothing_spin.value = float(binding.get("smoothing", 0.0))
	_select_metadata(curve_select, str(binding.get("curve", "linear")))
	_updating = false


func _build_recommendation(prefix: String) -> Dictionary:
	if prefix == "beta":
		return {
			"recommended": _split_lines_or_csv(beta_recommended_edit.text),
			"acceptable": _split_lines_or_csv(beta_acceptable_edit.text),
			"avoid": _split_lines_or_csv(beta_avoid_edit.text),
			"notes": beta_notes_edit.text.strip_edges(),
		}
	return {
		"recommended": _split_lines_or_csv(liftoff_recommended_edit.text),
		"acceptable": _split_lines_or_csv(liftoff_acceptable_edit.text),
		"avoid": _split_lines_or_csv(liftoff_avoid_edit.text),
		"notes": liftoff_notes_edit.text.strip_edges(),
	}


func _set_recommendation_fields(recommendation: Dictionary, prefix: String) -> void:
	if prefix == "beta":
		beta_recommended_edit.text = ", ".join(recommendation.get("recommended", []))
		beta_acceptable_edit.text = ", ".join(recommendation.get("acceptable", []))
		beta_avoid_edit.text = ", ".join(recommendation.get("avoid", []))
		beta_notes_edit.text = str(recommendation.get("notes", ""))
		return
	liftoff_recommended_edit.text = ", ".join(recommendation.get("recommended", []))
	liftoff_acceptable_edit.text = ", ".join(recommendation.get("acceptable", []))
	liftoff_avoid_edit.text = ", ".join(recommendation.get("avoid", []))
	liftoff_notes_edit.text = str(recommendation.get("notes", ""))


func _set_assist_fields(assists: Dictionary) -> void:
	assists_recommended_edit.text = ", ".join(assists.get("recommended", []))
	assists_optional_edit.text = ", ".join(assists.get("optional", []))
	assists_avoid_edit.text = ", ".join(assists.get("avoid", []))
	assists_notes_edit.text = str(assists.get("notes", ""))


func _selected_metadata(select: OptionButton, fallback: String) -> Variant:
	if select.selected < 0 or select.selected >= select.item_count:
		return fallback
	return select.get_item_metadata(select.selected)


func _select_metadata(select: OptionButton, value: Variant) -> void:
	for index in range(select.item_count):
		if select.get_item_metadata(index) == value:
			select.select(index)
			return
	if select.item_count > 0:
		select.select(0)


func _split_multiline(text: String) -> Array:
	var items: Array = []
	for line in text.split("\n"):
		var trimmed := line.strip_edges()
		if not trimmed.is_empty():
			items.append(trimmed)
	return items


func _split_lines_or_csv(text: String) -> Array:
	var items: Array = []
	for part in text.replace("\n", ",").split(","):
		var trimmed := part.strip_edges()
		if not trimmed.is_empty():
			items.append(trimmed)
	return items
