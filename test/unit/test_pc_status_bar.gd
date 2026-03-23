extends "res://addons/gut/test.gd"


func test_status_bar_surfaces_shell_summary_states() -> void:
	var scene: PackedScene = load("res://scenes/shared/pc_status_bar.tscn")
	assert_not_null(scene)

	var bar = scene.instantiate()
	add_child_autofree(bar)
	await wait_process_frames(1)
	bar.set_status({
		"template_name": "Attitude Tilt",
		"workflow_label": "Passthrough Baseline / Passthrough Standalone",
		"connected": false,
		"backend_available": false,
		"packets_received": 14,
		"packets_dropped": 2,
		"failsafe_active": true,
	})

	assert_true((bar.get_node("Margin/HBox/ConnectionCard/ConnectionLabel") as Label).text.contains("Disconnected"))
	assert_true((bar.get_node("Margin/HBox/BackendCard/BackendLabel") as Label).text.contains("Offline"))
	assert_true((bar.get_node("Margin/HBox/PacketsCard/PacketsLabel") as Label).text.contains("14 / 2 dropped"))
	assert_true((bar.get_node("Margin/HBox/FailsafeCard/FailsafeLabel") as Label).text.contains("Active"))
	assert_true((bar.get_node("Margin/HBox/TemplateCard/TemplateLabel") as Label).text.contains("Attitude Tilt"))
