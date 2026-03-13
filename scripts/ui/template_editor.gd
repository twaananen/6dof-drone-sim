class_name TemplateEditor
extends Control

const MappingTemplate = preload("res://scripts/mapping/mapping_template.gd")
const TemplateManager = preload("res://scripts/ui/template_manager.gd")

signal template_applied(template)
signal template_saved(template)
signal template_deleted(template_name)

var _manager: TemplateManager = TemplateManager.new()
var _current_template: MappingTemplate

@onready var template_select: OptionButton = $VBox/Toolbar/TemplateSelect
@onready var new_button: Button = $VBox/Toolbar/NewButton
@onready var apply_button: Button = $VBox/Toolbar/ApplyButton
@onready var save_button: Button = $VBox/Toolbar/SaveButton
@onready var delete_button: Button = $VBox/Toolbar/DeleteButton
@onready var editor: TextEdit = $VBox/Editor


func _ready() -> void:
    template_select.item_selected.connect(_on_template_selected)
    new_button.pressed.connect(_on_new_pressed)
    apply_button.pressed.connect(_on_apply_pressed)
    save_button.pressed.connect(_on_save_pressed)
    delete_button.pressed.connect(_on_delete_pressed)
    refresh_catalog()


func refresh_catalog() -> void:
    _manager.refresh()
    template_select.clear()
    for name in _manager.list_names():
        template_select.add_item(name)
    if template_select.item_count > 0:
        template_select.select(0)
        _load_template(template_select.get_item_text(0))


func set_template(template: MappingTemplate) -> void:
    _current_template = template
    editor.text = JSON.stringify(template.to_dict(), "\t")


func _load_template(name: String) -> void:
    var template: MappingTemplate = _manager.load_template(name)
    if template != null:
        set_template(template)


func _parse_editor_template() -> MappingTemplate:
    var json: JSON = JSON.new()
    if json.parse(editor.text) != OK:
        push_warning("Template JSON parse failed")
        return null
    var template: MappingTemplate = MappingTemplate.new()
    template.from_dict(json.data)
    return template


func _on_template_selected(index: int) -> void:
    _load_template(template_select.get_item_text(index))


func _on_new_pressed() -> void:
    var template: MappingTemplate = _manager.create_blank_template("template_%d" % Time.get_ticks_msec())
    set_template(template)


func _on_apply_pressed() -> void:
    var parsed: MappingTemplate = _parse_editor_template()
    if parsed == null:
        return
    _current_template = parsed
    template_applied.emit(parsed)


func _on_save_pressed() -> void:
    var parsed: MappingTemplate = _parse_editor_template()
    if parsed == null:
        return
    _current_template = parsed
    if _manager.save_user_template(parsed) == OK:
        refresh_catalog()
        template_saved.emit(parsed)


func _on_delete_pressed() -> void:
    if _current_template == null:
        return
    var name := _current_template.template_name
    if _manager.delete_user_template(name) == OK:
        refresh_catalog()
        editor.text = ""
        template_deleted.emit(name)
