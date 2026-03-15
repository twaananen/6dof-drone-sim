extends Node

const LOG_PREFIX := "QUEST_LOG"
const EVENT_BOOT := "BOOT"
const MAX_BUFFERED_ENTRIES := 256

var _entries: Array[Dictionary] = []


func info(event: String, fields: Dictionary = {}) -> void:
	_emit("INFO", event, fields)


func warn(event: String, fields: Dictionary = {}) -> void:
	_emit("WARN", event, fields)


func error(event: String, fields: Dictionary = {}) -> void:
	_emit("ERROR", event, fields)


func boot(phase: String, fields: Dictionary = {}) -> void:
	_emit("INFO", EVENT_BOOT, fields, phase)


func clear_entries() -> void:
	_entries.clear()


func get_entries() -> Array[Dictionary]:
	return _entries.duplicate(true)


func format_entry(entry: Dictionary) -> String:
	return "%s %s" % [LOG_PREFIX, JSON.stringify(entry)]


func _emit(level: String, event: String, fields: Dictionary, phase: String = "") -> void:
	var entry := _build_entry(level, event, fields, phase)
	_entries.append(entry)
	while _entries.size() > MAX_BUFFERED_ENTRIES:
		_entries.pop_front()
	print(format_entry(entry))


func _build_entry(level: String, event: String, fields: Dictionary, phase: String = "") -> Dictionary:
	var entry: Dictionary = {
		"level": level,
		"event": event,
		"ts_msec": Time.get_ticks_msec(),
		"fields": fields.duplicate(true),
	}
	if not phase.is_empty():
		entry["phase"] = phase
	return entry
