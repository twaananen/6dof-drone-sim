class_name MappingTemplate
extends RefCounted

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

var template_name: String = "untitled"
var description: String = ""
var outputs: Dictionary = {}


func _init() -> void:
    outputs = {}
    for output_name in OUTPUT_NAMES:
        outputs[output_name] = _default_output(output_name)


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
        "template_name": template_name,
        "description": description,
        "outputs": outputs.duplicate(true),
    }


func from_dict(data: Dictionary) -> void:
    template_name = data.get("template_name", "untitled")
    description = data.get("description", "")
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
