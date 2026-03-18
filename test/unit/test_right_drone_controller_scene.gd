extends "res://addons/gut/test.gd"


func test_right_drone_controller_scene_loads_imported_model() -> void:
	var scene: PackedScene = load("res://scenes/shared/right_drone_controller.tscn")
	assert_not_null(scene)

	var drone := scene.instantiate()
	add_child_autofree(drone)

	var model := drone.get_node_or_null("Model")
	assert_not_null(model, "Imported glTF model node should exist")
