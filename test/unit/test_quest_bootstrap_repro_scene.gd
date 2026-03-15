extends "res://addons/gut/test.gd"


func before_each() -> void:
	_logger().clear_entries()


func test_quest_bootstrap_repro_scene_runs_bootstrap_against_real_panel() -> void:
	var scene: PackedScene = load("res://scenes/repro/quest_bootstrap_repro.tscn")
	assert_not_null(scene)

	var repro := scene.instantiate()
	add_child_autofree(repro)
	await wait_process_frames(1)

	assert_not_null(repro.get_node("XROrigin3D/QuestUiLayer/SubViewport/QuestPanel/Panel/Margin/Scroll/VBox/StatusLabel"))
	assert_true(_has_boot_phase("BOOTSTRAP_REPRO_READY_BEGIN"))
	assert_true(_has_boot_phase("BOOTSTRAP_REPRO_UI_BIND_OK"))
	assert_true(_has_boot_phase("BOOTSTRAP_REPRO_READY_COMPLETE"))


func _has_boot_phase(phase_name: String) -> bool:
	for entry in _logger().get_entries():
		if str(entry.get("event", "")) == "BOOT" and str(entry.get("phase", "")) == phase_name:
			return true
	return false


func _logger() -> Node:
	return get_tree().root.get_node("QuestRuntimeLog")
