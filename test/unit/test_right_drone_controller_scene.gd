extends "res://addons/gut/test.gd"


func test_right_drone_controller_scene_has_clear_forward_and_up_markers() -> void:
	var scene: PackedScene = load("res://scenes/shared/right_drone_controller.tscn")
	assert_not_null(scene)

	var drone := scene.instantiate()
	add_child_autofree(drone)

	assert_not_null(drone.get_node("FrontArrow"))
	assert_not_null(drone.get_node("TopFin"))
	assert_not_null(drone.get_node("TopStripe"))

	var front_left := drone.get_node("RotorFL") as MeshInstance3D
	var rear_left := drone.get_node("RotorRL") as MeshInstance3D
	assert_not_null(front_left)
	assert_not_null(rear_left)
	assert_ne(front_left.get_surface_override_material(0).get_rid(), rear_left.get_surface_override_material(0).get_rid())
