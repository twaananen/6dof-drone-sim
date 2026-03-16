extends "res://addons/gut/test.gd"


func test_panel_surfaces_quest_input_debug_fields() -> void:
	var scene: PackedScene = load("res://scenes/shared/quest_status_panel.tscn")
	assert_not_null(scene)

	var panel := scene.instantiate()
	add_child_autofree(panel)
	panel.set_status({
		"connected": true,
		"control_active": false,
		"failsafe_active": false,
		"backend_available": true,
		"last_outputs": {
			"throttle": 0.0,
			"yaw": 0.0,
			"pitch": 0.0,
			"roll": 0.0,
			"aux_button_1": 1.0,
		},
		"quest_runtime_diagnostics": {
			"xr_state": "running",
			"discovery_state": "connected",
			"control_active": true,
			"tracking_valid": true,
			"right_grip_value": 0.82,
			"right_trigger_value": 0.31,
			"right_buttons_hex": "0x0001",
			"right_button_south_pressed": true,
			"right_thumbstick_x": 0.25,
			"right_thumbstick_y": -0.5,
			"last_origin_event": "set",
		},
	})

	var payload := panel.get_node("VBox/Payload") as Label
	assert_true(payload.text.contains("Quest Input: tracking ok | grip 0.82 | trigger 0.31"))
	assert_true(payload.text.contains("Quest Buttons: 0x0001 | A down | Stick 0.25, -0.50"))
	assert_true(payload.text.contains("Quest Origin Event: set"))
	assert_true(payload.text.contains("Outputs: T 0.00 | Y 0.00 | P 0.00 | R 0.00 | AUX1 1"))
