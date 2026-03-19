extends "res://addons/gut/test.gd"

const MappingTemplate = preload("res://scripts/mapping/mapping_template.gd")
const TemplateSummaryFormatter = preload("res://scripts/mapping/template_summary_formatter.gd")


func test_build_summary_includes_binding_mode_language() -> void:
	var formatter := TemplateSummaryFormatter.new()
	var template := MappingTemplate.new()
	template.template_id = "bundled.demo"
	template.display_name = "Demo"
	template.summary = "Summary"
	template.control_scheme = "direct_rate"
	template.difficulty = "advanced"
	template.outputs["yaw"]["bindings"] = [
		{
			"source": "swing_yaw_deg",
			"mode": "delta",
			"range_min": -30.0,
			"range_max": 30.0,
			"weight": 1.0,
			"invert": true,
			"smoothing": 0.0,
			"curve": "linear",
		},
	]

	var summary := formatter.build_summary(template)
	var binding_lines: Array = summary.get("binding_lines", [])

	assert_eq(summary["control_scheme_label"], "Direct Rate")
	assert_eq(summary["difficulty_label"], "Advanced")
	assert_true(binding_lines[0].contains("change in left/right hand yaw swing"))
	assert_true(binding_lines[0].contains("[delta]"))
