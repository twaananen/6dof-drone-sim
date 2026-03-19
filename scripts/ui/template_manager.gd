class_name TemplateManager
extends RefCounted

const MappingTemplate = preload("res://scripts/mapping/mapping_template.gd")
const TemplateSummaryFormatter = preload("res://scripts/mapping/template_summary_formatter.gd")

const BUNDLED_DIR := "res://templates/"
const USER_DIR := "user://templates/"
const BUNDLED_PREFIX := "bundled."
const USER_PREFIX := "user."
const ULID_ALPHABET := "0123456789ABCDEFGHJKMNPQRSTVWXYZ"

var _catalog: Dictionary = {}
var _summary_formatter := TemplateSummaryFormatter.new()


func _init() -> void:
	ensure_user_dir()
	refresh()


func ensure_user_dir() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(USER_DIR))


func refresh() -> void:
	_catalog.clear()
	_scan_dir(BUNDLED_DIR, "bundled")
	_scan_dir(USER_DIR, "user")


func list_templates() -> Array:
	var templates: Array = []
	for template_id in _catalog.keys():
		var entry: Dictionary = _catalog[template_id]
		templates.append(entry.get("summary", {}).duplicate(true))
	templates.sort_custom(_sort_summaries)
	return templates


func list_ids() -> PackedStringArray:
	var ids := PackedStringArray()
	for summary in list_templates():
		ids.append(str(summary.get("template_id", "")))
	return ids


func load_template(template_id: String) -> MappingTemplate:
	if template_id not in _catalog:
		return null
	var template := MappingTemplate.new()
	if template.load_from_file(_catalog[template_id]["path"]) != OK:
		return null
	return template


func get_summary(template_id: String) -> Dictionary:
	if template_id not in _catalog:
		return {}
	return _catalog[template_id].get("summary", {}).duplicate(true)


func create_blank_template(display_name: String = "New Template") -> MappingTemplate:
	var template := MappingTemplate.new()
	template.template_id = _generate_user_template_id()
	template.origin = "user"
	template.display_name = display_name
	template.slug = ensure_unique_slug(_slugify(display_name), template.template_id)
	template.summary = "New editable template."
	template.add_binding("throttle", MappingTemplate.default_binding("trigger", "absolute"))
	template.outputs["throttle"]["bindings"][0]["range_min"] = 0.0
	template.outputs["throttle"]["bindings"][0]["range_max"] = 1.0
	return template


func copy_to_user_template(template_id: String) -> MappingTemplate:
	var source := load_template(template_id)
	if source == null:
		return null
	var copy := source.copy_as_user_template()
	copy.template_id = _generate_user_template_id()
	copy.display_name = "%s Copy" % source.display_name
	copy.slug = ensure_unique_slug(_slugify(copy.display_name), copy.template_id)
	return copy


func save_user_template(template: MappingTemplate) -> Error:
	var previous_id := template.template_id
	template.origin = "user"
	if template.template_id.is_empty() or not template.template_id.begins_with(USER_PREFIX):
		if template.source_template_id.is_empty() and not previous_id.is_empty():
			template.source_template_id = previous_id
		template.template_id = _generate_user_template_id()
	template.slug = ensure_unique_slug(_slugify(template.slug if not template.slug.is_empty() else template.display_name), template.template_id)
	var path := USER_DIR + "%s--%s.json" % [template.slug, _short_id(template.template_id)]
	if template.template_id in _catalog:
		var previous_path := str(_catalog[template.template_id].get("path", ""))
		if not previous_path.is_empty() and previous_path != path:
			DirAccess.remove_absolute(ProjectSettings.globalize_path(previous_path))
	var err := template.save_to_file(path)
	if err == OK:
		_catalog[template.template_id] = {
			"path": path,
			"origin": "user",
			"summary": _summary_formatter.build_summary(template),
		}
	return err


func delete_user_template(template_id: String) -> Error:
	if template_id not in _catalog:
		return ERR_DOES_NOT_EXIST
	var entry: Dictionary = _catalog[template_id]
	if str(entry.get("origin", "")) != "user":
		return ERR_UNAUTHORIZED
	var global_path := ProjectSettings.globalize_path(str(entry.get("path", "")))
	var err := DirAccess.remove_absolute(global_path)
	if err == OK:
		_catalog.erase(template_id)
	return err


func ensure_unique_slug(base_slug: String, template_id: String = "") -> String:
	var candidate := base_slug if not base_slug.is_empty() else "template"
	var index := 2
	while _slug_in_use(candidate, template_id):
		candidate = "%s_%d" % [base_slug, index]
		index += 1
	return candidate


func _slug_in_use(candidate: String, template_id: String) -> bool:
	for existing_id in _catalog.keys():
		if existing_id == template_id:
			continue
		var summary: Dictionary = _catalog[existing_id].get("summary", {})
		if str(summary.get("slug", "")) == candidate:
			return true
	return false


func _scan_dir(dir_path: String, origin: String) -> void:
	var dir := DirAccess.open(dir_path)
	if dir == null:
		return
	dir.list_dir_begin()
	var name := dir.get_next()
	while name != "":
		if not dir.current_is_dir() and name.ends_with(".json"):
			var template := MappingTemplate.new()
			var full_path := dir_path + name
			if template.load_from_file(full_path) == OK:
				if template.template_id.is_empty():
					template.template_id = _default_template_id(origin, template.slug if not template.slug.is_empty() else name.get_basename())
				if template.origin.is_empty():
					template.origin = origin
				_catalog[template.template_id] = {
					"path": full_path,
					"origin": origin,
					"summary": _summary_formatter.build_summary(template),
				}
		name = dir.get_next()
	dir.list_dir_end()


func _default_template_id(origin: String, slug: String) -> String:
	var prefix := BUNDLED_PREFIX if origin == "bundled" else USER_PREFIX
	return "%s%s" % [prefix, _slugify(slug)]


func _generate_user_template_id() -> String:
	return "%s%s" % [USER_PREFIX, _generate_ulid()]


func _short_id(template_id: String) -> String:
	return template_id.split(".")[-1].substr(0, 6).to_lower()


func _generate_ulid() -> String:
	var timestamp_ms := int(Time.get_unix_time_from_system() * 1000.0)
	var prefix := _encode_base32(timestamp_ms, 10)
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	var suffix := ""
	for _i in range(16):
		suffix += ULID_ALPHABET[rng.randi_range(0, ULID_ALPHABET.length() - 1)]
	return prefix + suffix


func _encode_base32(value: int, width: int) -> String:
	var remaining := maxi(value, 0)
	var output := ""
	for _i in range(width):
		output = ULID_ALPHABET[remaining % 32] + output
		remaining = int(remaining / 32)
	return output


func _slugify(value: String) -> String:
	var lower := value.to_lower().strip_edges()
	var result := ""
	for index in range(lower.length()):
		var ch := lower.unicode_at(index)
		if (ch >= 97 and ch <= 122) or (ch >= 48 and ch <= 57):
			result += String.chr(ch)
		elif result.is_empty() or result.ends_with("_"):
			continue
		else:
			result += "_"
	result = result.strip_edges()
	result = result.trim_suffix("_")
	if result.is_empty():
		return "template"
	return result


func _sort_summaries(a: Dictionary, b: Dictionary) -> bool:
	var a_origin := str(a.get("origin", "user"))
	var b_origin := str(b.get("origin", "user"))
	if a_origin != b_origin:
		return a_origin == "bundled"
	return str(a.get("display_name", "")).naturalnocasecmp_to(str(b.get("display_name", ""))) < 0
