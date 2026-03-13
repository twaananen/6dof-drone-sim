class_name MappingEngine
extends RefCounted

const MappingTemplate = preload("res://scripts/mapping/mapping_template.gd")

var _template: MappingTemplate = MappingTemplate.new()
var _previous_values: Dictionary = {}
var _smoothed_values: Dictionary = {}
var _integrator_values: Dictionary = {}


func set_template(template: MappingTemplate) -> void:
	_template = template
	reset_state()


func reset_state() -> void:
	_previous_values.clear()
	_smoothed_values.clear()
	_integrator_values.clear()


func process(sources: Dictionary, dt: float) -> Dictionary:
	var outputs := neutral_outputs()
	if _template == null:
		return outputs

	for output_name in MappingTemplate.OUTPUT_NAMES:
		var output_config: Dictionary = _template.outputs.get(output_name, MappingTemplate._default_output(output_name))
		var mixed: float = float(_integrator_values.get(output_name, 0.0))
		var bindings: Array = output_config.get("bindings", [])
		for binding_index in range(bindings.size()):
			var binding: Dictionary = bindings[binding_index]
			mixed += _evaluate_binding(output_name, binding_index, binding, sources, dt)
		outputs[output_name] = _apply_output_processing(output_name, mixed, output_config)
	return outputs


func neutral_outputs() -> Dictionary:
	var outputs: Dictionary = {}
	for output_name in MappingTemplate.OUTPUT_NAMES:
		outputs[output_name] = 0.0
	return outputs


func clear_integrators() -> void:
	_integrator_values.clear()


func _evaluate_binding(output_name: String, binding_index: int, binding: Dictionary, sources: Dictionary, dt: float) -> float:
	var key := "%s:%d:%s" % [output_name, binding_index, binding.get("source", "")]
	var raw_value := float(sources.get(binding.get("source", ""), 0.0))
	var normalized := _normalize(raw_value, float(binding.get("range_min", -1.0)), float(binding.get("range_max", 1.0)))
	if binding.get("invert", false):
		normalized = -normalized
	normalized = _apply_curve(normalized, str(binding.get("curve", "linear")))

	var smoothing := float(binding.get("smoothing", 0.0))
	if smoothing > 0.0:
		var previous_smoothed := float(_smoothed_values.get(key, normalized))
		var alpha := clampf(dt / maxf(smoothing, dt), 0.0, 1.0)
		normalized = lerpf(previous_smoothed, normalized, alpha)
		_smoothed_values[key] = normalized

	var previous_normalized := float(_previous_values.get(key, normalized))
	_previous_values[key] = normalized

	var weight := float(binding.get("weight", 1.0))
	match str(binding.get("mode", "absolute")):
		"absolute":
			return normalized * weight
		"delta":
			if dt <= 0.0:
				return 0.0
			return (normalized - previous_normalized) * weight
		"integrator":
			var current := float(_integrator_values.get(output_name, 0.0))
			current += (normalized - previous_normalized) * weight
			current = clampf(current, -1.0, 1.0)
			_integrator_values[output_name] = current
			return 0.0
		_:
			return normalized * weight


func _normalize(value: float, range_min: float, range_max: float) -> float:
	var span := range_max - range_min
	if is_zero_approx(span):
		return 0.0
	var center := (range_min + range_max) * 0.5
	var half_span := span * 0.5
	return clampf((value - center) / half_span, -1.0, 1.0)


func _cubic_expo(value: float, amount: float) -> float:
	var abs_value := absf(value)
	return signf(value) * (amount * abs_value * abs_value * abs_value + (1.0 - amount) * abs_value)


func _apply_curve(value: float, curve: String) -> float:
	match curve:
		"expo_soft":
			return _cubic_expo(value, 0.35)
		"expo_hard":
			return _cubic_expo(value, 0.7)
		_:
			return value


func _apply_output_processing(output_name: String, value: float, output_config: Dictionary) -> float:
	var deadzone := float(output_config.get("deadzone", 0.0))
	var expo := float(output_config.get("expo", 0.0))
	var sensitivity := float(output_config.get("sensitivity", 1.0))
	var invert_output := bool(output_config.get("invert_output", false))
	var output_min := float(output_config.get("output_min", -1.0))
	var output_max := float(output_config.get("output_max", 1.0))

	var abs_value := absf(value)
	if deadzone > 0.0:
		if abs_value <= deadzone:
			value = 0.0
		elif deadzone >= 1.0:
			value = 0.0
		else:
			value = signf(value) * ((abs_value - deadzone) / (1.0 - deadzone))

	if expo > 0.0:
		value = _cubic_expo(value, expo)

	value *= sensitivity
	if invert_output:
		value = -value
	value = clampf(value, output_min, output_max)

	if output_name.begins_with("aux_button_"):
		return 1.0 if value >= 0.5 else 0.0
	return value
