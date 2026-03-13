extends "res://addons/gut/test.gd"

const MappingTemplate = preload("res://scripts/mapping/mapping_template.gd")


func test_defaults_and_roundtrip() -> void:
    var template := MappingTemplate.new()
    assert_has(template.outputs, "throttle")
    template.template_name = "demo"
    template.add_binding("pitch", MappingTemplate.default_binding("pose_pitch_deg", "absolute"))

    var copy := MappingTemplate.new()
    copy.from_dict(template.to_dict())

    assert_eq(copy.template_name, "demo")
    assert_eq(copy.outputs["pitch"]["bindings"].size(), 1)
