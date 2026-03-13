class_name TemplateManager
extends RefCounted

const MappingTemplate = preload("res://scripts/mapping/mapping_template.gd")
const BUNDLED_DIR := "res://templates/"
const USER_DIR := "user://templates/"

var _catalog: Dictionary = {}


func _init() -> void:
    _ensure_user_dir()
    refresh()


func refresh() -> void:
    _catalog.clear()
    _scan_dir(BUNDLED_DIR, true)
    _scan_dir(USER_DIR, false)


func list_names() -> PackedStringArray:
    var names: PackedStringArray = PackedStringArray(_catalog.keys())
    names.sort()
    return names


func load_template(name: String) -> MappingTemplate:
    if name not in _catalog:
        return null
    var template: MappingTemplate = MappingTemplate.new()
    if template.load_from_file(_catalog[name]["path"]) != OK:
        return null
    return template


func save_user_template(template: MappingTemplate) -> Error:
    var path: String = USER_DIR + template.template_name.to_snake_case() + ".json"
    var err: Error = template.save_to_file(path)
    if err == OK:
        _catalog[template.template_name] = {"path": path, "bundled": false}
    return err


func delete_user_template(name: String) -> Error:
    if name not in _catalog:
        return ERR_DOES_NOT_EXIST
    if _catalog[name]["bundled"]:
        return ERR_UNAUTHORIZED
    var global_path: String = ProjectSettings.globalize_path(_catalog[name]["path"])
    var err: Error = DirAccess.remove_absolute(global_path)
    if err == OK:
        _catalog.erase(name)
    return err


func create_blank_template(name: String = "new_template") -> MappingTemplate:
    var template: MappingTemplate = MappingTemplate.new()
    template.template_name = name
    template.description = "Editable template"
    template.add_binding("throttle", MappingTemplate.default_binding("trigger", "absolute"))
    template.outputs["throttle"]["bindings"][0]["range_min"] = 0.0
    template.outputs["throttle"]["bindings"][0]["range_max"] = 1.0
    return template


func _ensure_user_dir() -> void:
    DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(USER_DIR))


func _scan_dir(dir_path: String, bundled: bool) -> void:
    var dir: DirAccess = DirAccess.open(dir_path)
    if dir == null:
        return
    dir.list_dir_begin()
    var name: String = dir.get_next()
    while name != "":
        if not dir.current_is_dir() and name.ends_with(".json"):
            var template: MappingTemplate = MappingTemplate.new()
            var full_path: String = dir_path + name
            if template.load_from_file(full_path) == OK:
                _catalog[template.template_name] = {"path": full_path, "bundled": bundled}
        name = dir.get_next()
