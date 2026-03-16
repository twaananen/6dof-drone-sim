extends "res://addons/gut/test.gd"

const MappingEngine = preload("res://scripts/mapping/mapping_engine.gd")
const MappingTemplate = preload("res://scripts/mapping/mapping_template.gd")


func test_absolute_binding_normalizes() -> void:
    var template := MappingTemplate.new()
    var binding := MappingTemplate.default_binding("trigger", "absolute")
    binding["range_min"] = 0.0
    binding["range_max"] = 1.0
    template.add_binding("throttle", binding)

    var engine := MappingEngine.new()
    engine.set_template(template)
    var outputs := engine.process({"trigger": 0.5}, 1.0 / 90.0)
    assert_almost_eq(outputs["throttle"], 0.0, 0.001)


func test_delta_binding_uses_change() -> void:
    var template := MappingTemplate.new()
    var binding := MappingTemplate.default_binding("pose_yaw_deg", "delta")
    binding["range_min"] = -90.0
    binding["range_max"] = 90.0
    template.add_binding("yaw", binding)

    var engine := MappingEngine.new()
    engine.set_template(template)
    engine.process({"pose_yaw_deg": 0.0}, 1.0 / 90.0)
    var outputs := engine.process({"pose_yaw_deg": 45.0}, 1.0 / 90.0)
    assert_gt(outputs["yaw"], 0.0)


func test_integrator_holds_state_until_reset() -> void:
    var template := MappingTemplate.new()
    var binding := MappingTemplate.default_binding("pose_roll_deg", "integrator")
    binding["range_min"] = -45.0
    binding["range_max"] = 45.0
    binding["weight"] = 1.0
    template.add_binding("roll", binding)

    var engine := MappingEngine.new()
    engine.set_template(template)
    engine.process({"pose_roll_deg": 0.0}, 1.0 / 90.0)
    engine.process({"pose_roll_deg": 30.0}, 1.0 / 90.0)
    var held := engine.process({"pose_roll_deg": 30.0}, 1.0 / 90.0)
    assert_gt(held["roll"], 0.0)

    engine.clear_integrators()
    var reset := engine.process({"pose_roll_deg": 30.0}, 1.0 / 90.0)
    assert_lt(reset["roll"], held["roll"])


func test_button_binding_maps_to_aux_button_output() -> void:
    var template := MappingTemplate.new()
    var binding := MappingTemplate.default_binding("button_south", "absolute")
    binding["range_min"] = 0.0
    binding["range_max"] = 1.0
    template.add_binding("aux_button_1", binding)

    var engine := MappingEngine.new()
    engine.set_template(template)

    var pressed := engine.process({"button_south": 1.0}, 1.0 / 90.0)
    var released := engine.process({"button_south": 0.0}, 1.0 / 90.0)

    assert_eq(pressed["aux_button_1"], 1.0)
    assert_eq(released["aux_button_1"], 0.0)
