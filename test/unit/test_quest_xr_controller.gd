extends "res://addons/gut/test.gd"

const QuestXrController = preload("res://scripts/quest/quest_xr_controller.gd")


func test_xr_controller_syncs_passthrough_toggle_and_hides_fallback_visuals() -> void:
	var controller := QuestXrController.new()
	var world_environment := WorldEnvironment.new()
	var viewport := SubViewport.new()
	var left_hand := XRController3D.new()
	var right_hand := XRController3D.new()
	var left_fallback := MeshInstance3D.new()
	var right_fallback := MeshInstance3D.new()
	var left_render := Node3D.new()
	var right_render := Node3D.new()
	var toggle := CheckButton.new()
	left_render.name = "ControllerRenderModel"
	right_render.name = "ControllerRenderModel"
	left_render.visible = true
	right_render.visible = true
	left_fallback.visible = true
	right_fallback.visible = true
	left_hand.add_child(left_render)
	right_hand.add_child(right_render)
	add_child_autofree(world_environment)
	add_child_autofree(viewport)
	add_child_autofree(left_hand)
	add_child_autofree(right_hand)
	left_hand.add_child(left_fallback)
	right_hand.add_child(right_fallback)
	add_child_autofree(toggle)
	add_child_autofree(controller)
	controller.configure(world_environment, viewport, left_hand, right_hand, left_fallback, right_fallback, toggle)

	controller._xr_diagnostics = {
		"passthrough_enabled": true,
		"alpha_blend_supported": false,
	}
	controller.sync_passthrough_toggle()
	assert_true(toggle.button_pressed)
	assert_true(toggle.disabled)

	controller._update_controller_visuals()
	assert_false(left_fallback.visible)
	assert_false(right_fallback.visible)
	assert_false(left_render.visible)
	assert_false(right_render.visible)
