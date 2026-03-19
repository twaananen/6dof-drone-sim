extends "res://addons/gut/test.gd"

const QuestPanelController = preload("res://scripts/quest/quest_panel_controller.gd")


func test_panel_controller_toggles_panels_and_tutorial_visibility() -> void:
	var controller := QuestPanelController.new()
	var camera := XRCamera3D.new()
	var flight_panel := Node3D.new()
	var tutorial_panel := Node3D.new()
	var connection_panel := Node3D.new()
	var recenter_button := Button.new()
	var show_tutorial_button := Button.new()
	var hide_tutorial_button := Button.new()
	var show_connection_button := Button.new()
	add_child_autofree(camera)
	add_child_autofree(flight_panel)
	add_child_autofree(tutorial_panel)
	add_child_autofree(connection_panel)
	add_child_autofree(recenter_button)
	add_child_autofree(show_tutorial_button)
	add_child_autofree(hide_tutorial_button)
	add_child_autofree(show_connection_button)
	add_child_autofree(controller)
	flight_panel.position = Vector3(0.0, 0.0, -1.0)
	tutorial_panel.position = Vector3(0.5, 0.0, -1.0)
	connection_panel.position = Vector3(-0.5, 0.0, -1.0)
	tutorial_panel.visible = false
	controller.configure(
		camera,
		tutorial_panel,
		{
			"flight": flight_panel,
			"tutorial": tutorial_panel,
			"connection": connection_panel,
		},
		recenter_button,
		show_tutorial_button,
		hide_tutorial_button,
		{"connection": show_connection_button}
	)

	assert_false(controller.is_tutorial_visible())
	controller.show_tutorial()
	assert_true(controller.is_tutorial_visible())
	assert_true(show_tutorial_button.disabled)

	connection_panel.visible = false
	controller.toggle_panel("connection")
	assert_true(connection_panel.visible)
