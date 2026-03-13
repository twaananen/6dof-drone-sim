class_name FailsafeSupervisor
extends RefCounted

var timeout_usec: int = 200000
var _last_valid_local_usec: int = -1
var _active: bool = true


func note_state(state: Dictionary) -> void:
	if not state.get("tracking_valid", false):
		return
	_last_valid_local_usec = Time.get_ticks_usec()


func update() -> bool:
	if _last_valid_local_usec < 0:
		_active = true
		return _active
	_active = (Time.get_ticks_usec() - _last_valid_local_usec) > timeout_usec
	return _active


func force_trip() -> void:
	_active = true


func clear() -> void:
	_active = false


func is_active() -> bool:
	return _active
