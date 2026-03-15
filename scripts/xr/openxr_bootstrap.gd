class_name OpenXRBootstrap
extends RefCounted

const STATE_XR_STARTING := "xr_starting"
const STATE_XR_READY := "xr_ready"
const DEFAULT_MAXIMUM_REFRESH_RATE := 90.0

var _interface: Variant
var _viewport: Variant
var _passthrough_extension: Variant
var _diagnostics: Dictionary = _default_diagnostics()


func initialize(interface: Variant, viewport: Variant, passthrough_extension: Variant = null, maximum_refresh_rate: float = DEFAULT_MAXIMUM_REFRESH_RATE) -> Dictionary:
	_interface = interface
	_viewport = viewport
	_passthrough_extension = passthrough_extension if passthrough_extension != null else _resolve_passthrough_extension()
	_diagnostics = _default_diagnostics()
	_log_boot("XR_INIT_BEGIN", {
		"maximum_refresh_rate": maximum_refresh_rate,
	})

	if _interface == null:
		_diagnostics["error"] = "OpenXR interface missing"
		_log_error("XR_INIT_FAILED", {
			"reason": "interface_missing",
			"error": _diagnostics["error"],
		})
		return get_diagnostics()

	if not _interface.is_initialized():
		_log_info("XR_INTERFACE_INITIALIZE", {})
		var initialized: bool = bool(_interface.initialize())
		if not initialized:
			_diagnostics["error"] = "OpenXR failed to initialize"
			_log_error("XR_INIT_FAILED", {
				"reason": "initialize_returned_false",
				"error": _diagnostics["error"],
			})
			return get_diagnostics()

	if not _interface.is_initialized():
		_diagnostics["error"] = "OpenXR failed to initialize"
		_log_error("XR_INIT_FAILED", {
			"reason": "interface_not_initialized",
			"error": _diagnostics["error"],
		})
		return get_diagnostics()

	_viewport.use_xr = true
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)

	if RenderingServer.get_rendering_device():
		_viewport.vrs_mode = Viewport.VRS_XR
		_diagnostics["vrs_enabled"] = true
	_log_info("XR_VRS_STATE", {
		"enabled": bool(_diagnostics["vrs_enabled"]),
	})

	var modes: Array = _interface.get_supported_environment_blend_modes()
	_diagnostics["supported_environment_blend_modes"] = modes.duplicate()
	_diagnostics["alpha_blend_supported"] = XRInterface.XR_ENV_BLEND_MODE_ALPHA_BLEND in modes
	_diagnostics["passthrough_supported"] = _query_passthrough_supported()
	_diagnostics["passthrough_preferred"] = _query_passthrough_preferred()
	_log_info("XR_BLEND_MODES", {
		"supported_modes": modes.duplicate(),
		"alpha_blend_supported": bool(_diagnostics["alpha_blend_supported"]),
		"passthrough_supported": bool(_diagnostics["passthrough_supported"]),
		"passthrough_preferred": bool(_diagnostics["passthrough_preferred"]),
	})

	_configure_refresh_rate(maximum_refresh_rate)
	set_passthrough_enabled(
		bool(_diagnostics.get("alpha_blend_supported", false))
		and bool(_diagnostics.get("passthrough_supported", false))
		and bool(_diagnostics.get("passthrough_preferred", false))
	)

	_diagnostics["ok"] = true
	_diagnostics["state"] = STATE_XR_READY
	_log_boot("XR_INIT_OK", {
		"display_refresh_rate": float(_diagnostics.get("display_refresh_rate", 0.0)),
		"passthrough_enabled": bool(_diagnostics.get("passthrough_enabled", false)),
	})
	return get_diagnostics()


func set_passthrough_enabled(enabled: bool) -> Dictionary:
	if _interface == null or _viewport == null:
		return get_diagnostics()

	var allow_passthrough := enabled and bool(_diagnostics.get("alpha_blend_supported", false))
	allow_passthrough = allow_passthrough and bool(_diagnostics.get("passthrough_supported", false))

	_viewport.transparent_bg = allow_passthrough
	_interface.environment_blend_mode = XRInterface.XR_ENV_BLEND_MODE_ALPHA_BLEND if allow_passthrough else XRInterface.XR_ENV_BLEND_MODE_OPAQUE
	_diagnostics["passthrough_enabled"] = allow_passthrough
	_diagnostics["environment_blend_mode"] = int(_interface.environment_blend_mode)
	_log_info("XR_PASSTHROUGH_STATE", {
		"requested": enabled,
		"enabled": allow_passthrough,
		"environment_blend_mode": int(_diagnostics["environment_blend_mode"]),
	})
	return get_diagnostics()


func get_diagnostics() -> Dictionary:
	return _diagnostics.duplicate(true)


func _default_diagnostics() -> Dictionary:
	return {
		"state": STATE_XR_STARTING,
		"ok": false,
		"error": "",
		"alpha_blend_supported": false,
		"passthrough_supported": false,
		"passthrough_preferred": false,
		"passthrough_enabled": false,
		"render_model_plugin_available": ClassDB.class_exists("OpenXRFbRenderModel"),
		"passthrough_plugin_available": ClassDB.class_exists("OpenXRFbPassthroughGeometry"),
		"passthrough_extension_available": Engine.has_singleton("OpenXRFbPassthroughExtension"),
		"supported_environment_blend_modes": [],
		"environment_blend_mode": XRInterface.XR_ENV_BLEND_MODE_OPAQUE,
		"display_refresh_rate": 0.0,
		"target_refresh_rate": 0.0,
		"physics_ticks_per_second": 0,
		"vrs_enabled": false,
	}


func _resolve_passthrough_extension() -> Variant:
	if Engine.has_singleton("OpenXRFbPassthroughExtension"):
		return Engine.get_singleton("OpenXRFbPassthroughExtension")
	return null


func _query_passthrough_supported() -> bool:
	if _passthrough_extension != null and _passthrough_extension.has_method("is_passthrough_supported"):
		return bool(_passthrough_extension.is_passthrough_supported())
	return bool(_diagnostics.get("alpha_blend_supported", false))


func _query_passthrough_preferred() -> bool:
	if _passthrough_extension != null and _passthrough_extension.has_method("is_passthrough_preferred"):
		return bool(_passthrough_extension.is_passthrough_preferred())
	return bool(_diagnostics.get("alpha_blend_supported", false))


func _configure_refresh_rate(maximum_refresh_rate: float) -> void:
	if _interface == null:
		return

	var current_refresh_rate := 0.0
	if _interface.has_method("get_display_refresh_rate"):
		current_refresh_rate = float(_interface.get_display_refresh_rate())

	var target_refresh_rate := current_refresh_rate
	var available_rates: Array = []
	if _interface.has_method("get_available_display_refresh_rates"):
		available_rates = _interface.get_available_display_refresh_rates()

	if available_rates.size() == 1:
		target_refresh_rate = float(available_rates[0])
	elif available_rates.size() > 1:
		for rate in available_rates:
			var candidate := float(rate)
			if candidate > target_refresh_rate and candidate <= maximum_refresh_rate:
				target_refresh_rate = candidate

	if current_refresh_rate != target_refresh_rate and target_refresh_rate > 0.0 and _interface.has_method("set_display_refresh_rate"):
		_interface.set_display_refresh_rate(target_refresh_rate)
		current_refresh_rate = target_refresh_rate

	if current_refresh_rate > 0.0:
		Engine.physics_ticks_per_second = maxi(1, int(round(current_refresh_rate)))

	_diagnostics["display_refresh_rate"] = current_refresh_rate
	_diagnostics["target_refresh_rate"] = target_refresh_rate
	_diagnostics["physics_ticks_per_second"] = Engine.physics_ticks_per_second
	_log_info("XR_REFRESH_RATE_CONFIGURED", {
		"display_refresh_rate": current_refresh_rate,
		"target_refresh_rate": target_refresh_rate,
		"physics_ticks_per_second": Engine.physics_ticks_per_second,
	})


func _log_boot(phase: String, fields: Dictionary = {}) -> void:
	var logger := _get_logger()
	if logger != null:
		logger.boot(phase, fields)


func _log_info(event: String, fields: Dictionary = {}) -> void:
	var logger := _get_logger()
	if logger != null:
		logger.info(event, fields)


func _log_error(event: String, fields: Dictionary = {}) -> void:
	var logger := _get_logger()
	if logger != null:
		logger.error(event, fields)


func _get_logger() -> Node:
	var main_loop: MainLoop = Engine.get_main_loop()
	if main_loop == null or not (main_loop is SceneTree):
		return null
	return (main_loop as SceneTree).root.get_node_or_null("QuestRuntimeLog")
