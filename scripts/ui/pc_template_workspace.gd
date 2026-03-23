class_name PcTemplateWorkspace
extends Control

const MappingTemplate = preload("res://scripts/mapping/mapping_template.gd")
const TemplateManager = preload("res://scripts/ui/template_manager.gd")
const TemplateSummaryFormatter = preload("res://scripts/mapping/template_summary_formatter.gd")

signal template_applied(template)
signal template_saved(template)
signal template_deleted(template_id)

var _manager: TemplateManager = TemplateManager.new()
var _summary_formatter := TemplateSummaryFormatter.new()
var _current_template: MappingTemplate
var _selected_template_id: String = ""
var _runtime_template_id: String = ""
var _dirty: bool = false

@onready var state_label: Label = $Margin/VBox/HeaderCard/HeaderVBox/StateLabel
@onready var identity_label: Label = $Margin/VBox/HeaderCard/HeaderVBox/IdentityLabel
@onready var summary_label: Label = $Margin/VBox/HeaderCard/HeaderVBox/SummaryLabel
@onready var tabs: TabContainer = $Margin/VBox/BodySplit/RightColumn/Tabs
@onready var library_panel: TemplateLibraryPanel = $Margin/VBox/BodySplit/LibraryPanel
@onready var guide_panel: TemplateGuidePanel = $Margin/VBox/BodySplit/RightColumn/Tabs/GuidePanel
@onready var structured_editor: TemplateStructuredEditor = $Margin/VBox/BodySplit/RightColumn/Tabs/StructuredEditor
@onready var json_editor: TextEdit = $Margin/VBox/BodySplit/RightColumn/Tabs/AdvancedJson/JsonVBox/JsonEditor
@onready var json_apply_button: Button = $Margin/VBox/BodySplit/RightColumn/Tabs/AdvancedJson/JsonVBox/JsonButtons/JsonApplyButton
@onready var json_save_button: Button = $Margin/VBox/BodySplit/RightColumn/Tabs/AdvancedJson/JsonVBox/JsonButtons/JsonSaveButton


func _ready() -> void:
	_apply_desktop_theme(library_panel)
	_apply_desktop_theme(guide_panel)
	_apply_desktop_theme(structured_editor)
	library_panel.selection_changed.connect(_on_library_selection_changed)
	library_panel.apply_requested.connect(_on_library_apply_requested)
	library_panel.copy_requested.connect(_on_library_copy_requested)
	library_panel.new_requested.connect(_on_library_new_requested)
	library_panel.delete_requested.connect(_on_library_delete_requested)
	structured_editor.template_changed.connect(_on_template_changed)
	structured_editor.apply_requested.connect(_on_structured_apply_requested)
	structured_editor.save_requested.connect(_on_structured_save_requested)
	json_editor.text_changed.connect(func(): _set_dirty(true))
	json_apply_button.pressed.connect(_on_json_apply_pressed)
	json_save_button.pressed.connect(_on_json_save_pressed)
	tabs.set_tab_title(tabs.get_tab_idx_from_control(guide_panel), "Overview")
	tabs.set_tab_title(tabs.get_tab_idx_from_control(structured_editor), "Bindings")
	tabs.set_tab_title(tabs.get_tab_idx_from_control(json_editor.get_parent().get_parent()), "Advanced JSON")
	refresh_catalog()


func set_data(template_data: Dictionary) -> void:
	var next_runtime_template_id := str(template_data.get("template_id", ""))
	var should_sync := _current_template == null or (not _dirty and next_runtime_template_id != _runtime_template_id)
	_runtime_template_id = next_runtime_template_id
	if should_sync and not _runtime_template_id.is_empty():
		var template := _manager.load_template(_runtime_template_id)
		if template != null:
			set_template(template)
	_refresh_header()


func refresh_catalog() -> void:
	_manager.refresh()
	var catalog := _manager.list_templates()
	library_panel.set_catalog(catalog)
	if _selected_template_id.is_empty() and not catalog.is_empty():
		_selected_template_id = str(catalog[0].get("template_id", ""))
	if not _selected_template_id.is_empty() and _current_template == null:
		_load_template(_selected_template_id)


func set_template(template: MappingTemplate) -> void:
	_current_template = template.duplicate_template()
	_selected_template_id = _current_template.template_id
	library_panel.set_selected_template_id(_selected_template_id)
	var summary := _summary_formatter.build_summary(_current_template)
	guide_panel.set_summary(summary)
	structured_editor.set_template(_current_template)
	json_editor.text = JSON.stringify(_current_template.to_dict(), "\t")
	_set_dirty(false)
	_refresh_header()


func _load_template(template_id: String) -> void:
	var template := _manager.load_template(template_id)
	if template != null:
		set_template(template)


func _parse_json_template() -> MappingTemplate:
	var json := JSON.new()
	if json.parse(json_editor.text) != OK:
		push_warning("Template JSON parse failed")
		return null
	var template := MappingTemplate.new()
	template.from_dict(json.data)
	return template


func _on_library_selection_changed(template_id: String) -> void:
	_selected_template_id = template_id
	_load_template(template_id)


func _on_library_apply_requested(template_id: String) -> void:
	var template := _manager.load_template(template_id)
	if template == null:
		return
	set_template(template)
	_runtime_template_id = template.template_id
	template_applied.emit(template)


func _on_library_copy_requested(template_id: String) -> void:
	var template := _manager.copy_to_user_template(template_id)
	if template == null:
		return
	set_template(template)
	tabs.current_tab = tabs.get_tab_idx_from_control(structured_editor)
	_set_dirty(true)


func _on_library_new_requested() -> void:
	set_template(_manager.create_blank_template("New Template"))
	tabs.current_tab = tabs.get_tab_idx_from_control(structured_editor)
	_set_dirty(true)


func _on_library_delete_requested(template_id: String) -> void:
	if _manager.delete_user_template(template_id) != OK:
		return
	template_deleted.emit(template_id)
	_selected_template_id = ""
	_current_template = null
	refresh_catalog()
	_refresh_header()


func _on_structured_apply_requested(template: MappingTemplate) -> void:
	set_template(template)
	_runtime_template_id = template.template_id
	template_applied.emit(template)


func _on_structured_save_requested(template: MappingTemplate) -> void:
	if _manager.save_user_template(template) != OK:
		return
	_manager.refresh()
	set_template(template)
	library_panel.set_catalog(_manager.list_templates())
	template_saved.emit(template)


func _on_json_apply_pressed() -> void:
	var template := _parse_json_template()
	if template == null:
		return
	set_template(template)
	_runtime_template_id = template.template_id
	template_applied.emit(template)


func _on_json_save_pressed() -> void:
	var template := _parse_json_template()
	if template == null:
		return
	if _manager.save_user_template(template) != OK:
		return
	_manager.refresh()
	set_template(template)
	library_panel.set_catalog(_manager.list_templates())
	template_saved.emit(template)


func _on_template_changed(_template: MappingTemplate) -> void:
	if _current_template == null:
		return
	_current_template = structured_editor.get_template()
	json_editor.text = JSON.stringify(_current_template.to_dict(), "\t")
	_set_dirty(true)


func _set_dirty(value: bool) -> void:
	_dirty = value
	_refresh_header()


func _refresh_header() -> void:
	if _current_template == null:
		identity_label.text = "No template selected"
		summary_label.text = "Choose a template from the library or create a new one."
		state_label.text = "Idle"
		return
	var summary := _summary_formatter.build_summary(_current_template)
	identity_label.text = "%s  |  %s  |  %s" % [
		_current_template.display_name,
		str(summary.get("control_scheme_label", "Control Scheme")),
		str(summary.get("difficulty_label", "Difficulty")),
	]
	summary_label.text = str(summary.get("summary", "No summary available."))
	if _dirty:
		state_label.text = "Editing"
	elif _runtime_template_id == _current_template.template_id:
		state_label.text = "Applied"
	else:
		state_label.text = "Saved"


func _apply_desktop_theme(panel: Control) -> void:
	panel.theme = null
	panel.remove_theme_stylebox_override("panel")
