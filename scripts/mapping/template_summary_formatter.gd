class_name TemplateSummaryFormatter
extends RefCounted

const MappingTemplate = preload("res://scripts/mapping/mapping_template.gd")

const OUTPUT_LABELS := {
	"throttle": "Throttle",
	"yaw": "Yaw",
	"pitch": "Pitch",
	"roll": "Roll",
	"aux_analog_1": "Aux Analog 1",
	"aux_analog_2": "Aux Analog 2",
	"aux_button_1": "Aux Button 1",
	"aux_button_2": "Aux Button 2",
	"aux_button_3": "Aux Button 3",
	"aux_button_4": "Aux Button 4",
}

const SOURCE_LABELS := {
	"trigger": "trigger squeeze",
	"grip": "grip squeeze",
	"thumbstick_x": "thumbstick X",
	"thumbstick_y": "thumbstick Y",
	"pose_pitch_deg": "controller pitch angle",
	"pose_yaw_deg": "controller yaw angle",
	"pose_roll_deg": "controller roll angle",
	"swing_pitch_deg": "forward/back hand tilt",
	"swing_yaw_deg": "left/right hand yaw swing",
	"twist_roll_deg": "wrist roll twist",
	"pos_x_m": "hand left/right position",
	"pos_y_m": "hand height",
	"pos_z_m": "hand forward/back position",
	"angvel_x_rad_s": "pitch rotation speed",
	"angvel_y_rad_s": "yaw rotation speed",
	"angvel_z_rad_s": "roll rotation speed",
	"linvel_x_m_s": "left/right hand speed",
	"linvel_y_m_s": "vertical hand speed",
	"linvel_z_m_s": "forward/back hand speed",
	"radius_xyz_m": "hand distance from origin",
	"radius_xz_m": "hand horizontal distance from origin",
	"button_south": "A button",
	"button_east": "B button",
	"button_west": "X button",
	"button_north": "Y button",
	"button_thumbstick": "thumbstick click",
	"button_menu": "menu button",
}

const CONTROL_SCHEME_LABELS := {
	"absolute_attitude": "Absolute Attitude",
	"direct_rate": "Direct Rate",
	"latched_attitude": "Latched Attitude",
	"impulse_latched": "Impulse Latched",
	"blended_precision": "Blended Precision",
	"blended_rate": "Blended Rate",
	"position_orientation_blend": "Position + Orientation Blend",
	"experimental": "Experimental",
}

const DIFFICULTY_LABELS := {
	"beginner": "Beginner",
	"intermediate": "Intermediate",
	"advanced": "Advanced",
	"experimental": "Experimental",
}


func build_summary(template: MappingTemplate) -> Dictionary:
	var summary: Dictionary = template.to_summary_dict()
	summary["binding_lines"] = build_binding_lines(template)
	summary["mode_lines"] = build_mode_lines(template)
	summary["assist_lines"] = build_assist_lines(template)
	summary["control_scheme_label"] = CONTROL_SCHEME_LABELS.get(
		template.control_scheme,
		template.control_scheme.capitalize()
	)
	summary["difficulty_label"] = DIFFICULTY_LABELS.get(template.difficulty, template.difficulty.capitalize())
	return summary


func build_binding_lines(template: MappingTemplate) -> Array:
	var lines: Array = []
	for output_name in MappingTemplate.OUTPUT_NAMES:
		var output_config: Dictionary = template.outputs.get(output_name, {})
		var bindings: Array = output_config.get("bindings", [])
		if bindings.is_empty():
			continue
		var parts: Array = []
		for binding in bindings:
			parts.append(_binding_phrase(binding))
		lines.append("%s: %s" % [OUTPUT_LABELS.get(output_name, output_name), "; ".join(parts)])
	return lines


func build_mode_lines(template: MappingTemplate) -> Array:
	var lines: Array = []
	lines.append("Betaflight: %s" % _recommendation_phrase(template.betaflight_recommendation))
	lines.append("Liftoff: %s" % _recommendation_phrase(template.liftoff_recommendation))
	return lines


func build_assist_lines(template: MappingTemplate) -> Array:
	var lines: Array = []
	var assists: Dictionary = template.liftoff_assists
	var recommended: Array = assists.get("recommended", [])
	var optional: Array = assists.get("optional", [])
	var avoid: Array = assists.get("avoid", [])
	if not recommended.is_empty():
		lines.append("Recommended assists: %s" % ", ".join(recommended))
	if not optional.is_empty():
		lines.append("Optional assists: %s" % ", ".join(optional))
	if not avoid.is_empty():
		lines.append("Avoid assists: %s" % ", ".join(avoid))
	var notes := str(assists.get("notes", ""))
	if not notes.is_empty():
		lines.append(notes)
	return lines


func _binding_phrase(binding: Dictionary) -> String:
	var source: String = str(SOURCE_LABELS.get(str(binding.get("source", "")), str(binding.get("source", ""))))
	var mode: String = str(binding.get("mode", "absolute"))
	var phrase: String = ""
	match mode:
		"delta":
			phrase = "change in %s" % source
		"integrator":
			phrase = "latched deflection from changes in %s" % source
		_:
			phrase = "%s" % source
	if bool(binding.get("invert", false)):
		phrase += " (inverted)"
	phrase += " [%s]" % mode
	return phrase


func _recommendation_phrase(recommendation: Dictionary) -> String:
	var parts: Array = []
	var recommended: Array = recommendation.get("recommended", [])
	var acceptable: Array = recommendation.get("acceptable", [])
	var avoid: Array = recommendation.get("avoid", [])
	var notes := str(recommendation.get("notes", ""))
	if not recommended.is_empty():
		parts.append("recommended %s" % ", ".join(recommended))
	if not acceptable.is_empty():
		parts.append("acceptable %s" % ", ".join(acceptable))
	if not avoid.is_empty():
		parts.append("avoid %s" % ", ".join(avoid))
	if not notes.is_empty():
		parts.append(notes)
	return " | ".join(parts)
