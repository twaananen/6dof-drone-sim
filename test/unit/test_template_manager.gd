extends "res://addons/gut/test.gd"

const TemplateManager = preload("res://scripts/ui/template_manager.gd")


func test_create_blank_and_copy_assign_user_identity() -> void:
	var manager := TemplateManager.new()

	var blank := manager.create_blank_template("My Test Template")
	assert_true(blank.template_id.begins_with("user."))
	assert_eq(blank.origin, "user")
	assert_eq(blank.display_name, "My Test Template")
	assert_true(blank.slug.begins_with("my_test_template"))

	var copied := manager.copy_to_user_template("bundled.rate_direct")
	assert_not_null(copied)
	assert_true(copied.template_id.begins_with("user."))
	assert_eq(copied.origin, "user")
	assert_eq(copied.source_template_id, "bundled.rate_direct")
	assert_string_contains(copied.display_name, "Copy")
