extends Node

const MappingTemplate = preload("res://scripts/mapping/mapping_template.gd")

signal control_message_requested(message)

var template_select: OptionButton
var template_summary_label: Label
var template_modes_label: Label
var sensitivity_slider: HSlider
var deadzone_slider: HSlider
var expo_slider: HSlider
var integrator_slider: HSlider

var template_library_panel: TemplateLibraryPanel
var template_guide_panel: TemplateGuidePanel
var template_editor_panel: TemplateStructuredEditor

var _active_template_id: String = ""
var _active_template_summary: Dictionary = {}
var _active_template_payload: Dictionary = {}
var _template_catalog: Array = []
var _template_editor_loaded_id: String = ""


func configure(
	flight_panel_root: Control,
	template_library_root: Control,
	template_guide_root: Control,
	template_editor_root: Control
) -> bool:
	if flight_panel_root == null:
		return false
	var base_path := "Panel/Margin/Scroll/VBox/"
	template_select = _require_panel_node(flight_panel_root, base_path + "TemplateSelect") as OptionButton
	template_summary_label = _require_panel_node(flight_panel_root, base_path + "TemplateSummaryLabel") as Label
	template_modes_label = _require_panel_node(flight_panel_root, base_path + "TemplateModesLabel") as Label
	sensitivity_slider = _require_panel_node(flight_panel_root, base_path + "Tuning/SensitivitySlider") as HSlider
	deadzone_slider = _require_panel_node(flight_panel_root, base_path + "Tuning/DeadzoneSlider") as HSlider
	expo_slider = _require_panel_node(flight_panel_root, base_path + "Tuning/ExpoSlider") as HSlider
	integrator_slider = _require_panel_node(flight_panel_root, base_path + "Tuning/IntegratorSlider") as HSlider
	template_library_panel = template_library_root as TemplateLibraryPanel
	template_guide_panel = template_guide_root as TemplateGuidePanel
	template_editor_panel = template_editor_root as TemplateStructuredEditor
	if not _has_bound_controls():
		return false
	_connect_controls()
	return true


func apply_template_catalog(templates: Array) -> void:
	_template_catalog.clear()
	for item in templates:
		if typeof(item) == TYPE_DICTIONARY:
			_template_catalog.append(item.duplicate(true))
	if template_select == null:
		return
	var previous := _active_template_id
	template_select.clear()
	for item in _template_catalog:
		var summary: Dictionary = item
		template_select.add_item(str(summary.get("display_name", "")))
		template_select.set_item_metadata(template_select.item_count - 1, str(summary.get("template_id", "")))
	if previous.is_empty() and template_select.item_count > 0:
		template_select.select(0)
	else:
		for index in range(template_select.item_count):
			if str(template_select.get_item_metadata(index)) == previous:
				template_select.select(index)
				break
	sync_template_surfaces(true)


func apply_active_template(template_id: String, summary: Dictionary, payload: Dictionary) -> void:
	_active_template_id = template_id
	_active_template_summary = summary.duplicate(true)
	_active_template_payload = payload.duplicate(true)
	sync_template_surfaces(true)


func apply_status_template_fallback(status: Dictionary) -> void:
	var changed := false
	if _active_template_id.is_empty():
		_active_template_id = str(status.get("template_id", ""))
		changed = true
	if _active_template_summary.is_empty():
		_active_template_summary = status.get("template_summary", {}).duplicate(true)
		changed = true
	if _active_template_payload.is_empty():
		_active_template_payload = status.get("template", {}).duplicate(true)
		changed = true
	if changed:
		sync_template_surfaces(false)


func handle_control_disconnected() -> void:
	_template_editor_loaded_id = ""


func override_local_state(
	template_catalog: Array,
	active_template_id: String,
	active_template_summary: Dictionary,
	active_template_payload: Dictionary
) -> void:
	_template_catalog = template_catalog.duplicate(true)
	_active_template_id = active_template_id
	_active_template_summary = active_template_summary.duplicate(true)
	_active_template_payload = active_template_payload.duplicate(true)


func get_active_template_summary() -> Dictionary:
	return _active_template_summary.duplicate(true)


func get_active_template_id() -> String:
	return _active_template_id


func get_active_template_payload() -> Dictionary:
	return _active_template_payload.duplicate(true)


func get_template_catalog() -> Array:
	return _template_catalog.duplicate(true)


func sync_template_surfaces(reset_library_selection: bool = true) -> void:
	if template_library_panel != null:
		template_library_panel.set_catalog(_template_catalog)
		if reset_library_selection or str(template_library_panel._selected_template_id).is_empty():
			template_library_panel.set_selected_template_id(_active_template_id)
	if template_guide_panel != null:
		var selected_id := _active_template_id
		if template_library_panel != null and not str(template_library_panel._selected_template_id).is_empty():
			selected_id = str(template_library_panel._selected_template_id)
		template_guide_panel.set_summary(_catalog_summary(selected_id))
	if template_editor_panel != null and not _active_template_payload.is_empty() and _template_editor_loaded_id != _active_template_id:
		var template := MappingTemplate.new()
		template.from_dict(_active_template_payload)
		template_editor_panel.set_template(template)
		_template_editor_loaded_id = _active_template_id
	if template_summary_label != null:
		template_summary_label.text = str(
			_active_template_summary.get("summary", "Waiting for active template details.")
		)
	if template_modes_label != null:
		var mode_lines: Array = _active_template_summary.get("mode_lines", [])
		template_modes_label.text = "\n".join(mode_lines) if not mode_lines.is_empty() else "Modes: waiting for recommendations"


func _connect_controls() -> void:
	template_select.item_selected.connect(_on_template_selected)
	sensitivity_slider.value_changed.connect(_on_tuning_changed)
	deadzone_slider.value_changed.connect(_on_tuning_changed)
	expo_slider.value_changed.connect(_on_tuning_changed)
	integrator_slider.value_changed.connect(_on_tuning_changed)
	if template_library_panel != null:
		template_library_panel.selection_changed.connect(_on_template_library_selection_changed)
		template_library_panel.apply_requested.connect(_on_template_library_apply_requested)
		template_library_panel.copy_requested.connect(_on_template_library_copy_requested)
		template_library_panel.new_requested.connect(_on_template_library_new_requested)
		template_library_panel.delete_requested.connect(_on_template_library_delete_requested)
	if template_editor_panel != null:
		template_editor_panel.apply_requested.connect(_on_template_editor_apply_requested)
		template_editor_panel.save_requested.connect(_on_template_editor_save_requested)


func _catalog_summary(template_id: String) -> Dictionary:
	for item in _template_catalog:
		if str(item.get("template_id", "")) == template_id:
			return item
	return _active_template_summary.duplicate(true)


func _on_template_selected(index: int) -> void:
	control_message_requested.emit({
		"type": "select_template",
		"template_id": str(template_select.get_item_metadata(index)),
	})


func _on_template_library_selection_changed(template_id: String) -> void:
	if template_guide_panel != null:
		template_guide_panel.set_summary(_catalog_summary(template_id))


func _on_template_library_apply_requested(template_id: String) -> void:
	control_message_requested.emit({
		"type": "select_template",
		"template_id": template_id,
	})


func _on_template_library_copy_requested(template_id: String) -> void:
	control_message_requested.emit({
		"type": "duplicate_template",
		"template_id": template_id,
	})


func _on_template_library_new_requested() -> void:
	control_message_requested.emit({
		"type": "create_blank_template",
		"display_name": "New Template",
	})


func _on_template_library_delete_requested(template_id: String) -> void:
	control_message_requested.emit({
		"type": "delete_template",
		"template_id": template_id,
	})


func _on_template_editor_apply_requested(template: MappingTemplate) -> void:
	control_message_requested.emit({
		"type": "apply_template",
		"template": template.to_dict(),
	})


func _on_template_editor_save_requested(template: MappingTemplate) -> void:
	control_message_requested.emit({
		"type": "save_template",
		"template": template.to_dict(),
	})


func _on_tuning_changed(_value: float) -> void:
	control_message_requested.emit({
		"type": "apply_tuning",
		"settings": {
			"sensitivity": sensitivity_slider.value,
			"deadzone": deadzone_slider.value,
			"expo": expo_slider.value,
			"integrator_gain": integrator_slider.value,
		},
	})


func _require_panel_node(quest_panel: Control, node_path: String) -> Node:
	var node := quest_panel.get_node_or_null(node_path)
	if node == null:
		QuestRuntimeLog.error("UI_BIND_MISSING_NODE", {
			"path": node_path,
			"error": "Quest panel missing node: %s" % node_path,
		})
	return node


func _has_bound_controls() -> bool:
	return template_select != null \
		and template_summary_label != null \
		and template_modes_label != null \
		and sensitivity_slider != null \
		and deadzone_slider != null \
		and expo_slider != null \
		and integrator_slider != null
