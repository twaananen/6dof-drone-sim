class_name FailsafeSupervisor
extends RefCounted

var timeout_usec: int = 200000
var _last_valid_local_usec: int = -1
var _active: bool = true


func note_state(state: Dictionary, now_usec: int = -1) -> void:
	if not state.get("tracking_valid", false):
		return
	_last_valid_local_usec = _resolve_now_usec(now_usec)


func update(now_usec: int = -1) -> bool:
	if _last_valid_local_usec < 0:
		_active = true
		return _active
	_active = (_resolve_now_usec(now_usec) - _last_valid_local_usec) > timeout_usec
	return _active


func force_trip() -> void:
	_active = true


func clear() -> void:
	_active = false


func is_active() -> bool:
	return _active


func _resolve_now_usec(now_usec: int) -> int:
	if now_usec >= 0:
		return now_usec
	return Time.get_ticks_usec()
