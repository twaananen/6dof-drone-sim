extends "res://addons/gut/test.gd"


func before_each() -> void:
	_logger().clear_entries()


func test_repro_panel_scene_instantiates_real_quest_panel_in_composition_layer() -> void:
	var scene: PackedScene = load("res://scenes/repro/quest_composition_layer_repro_panel.tscn")
	assert_not_null(scene)

	var repro := scene.instantiate()
	add_child_autofree(repro)
	await wait_process_frames(1)

	assert_not_null(repro.get_node("XROrigin3D/CompositionLayerQuad/SubViewport/QuestPanel/Panel/Margin/Scroll/VBox/RunLabelEdit"))
	assert_not_null(repro.get_node("XROrigin3D/CompositionLayerQuad/SubViewport/QuestPanel/Panel/Margin/Scroll/VBox/PassthroughToggle"))
	assert_true(_has_boot_phase("REPRO_READY_BEGIN"))
	assert_true(_has_boot_phase("REPRO_UI_LAYER_READY"))


func _has_boot_phase(phase_name: String) -> bool:
	for entry in _logger().get_entries():
		if str(entry.get("event", "")) == "BOOT" and str(entry.get("phase", "")) == phase_name:
			return true
	return false


func _logger() -> Node:
	return get_tree().root.get_node("QuestRuntimeLog")
