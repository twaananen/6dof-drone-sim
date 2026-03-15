extends Node3D

const DEFAULT_MAXIMUM_REFRESH_RATE := 90.0

@export var maximum_refresh_rate := DEFAULT_MAXIMUM_REFRESH_RATE

var _xr_interface: OpenXRInterface


func _ready() -> void:
	QuestRuntimeLog.boot("REPRO_READY_BEGIN", {
		"scene": "quest_composition_layer_repro",
	})

	_xr_interface = XRServer.find_interface("OpenXR") as OpenXRInterface
	if _xr_interface == null:
		QuestRuntimeLog.error("REPRO_XR_INIT_FAILED", {
			"reason": "interface_missing",
		})
		return

	if not _xr_interface.is_initialized() and not _xr_interface.initialize():
		QuestRuntimeLog.error("REPRO_XR_INIT_FAILED", {
			"reason": "initialize_returned_false",
		})
		return

	var viewport := get_viewport()
	viewport.use_xr = true
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	if RenderingServer.get_rendering_device():
		viewport.vrs_mode = Viewport.VRS_XR

	if not _xr_interface.session_begun.is_connected(_on_openxr_session_begun):
		_xr_interface.session_begun.connect(_on_openxr_session_begun)

	QuestRuntimeLog.boot("REPRO_XR_READY", {
		"use_xr": viewport.use_xr,
	})


func _on_openxr_session_begun() -> void:
	var current_refresh_rate := 0.0
	if _xr_interface.has_method("get_display_refresh_rate"):
		current_refresh_rate = float(_xr_interface.get_display_refresh_rate())

	var target_refresh_rate := current_refresh_rate
	var available_rates: Array = []
	if _xr_interface.has_method("get_available_display_refresh_rates"):
		available_rates = _xr_interface.get_available_display_refresh_rates()

	for rate in available_rates:
		var candidate := float(rate)
		if candidate > target_refresh_rate and candidate <= maximum_refresh_rate:
			target_refresh_rate = candidate

	if target_refresh_rate > 0.0 and current_refresh_rate != target_refresh_rate and _xr_interface.has_method("set_display_refresh_rate"):
		_xr_interface.set_display_refresh_rate(target_refresh_rate)
		current_refresh_rate = target_refresh_rate

	if current_refresh_rate > 0.0:
		Engine.physics_ticks_per_second = maxi(1, int(round(current_refresh_rate)))

	QuestRuntimeLog.info("REPRO_XR_SESSION_BEGUN", {
		"display_refresh_rate": current_refresh_rate,
		"physics_ticks_per_second": Engine.physics_ticks_per_second,
	})
