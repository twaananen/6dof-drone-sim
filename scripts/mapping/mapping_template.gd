class_name MappingTemplate
extends RefCounted

const SCHEMA_VERSION := 2

const OUTPUT_NAMES := [
	"throttle",
	"yaw",
	"pitch",
	"roll",
	"aux_analog_1",
	"aux_analog_2",
	"aux_button_1",
	"aux_button_2",
	"aux_button_3",
	"aux_button_4",
]

const DEFAULT_CURVES := ["linear", "expo_soft", "expo_hard"]
const DEFAULT_MODES := ["absolute", "delta", "integrator"]

var schema_version: int = SCHEMA_VERSION
var template_id: String = ""
var slug: String = "untitled"
var display_name: String = "Untitled Template"
var origin: String = "user"
var source_template_id: String = ""
var summary: String = ""
var control_scheme: String = "experimental"
var difficulty: String = "experimental"
var betaflight_recommendation: Dictionary = {}
var liftoff_recommendation: Dictionary = {}
var liftoff_assists: Dictionary = {}
var warnings: Array = []
var usage_tips: Array = []
var outputs: Dictionary = {}


func _init() -> void:
	betaflight_recommendation = _default_recommendation()
	liftoff_recommendation = _default_recommendation()
	liftoff_assists = _default_assists()
	outputs = {}
	for output_name in OUTPUT_NAMES:
		outputs[output_name] = _default_output(output_name)


static func _default_recommendation() -> Dictionary:
	return {
		"recommended": [],
		"acceptable": [],
		"avoid": [],
		"notes": "",
	}


static func _default_assists() -> Dictionary:
	return {
		"recommended": [],
		"optional": [],
		"avoid": [],
		"notes": "",
	}


static func _default_output(output_name: String) -> Dictionary:
	var is_button: bool = output_name.begins_with("aux_button_")
	return {
		"bindings": [],
		"deadzone": 0.0,
		"expo": 0.0,
		"sensitivity": 1.0,
		"invert_output": false,
		"output_min": 0.0 if is_button else -1.0,
		"output_max": 1.0,
	}


static func default_binding(source: String = "trigger", mode: String = "absolute") -> Dictionary:
	return {
		"source": source,
		"mode": mode,
		"range_min": -1.0,
		"range_max": 1.0,
		"weight": 1.0,
		"invert": false,
		"smoothing": 0.0,
		"curve": "linear",
	}


func add_binding(output_name: String, binding: Dictionary) -> void:
	if output_name not in outputs:
		return
	outputs[output_name]["bindings"].append(binding)


func to_dict() -> Dictionary:
	return {
		"schema_version": schema_version,
		"template_id": template_id,
		"slug": slug,
		"display_name": display_name,
		"origin": origin,
		"source_template_id": source_template_id,
		"summary": summary,
		"control_scheme": control_scheme,
		"difficulty": difficulty,
		"betaflight_recommendation": betaflight_recommendation.duplicate(true),
		"liftoff_recommendation": liftoff_recommendation.duplicate(true),
		"liftoff_assists": liftoff_assists.duplicate(true),
		"warnings": warnings.duplicate(true),
		"usage_tips": usage_tips.duplicate(true),
		"outputs": outputs.duplicate(true),
	}


func to_summary_dict() -> Dictionary:
	return {
		"template_id": template_id,
		"slug": slug,
		"display_name": display_name,
		"origin": origin,
		"source_template_id": source_template_id,
		"summary": summary,
		"control_scheme": control_scheme,
		"difficulty": difficulty,
		"betaflight_recommendation": betaflight_recommendation.duplicate(true),
		"liftoff_recommendation": liftoff_recommendation.duplicate(true),
		"liftoff_assists": liftoff_assists.duplicate(true),
		"warnings": warnings.duplicate(true),
		"usage_tips": usage_tips.duplicate(true),
	}


func duplicate_template() -> MappingTemplate:
	var copy := MappingTemplate.new()
	copy.from_dict(to_dict())
	return copy


func copy_as_user_template() -> MappingTemplate:
	var copy := duplicate_template()
	copy.origin = "user"
	copy.source_template_id = template_id
	copy.template_id = ""
	return copy


func with_global_tuning(settings: Dictionary) -> MappingTemplate:
	var tuned := duplicate_template()
	for output_name in tuned.outputs.keys():
		var output: Dictionary = tuned.outputs[output_name]
		if "sensitivity" in settings:
			output["sensitivity"] = settings["sensitivity"]
		if "deadzone" in settings:
			output["deadzone"] = settings["deadzone"]
		if "expo" in settings:
			output["expo"] = settings["expo"]
		if "integrator_gain" in settings:
			for binding in output["bindings"]:
				if binding.get("mode", "") == "integrator":
					binding["weight"] = settings["integrator_gain"]
	return tuned


func from_dict(data: Dictionary) -> void:
	schema_version = int(data.get("schema_version", SCHEMA_VERSION))
	template_id = str(data.get("template_id", ""))
	slug = str(data.get("slug", "untitled"))
	display_name = str(data.get("display_name", slug.capitalize()))
	origin = str(data.get("origin", "user"))
	source_template_id = str(data.get("source_template_id", ""))
	summary = str(data.get("summary", ""))
	control_scheme = str(data.get("control_scheme", "experimental"))
	difficulty = str(data.get("difficulty", "experimental"))
	betaflight_recommendation = _merge_recommendation(
		_default_recommendation(),
		data.get("betaflight_recommendation", {})
	)
	liftoff_recommendation = _merge_recommendation(
		_default_recommendation(),
		data.get("liftoff_recommendation", {})
	)
	liftoff_assists = _merge_assists(_default_assists(), data.get("liftoff_assists", {}))
	warnings = _string_array(data.get("warnings", []))
	usage_tips = _string_array(data.get("usage_tips", []))

	outputs = {}
	for output_name in OUTPUT_NAMES:
		var merged: Dictionary = _default_output(output_name)
		var loaded: Dictionary = data.get("outputs", {}).get(output_name, {})
		for key in loaded.keys():
			merged[key] = loaded[key]
		outputs[output_name] = merged


func save_to_file(path: String) -> Error:
	var file: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		return FileAccess.get_open_error()
	file.store_string(JSON.stringify(to_dict(), "\t"))
	file.close()
	return OK


func load_from_file(path: String) -> Error:
	var file: FileAccess = FileAccess.open(path, FileAccess.READ)
	if file == null:
		return FileAccess.get_open_error()
	var text: String = file.get_as_text()
	file.close()

	var json: JSON = JSON.new()
	var err: Error = json.parse(text)
	if err != OK:
		return err
	from_dict(json.data)
	return OK


func is_bundled() -> bool:
	return origin == "bundled"


static func difficulty_options() -> Array:
	return ["beginner", "intermediate", "advanced", "experimental"]


static func control_scheme_options() -> Array:
	return [
		"absolute_attitude",
		"direct_rate",
		"latched_attitude",
		"impulse_latched",
		"blended_precision",
		"blended_rate",
		"position_orientation_blend",
		"experimental",
	]


static func _merge_recommendation(base: Dictionary, data: Variant) -> Dictionary:
	var merged := base.duplicate(true)
	if typeof(data) != TYPE_DICTIONARY:
		return merged
	for key in ["recommended", "acceptable", "avoid"]:
		merged[key] = _string_array(data.get(key, []))
	merged["notes"] = str(data.get("notes", ""))
	return merged


static func _merge_assists(base: Dictionary, data: Variant) -> Dictionary:
	var merged := base.duplicate(true)
	if typeof(data) != TYPE_DICTIONARY:
		return merged
	for key in ["recommended", "optional", "avoid"]:
		merged[key] = _string_array(data.get(key, []))
	merged["notes"] = str(data.get("notes", ""))
	return merged


static func _string_array(value: Variant) -> Array:
	var result: Array = []
	if typeof(value) != TYPE_ARRAY:
		return result
	for item in value:
		result.append(str(item))
	return result
