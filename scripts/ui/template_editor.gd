class_name TemplateEditor
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

@onready var tabs: TabContainer = $VBox/Tabs
@onready var library_panel: TemplateLibraryPanel = $VBox/Tabs/Library
@onready var guide_panel: TemplateGuidePanel = $VBox/Tabs/Guide
@onready var structured_editor: TemplateStructuredEditor = $VBox/Tabs/Editor
@onready var json_editor: TextEdit = $VBox/Tabs/AdvancedJson/VBox/Editor
@onready var json_apply_button: Button = $VBox/Tabs/AdvancedJson/VBox/Buttons/ApplyButton
@onready var json_save_button: Button = $VBox/Tabs/AdvancedJson/VBox/Buttons/SaveButton


func _ready() -> void:
	library_panel.selection_changed.connect(_on_library_selection_changed)
	library_panel.apply_requested.connect(_on_library_apply_requested)
	library_panel.copy_requested.connect(_on_library_copy_requested)
	library_panel.new_requested.connect(_on_library_new_requested)
	library_panel.delete_requested.connect(_on_library_delete_requested)
	structured_editor.apply_requested.connect(_on_structured_apply_requested)
	structured_editor.save_requested.connect(_on_structured_save_requested)
	json_apply_button.pressed.connect(_on_json_apply_pressed)
	json_save_button.pressed.connect(_on_json_save_pressed)
	refresh_catalog()


func refresh_catalog() -> void:
	_manager.refresh()
	var catalog := _manager.list_templates()
	library_panel.set_catalog(catalog)
	if _selected_template_id.is_empty() and not catalog.is_empty():
		_selected_template_id = str(catalog[0].get("template_id", ""))
	if not _selected_template_id.is_empty():
		_load_template(_selected_template_id)


func set_template(template: MappingTemplate) -> void:
	_current_template = template.duplicate_template()
	_selected_template_id = _current_template.template_id
	library_panel.set_selected_template_id(_selected_template_id)
	var summary := _summary_formatter.build_summary(_current_template)
	guide_panel.set_summary(summary)
	structured_editor.set_template(_current_template)
	json_editor.text = JSON.stringify(_current_template.to_dict(), "\t")


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
	template_applied.emit(template)


func _on_library_copy_requested(template_id: String) -> void:
	var template := _manager.copy_to_user_template(template_id)
	if template == null:
		return
	set_template(template)
	tabs.current_tab = tabs.get_tab_idx_from_control(structured_editor)


func _on_library_new_requested() -> void:
	set_template(_manager.create_blank_template("New Template"))
	tabs.current_tab = tabs.get_tab_idx_from_control(structured_editor)


func _on_library_delete_requested(template_id: String) -> void:
	if _manager.delete_user_template(template_id) != OK:
		return
	template_deleted.emit(template_id)
	_selected_template_id = ""
	refresh_catalog()


func _on_structured_apply_requested(template: MappingTemplate) -> void:
	set_template(template)
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
