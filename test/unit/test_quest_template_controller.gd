extends "res://addons/gut/test.gd"

const QuestTemplateController = preload("res://scripts/quest/quest_template_controller.gd")
const MappingTemplate = preload("res://scripts/mapping/mapping_template.gd")
const TemplateSummaryFormatter = preload("res://scripts/mapping/template_summary_formatter.gd")


func test_template_controller_syncs_surfaces_and_preserves_library_browsing_selection() -> void:
	var flight_panel: Control = load("res://scenes/quest_flight_panel.tscn").instantiate()
	var library_panel: Control = load("res://scenes/shared/template_library_panel.tscn").instantiate()
	var guide_panel: Control = load("res://scenes/shared/template_guide_panel.tscn").instantiate()
	var editor_panel: Control = load("res://scenes/shared/template_structured_editor.tscn").instantiate()
	var controller := QuestTemplateController.new()
	add_child_autofree(flight_panel)
	add_child_autofree(library_panel)
	add_child_autofree(guide_panel)
	add_child_autofree(editor_panel)
	add_child_autofree(controller)
	assert_true(controller.configure(flight_panel, library_panel, guide_panel, editor_panel))

	var active := MappingTemplate.new()
	active.template_id = "bundled.attitude_tilt"
	active.display_name = "Attitude Tilt"
	active.summary = "Active"
	var other := MappingTemplate.new()
	other.template_id = "bundled.rate_direct"
	other.display_name = "Rate Direct"
	other.summary = "Other"
	var active_summary := TemplateSummaryFormatter.new().build_summary(active)
	var other_summary := TemplateSummaryFormatter.new().build_summary(other)

	controller.apply_template_catalog([active_summary, other_summary])
	controller.apply_active_template(active.template_id, active_summary, active.to_dict())
	assert_eq(controller.template_summary_label.text, "Active")
	assert_eq(controller.template_library_panel.list.item_count, 2)

	controller.template_library_panel.set_selected_template_id(other.template_id)
	controller.apply_status_template_fallback({
		"template_id": active.template_id,
		"template_summary": active_summary,
		"template": active.to_dict(),
	})

	var selected_items: PackedInt32Array = controller.template_library_panel.list.get_selected_items()
	assert_eq(selected_items.size(), 1)
	assert_eq(str(controller.template_library_panel.list.get_item_metadata(selected_items[0])), other.template_id)


func test_template_controller_emits_apply_tuning_messages() -> void:
	var flight_panel: Control = load("res://scenes/quest_flight_panel.tscn").instantiate()
	var controller := QuestTemplateController.new()
	add_child_autofree(flight_panel)
	add_child_autofree(controller)
	assert_true(controller.configure(flight_panel, null, null, null))

	var messages: Array = []
	controller.control_message_requested.connect(func(message: Dictionary): messages.append(message))
	controller.sensitivity_slider.value = 1.25
	controller.deadzone_slider.value = 0.1
	controller.expo_slider.value = 0.2
	controller.integrator_slider.value = 0.3
	controller._on_tuning_changed(0.0)

	assert_gt(messages.size(), 0)
	assert_eq(messages[messages.size() - 1]["type"], "apply_tuning")
