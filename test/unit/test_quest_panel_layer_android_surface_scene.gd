extends "res://addons/gut/test.gd"


func before_each() -> void:
	_logger().clear_entries()


func test_android_surface_panel_layer_scene_instantiates_hidden_panel_root() -> void:
	var scene: PackedScene = load("res://scenes/shared/quest_panel_layer_android_surface.tscn")
	assert_not_null(scene)

	var panel_layer := scene.instantiate()
	add_child_autofree(panel_layer)
	await wait_process_frames(1)

	assert_true(panel_layer.use_android_surface)
	assert_not_null(panel_layer.get_node("SubViewport"))
	assert_not_null(panel_layer.call("get_scene_root"))
	assert_not_null(panel_layer.get_node("SubViewport/QuestPanel/Panel/Margin/Scroll/VBox/RunLabelEdit"))
	assert_true(_has_boot_phase("UI_LAYER_READY"))
	assert_true(_has_event("UI_LAYER_VIEWPORT_ATTACHED"))
	assert_true(_has_event("UI_LAYER_SCENE_ATTACHED"))


func _has_boot_phase(phase_name: String) -> bool:
	for entry in _logger().get_entries():
		if str(entry.get("event", "")) == "BOOT" and str(entry.get("phase", "")) == phase_name:
			return true
	return false


func _has_event(event_name: String) -> bool:
	for entry in _logger().get_entries():
		if str(entry.get("event", "")) == event_name:
			return true
	return false


func _logger() -> Node:
	return get_tree().root.get_node("QuestRuntimeLog")
