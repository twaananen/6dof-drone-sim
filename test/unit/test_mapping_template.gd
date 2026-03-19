extends "res://addons/gut/test.gd"

const MappingTemplate = preload("res://scripts/mapping/mapping_template.gd")


func test_defaults_and_roundtrip() -> void:
	var template := MappingTemplate.new()
	assert_has(template.outputs, "throttle")
	template.template_id = "user.TEST"
	template.slug = "demo"
	template.display_name = "Demo"
	template.summary = "Demo summary"
	template.add_binding("pitch", MappingTemplate.default_binding("pose_pitch_deg", "absolute"))

	var copy := MappingTemplate.new()
	copy.from_dict(template.to_dict())

	assert_eq(copy.template_id, "user.TEST")
	assert_eq(copy.display_name, "Demo")
	assert_eq(copy.summary, "Demo summary")
	assert_eq(copy.outputs["pitch"]["bindings"].size(), 1)


func test_copy_as_user_template_keeps_lineage_and_clears_id() -> void:
	var template := MappingTemplate.new()
	template.template_id = "bundled.demo"
	template.slug = "demo"
	template.display_name = "Demo"

	var copied := template.copy_as_user_template()

	assert_eq(copied.origin, "user")
	assert_eq(copied.source_template_id, "bundled.demo")
	assert_eq(copied.template_id, "")
	assert_eq(copied.display_name, "Demo")


func test_with_global_tuning_returns_independent_copy() -> void:
	var template := MappingTemplate.new()
	template.template_id = "user.demo"
	template.outputs["roll"]["sensitivity"] = 1.0
	template.outputs["roll"]["deadzone"] = 0.05
	template.outputs["roll"]["expo"] = 0.1
	template.outputs["roll"]["bindings"] = [
		MappingTemplate.default_binding("pose_roll_deg", "integrator"),
		MappingTemplate.default_binding("pose_yaw_deg", "absolute"),
	]

	var tuned := template.with_global_tuning({
		"sensitivity": 2.0,
		"deadzone": 0.2,
		"expo": 0.6,
		"integrator_gain": 1.5,
	})

	assert_eq(tuned.template_id, "user.demo")
	assert_eq(template.outputs["roll"]["sensitivity"], 1.0)
	assert_eq(template.outputs["roll"]["deadzone"], 0.05)
	assert_eq(template.outputs["roll"]["expo"], 0.1)
	assert_eq(template.outputs["roll"]["bindings"][0]["weight"], 1.0)
	assert_eq(template.outputs["roll"]["bindings"][1]["weight"], 1.0)
	assert_eq(tuned.outputs["roll"]["sensitivity"], 2.0)
	assert_eq(tuned.outputs["roll"]["deadzone"], 0.2)
	assert_eq(tuned.outputs["roll"]["expo"], 0.6)
	assert_eq(tuned.outputs["roll"]["bindings"][0]["weight"], 1.5)
	assert_eq(tuned.outputs["roll"]["bindings"][1]["weight"], 1.0)
