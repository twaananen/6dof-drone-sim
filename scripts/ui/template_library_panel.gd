class_name TemplateLibraryPanel
extends PanelContainer

const MappingTemplate = preload("res://scripts/mapping/mapping_template.gd")
const TemplateSummaryFormatter = preload("res://scripts/mapping/template_summary_formatter.gd")

signal selection_changed(template_id)
signal apply_requested(template_id)
signal copy_requested(template_id)
signal new_requested()
signal delete_requested(template_id)

var _catalog: Array = []
var _selected_template_id: String = ""
var _scheme_filter: String = ""
var _difficulty_filter: String = ""

@onready var scheme_filter_select: OptionButton = $Margin/VBox/Filters/SchemeFilterSelect
@onready var difficulty_filter_select: OptionButton = $Margin/VBox/Filters/DifficultyFilterSelect
@onready var list: ItemList = $Margin/VBox/List
@onready var summary_label: Label = $Margin/VBox/Summary
@onready var apply_button: Button = $Margin/VBox/Buttons/ApplyButton
@onready var copy_button: Button = $Margin/VBox/Buttons/CopyButton
@onready var new_button: Button = $Margin/VBox/Buttons/NewButton
@onready var delete_button: Button = $Margin/VBox/Buttons/DeleteButton


func _ready() -> void:
	_load_filter_options()
	scheme_filter_select.item_selected.connect(_on_scheme_filter_selected)
	difficulty_filter_select.item_selected.connect(_on_difficulty_filter_selected)
	list.item_selected.connect(_on_item_selected)
	apply_button.pressed.connect(func(): apply_requested.emit(_selected_template_id))
	copy_button.pressed.connect(func(): copy_requested.emit(_selected_template_id))
	new_button.pressed.connect(func(): new_requested.emit())
	delete_button.pressed.connect(func(): delete_requested.emit(_selected_template_id))
	_refresh()


func set_catalog(catalog: Array) -> void:
	_catalog.clear()
	for item in catalog:
		if typeof(item) == TYPE_DICTIONARY:
			_catalog.append(item.duplicate(true))
	_refresh()


func get_selected_template_id() -> String:
	return _selected_template_id


func set_selected_template_id(template_id: String) -> void:
	_selected_template_id = template_id
	_refresh()


func _refresh() -> void:
	if not is_node_ready():
		return
	list.clear()
	var visible_catalog := _visible_catalog()
	for item in visible_catalog:
		var label := "%s [%s]" % [
			str(item.get("display_name", "")),
			str(item.get("difficulty_label", item.get("difficulty", ""))),
		]
		list.add_item(label)
		list.set_item_metadata(list.item_count - 1, str(item.get("template_id", "")))
		if str(item.get("template_id", "")) == _selected_template_id:
			list.select(list.item_count - 1)
			_update_summary(item)
	if list.item_count > 0 and list.is_anything_selected() == false:
		list.select(0)
		_selected_template_id = str(list.get_item_metadata(0))
		_update_summary(_find_summary(_selected_template_id))
	elif list.item_count == 0:
		_selected_template_id = ""
		_update_summary({})
	copy_button.disabled = _selected_template_id.is_empty()
	apply_button.disabled = _selected_template_id.is_empty()
	var selected_summary := _find_summary(_selected_template_id)
	delete_button.disabled = _selected_template_id.is_empty() or str(selected_summary.get("origin", "")) != "user"


func _on_item_selected(index: int) -> void:
	_selected_template_id = str(list.get_item_metadata(index))
	_update_summary(_find_summary(_selected_template_id))
	selection_changed.emit(_selected_template_id)


func _find_summary(template_id: String) -> Dictionary:
	for item in _catalog:
		if str(item.get("template_id", "")) == template_id:
			return item
	return {}


func _update_summary(summary: Dictionary) -> void:
	if summary.is_empty():
		summary_label.text = "No templates match the current filters."
		return
	var lines := PackedStringArray()
	lines.append(str(summary.get("summary", "")))
	lines.append("Scheme: %s" % str(summary.get("control_scheme_label", summary.get("control_scheme", ""))))
	lines.append("Origin: %s" % str(summary.get("origin", "")))
	summary_label.text = "\n".join(lines)


func _load_filter_options() -> void:
	scheme_filter_select.clear()
	scheme_filter_select.add_item("All Schemes")
	scheme_filter_select.set_item_metadata(0, "")
	var scheme_keys := TemplateSummaryFormatter.CONTROL_SCHEME_LABELS.keys()
	scheme_keys.sort()
	for scheme in scheme_keys:
		scheme_filter_select.add_item(str(TemplateSummaryFormatter.CONTROL_SCHEME_LABELS.get(scheme, scheme)))
		scheme_filter_select.set_item_metadata(scheme_filter_select.item_count - 1, scheme)
	scheme_filter_select.select(0)

	difficulty_filter_select.clear()
	difficulty_filter_select.add_item("All Difficulties")
	difficulty_filter_select.set_item_metadata(0, "")
	for difficulty in MappingTemplate.difficulty_options():
		difficulty_filter_select.add_item(str(TemplateSummaryFormatter.DIFFICULTY_LABELS.get(difficulty, difficulty)))
		difficulty_filter_select.set_item_metadata(difficulty_filter_select.item_count - 1, difficulty)
	difficulty_filter_select.select(0)


func _visible_catalog() -> Array:
	var visible: Array = []
	for item in _catalog:
		if not _scheme_filter.is_empty() and str(item.get("control_scheme", "")) != _scheme_filter:
			continue
		if not _difficulty_filter.is_empty() and str(item.get("difficulty", "")) != _difficulty_filter:
			continue
		visible.append(item)
	return visible


func _on_scheme_filter_selected(index: int) -> void:
	_scheme_filter = str(scheme_filter_select.get_item_metadata(index))
	_refresh()


func _on_difficulty_filter_selected(index: int) -> void:
	_difficulty_filter = str(difficulty_filter_select.get_item_metadata(index))
	_refresh()
