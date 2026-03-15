extends "res://addons/gut/test.gd"


func before_each() -> void:
	_logger().clear_entries()


func test_logger_formats_single_line_prefixed_json() -> void:
	var logger := _logger()
	logger.info("TEST_EVENT", {
		"value": 7,
	})

	var entries: Array = logger.get_entries()
	assert_eq(entries.size(), 1)
	assert_eq(entries[0]["event"], "TEST_EVENT")
	assert_eq(entries[0]["fields"]["value"], 7)

	var line: String = logger.format_entry(entries[0])
	assert_true(line.begins_with("QUEST_LOG "))
	assert_eq(line.count("\n"), 0)

	var payload: Variant = JSON.parse_string(line.trim_prefix("QUEST_LOG "))
	assert_typeof(payload, TYPE_DICTIONARY)
	assert_eq(payload["event"], "TEST_EVENT")
	assert_eq(int(payload["fields"]["value"]), 7)


func test_logger_handles_empty_fields() -> void:
	var logger := _logger()
	logger.boot("READY_BEGIN")

	var entries: Array = logger.get_entries()
	assert_eq(entries.size(), 1)
	assert_eq(entries[0]["event"], "BOOT")
	assert_eq(entries[0]["phase"], "READY_BEGIN")
	assert_eq(entries[0]["fields"], {})


func _logger() -> Node:
	return get_tree().root.get_node("QuestRuntimeLog")
