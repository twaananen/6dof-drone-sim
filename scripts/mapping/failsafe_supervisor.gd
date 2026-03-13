class_name FailsafeSupervisor
extends RefCounted

var timeout_usec: int = 200000
var _last_valid_timestamp_usec: int = -1
var _active: bool = true


func note_state(state: Dictionary) -> void:
    if not state.get("tracking_valid", false):
        return
    _last_valid_timestamp_usec = int(state.get("timestamp_usec", 0))
    _active = false


func update(now_timestamp_usec: int) -> bool:
    if _last_valid_timestamp_usec < 0:
        _active = true
        return _active
    _active = (now_timestamp_usec - _last_valid_timestamp_usec) > timeout_usec
    return _active


func force_trip() -> void:
    _active = true


func clear() -> void:
    _active = false


func is_active() -> bool:
    return _active


func neutralize(outputs: Dictionary) -> Dictionary:
    var neutral: Dictionary = outputs.duplicate()
    for key in neutral.keys():
        neutral[key] = 0.0
    return neutral
