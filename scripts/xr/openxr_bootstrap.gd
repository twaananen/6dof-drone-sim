class_name OpenXRBootstrap
extends RefCounted

const STATE_XR_STARTING := "xr_starting"
const STATE_XR_READY := "xr_ready"
const DEFAULT_MAXIMUM_REFRESH_RATE := 90.0
const PRESENTATION_MODE_OPAQUE := "opaque"
const PRESENTATION_MODE_PASSTHROUGH := "passthrough"
const PASSTHROUGH_STATE_EVENT_STARTING := "starting"
const PASSTHROUGH_STATE_EVENT_STARTED := "started"
const PASSTHROUGH_STATE_EVENT_STOPPED := "stopped"
const PASSTHROUGH_FALLBACK_REASON_NOT_REQUESTED := ""
const PASSTHROUGH_FALLBACK_REASON_NOT_SUPPORTED := "passthrough_not_supported"
const PASSTHROUGH_FALLBACK_REASON_BLEND_MODE_REJECTED := "blend_mode_rejected"
const PASSTHROUGH_FALLBACK_REASON_NOT_STARTED := "passthrough_not_started"
const PASSTHROUGH_FALLBACK_REASON_STATE_STOPPED := "passthrough_state_stopped"
const PASSTHROUGH_START_VALIDATION_DELAY_SEC := 0.25

var _interface: Variant
var _viewport: Variant
var _passthrough_extension: Variant
var _diagnostics: Dictionary = _default_diagnostics()
var _maximum_refresh_rate: float = DEFAULT_MAXIMUM_REFRESH_RATE
var _runtime_settings_applied := false
var _world_environment: WorldEnvironment
var _opaque_background_mode: int = Environment.BG_SKY
var _opaque_background_color: Color = Color.BLACK
var _passthrough_state_connected := false
var _passthrough_validation_ticket := 0

var prefer_passthrough_on_startup := false
var fallback_to_opaque_on_passthrough_failure := true


var world_environment: WorldEnvironment:
	set(new_world_environment):
		_world_environment = new_world_environment
		_capture_world_environment_defaults()
	get:
		return _world_environment


func initialize(interface: Variant, viewport: Variant, passthrough_extension: Variant = null, maximum_refresh_rate: float = DEFAULT_MAXIMUM_REFRESH_RATE) -> Dictionary:
	_interface = interface
	_viewport = viewport
	_passthrough_extension = passthrough_extension if passthrough_extension != null else _resolve_passthrough_extension()
	_maximum_refresh_rate = maximum_refresh_rate
	_diagnostics = _default_diagnostics()
	_runtime_settings_applied = false
	_passthrough_state_connected = false
	_passthrough_validation_ticket = 0
	_capture_world_environment_defaults()
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
	_apply_opaque_baseline("initialize")

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
	_connect_passthrough_signals()
	_connect_session_begun()

	_diagnostics["ok"] = true
	_diagnostics["state"] = STATE_XR_READY
	_log_boot("XR_INIT_OK", {
		"display_refresh_rate": float(_diagnostics.get("display_refresh_rate", 0.0)),
		"passthrough_enabled": bool(_diagnostics.get("passthrough_enabled", false)),
	})
	return get_diagnostics()


func on_session_begun() -> Dictionary:
	if _runtime_settings_applied:
		return get_diagnostics()
	_runtime_settings_applied = true

	_configure_refresh_rate(_maximum_refresh_rate)
	if prefer_passthrough_on_startup \
		and bool(_diagnostics.get("passthrough_preferred", false)):
		set_passthrough_enabled(true)
	return get_diagnostics()


func set_passthrough_enabled(enabled: bool) -> Dictionary:
	if _interface == null or _viewport == null:
		return get_diagnostics()

	_diagnostics["xr_requested_mode"] = PRESENTATION_MODE_PASSTHROUGH if enabled else PRESENTATION_MODE_OPAQUE
	if enabled:
		_request_passthrough("toggle")
	else:
		_apply_opaque_baseline("toggle")
	_diagnostics["environment_blend_mode"] = _get_current_environment_blend_mode()
	_log_info("XR_PASSTHROUGH_STATE", {
		"requested": enabled,
		"enabled": bool(_diagnostics.get("passthrough_enabled", false)),
		"environment_blend_mode": int(_diagnostics["environment_blend_mode"]),
		"active_mode": str(_diagnostics.get("xr_active_mode", PRESENTATION_MODE_OPAQUE)),
		"fallback_reason": str(_diagnostics.get("xr_passthrough_fallback_reason", "")),
	})
	return get_diagnostics()


func _connect_session_begun() -> void:
	if _interface == null or not _interface.has_signal("session_begun"):
		return
	if _interface.session_begun.is_connected(_on_openxr_session_begun):
		return
	_interface.session_begun.connect(_on_openxr_session_begun)


func _on_openxr_session_begun() -> void:
	on_session_begun()


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
		"xr_requested_mode": PRESENTATION_MODE_OPAQUE,
		"xr_active_mode": PRESENTATION_MODE_OPAQUE,
		"xr_passthrough_started": false,
		"xr_passthrough_fallback_reason": PASSTHROUGH_FALLBACK_REASON_NOT_REQUESTED,
		"xr_passthrough_state_event": "",
		"display_refresh_rate": 0.0,
		"target_refresh_rate": 0.0,
		"physics_ticks_per_second": 0,
		"vrs_enabled": false,
	}


func _capture_world_environment_defaults() -> void:
	if _world_environment == null or _world_environment.environment == null:
		return
	_opaque_background_mode = _world_environment.environment.background_mode
	_opaque_background_color = _world_environment.environment.background_color


func _apply_opaque_baseline(reason: String) -> void:
	_passthrough_validation_ticket += 1
	if _viewport != null:
		_viewport.transparent_bg = false
	_set_environment_blend_mode(XRInterface.XR_ENV_BLEND_MODE_OPAQUE)
	if reason != "initialize":
		_stop_passthrough_if_possible()
	if _world_environment != null and _world_environment.environment != null:
		_world_environment.environment.background_mode = _opaque_background_mode
		_world_environment.environment.background_color = _opaque_background_color
	_diagnostics["passthrough_enabled"] = false
	_diagnostics["xr_active_mode"] = PRESENTATION_MODE_OPAQUE
	_diagnostics["xr_passthrough_started"] = false
	_diagnostics["environment_blend_mode"] = _get_current_environment_blend_mode()
	if reason == "toggle":
		_diagnostics["xr_passthrough_fallback_reason"] = PASSTHROUGH_FALLBACK_REASON_NOT_REQUESTED
		_diagnostics["xr_passthrough_state_event"] = ""
	elif reason == "initialize":
		_diagnostics["xr_passthrough_fallback_reason"] = PASSTHROUGH_FALLBACK_REASON_NOT_REQUESTED
	_log_info("XR_OPAQUE_BASELINE_APPLIED", {
		"reason": reason,
		"environment_blend_mode": int(_diagnostics["environment_blend_mode"]),
	})


func _request_passthrough(reason: String) -> void:
	_log_info("XR_PASSTHROUGH_REQUESTED", {
		"reason": reason,
	})
	if not bool(_diagnostics.get("alpha_blend_supported", false)) \
		or not bool(_diagnostics.get("passthrough_supported", false)):
		_fallback_to_opaque(PASSTHROUGH_FALLBACK_REASON_NOT_SUPPORTED)
		return

	_start_passthrough_if_possible()
	if _world_environment != null and _world_environment.environment != null:
		_world_environment.environment.background_mode = Environment.BG_COLOR
		_world_environment.environment.background_color = Color(0.0, 0.0, 0.0, 0.0)

	if _viewport != null:
		_viewport.transparent_bg = true
	if not _set_environment_blend_mode(XRInterface.XR_ENV_BLEND_MODE_ALPHA_BLEND):
		_fallback_to_opaque(PASSTHROUGH_FALLBACK_REASON_BLEND_MODE_REJECTED)
		return

	_diagnostics["environment_blend_mode"] = _get_current_environment_blend_mode()
	if int(_diagnostics["environment_blend_mode"]) != XRInterface.XR_ENV_BLEND_MODE_ALPHA_BLEND:
		_fallback_to_opaque(PASSTHROUGH_FALLBACK_REASON_BLEND_MODE_REJECTED)
		return

	var passthrough_started := _query_passthrough_started()
	if _passthrough_extension != null and _passthrough_extension.has_method("is_passthrough_started") and not passthrough_started:
		_diagnostics["passthrough_enabled"] = true
		_diagnostics["xr_active_mode"] = PRESENTATION_MODE_PASSTHROUGH
		_diagnostics["xr_passthrough_started"] = false
		_diagnostics["xr_passthrough_fallback_reason"] = PASSTHROUGH_FALLBACK_REASON_NOT_REQUESTED
		_diagnostics["xr_passthrough_state_event"] = PASSTHROUGH_STATE_EVENT_STARTING
		_log_info("XR_PASSTHROUGH_START_PENDING", {
			"reason": reason,
			"environment_blend_mode": int(_diagnostics["environment_blend_mode"]),
		})
		_schedule_passthrough_validation(reason)
		return

	_mark_passthrough_verified(reason)


func _fallback_to_opaque(fallback_reason: String) -> void:
	if not fallback_to_opaque_on_passthrough_failure:
		_diagnostics["passthrough_enabled"] = false
		_diagnostics["xr_active_mode"] = PRESENTATION_MODE_OPAQUE
		_diagnostics["xr_passthrough_started"] = false
		_diagnostics["xr_requested_mode"] = PRESENTATION_MODE_OPAQUE
		_diagnostics["xr_passthrough_fallback_reason"] = fallback_reason
		return
	_apply_opaque_baseline("passthrough_fallback")
	_diagnostics["xr_requested_mode"] = PRESENTATION_MODE_OPAQUE
	_diagnostics["xr_passthrough_fallback_reason"] = fallback_reason
	_log_info("XR_PASSTHROUGH_FALLBACK_TO_OPAQUE", {
		"fallback_reason": fallback_reason,
	})


func _connect_passthrough_signals() -> void:
	if _passthrough_state_connected or _passthrough_extension == null:
		return
	_passthrough_state_connected = true
	if _passthrough_extension.has_signal("openxr_fb_passthrough_state_changed"):
		_passthrough_extension.connect("openxr_fb_passthrough_state_changed", Callable(self, "_on_passthrough_state_changed"))
	if _passthrough_extension.has_signal("openxr_fb_passthrough_started"):
		_passthrough_extension.connect("openxr_fb_passthrough_started", Callable(self, "_on_passthrough_started"))
	if _passthrough_extension.has_signal("openxr_fb_passthrough_stopped"):
		_passthrough_extension.connect("openxr_fb_passthrough_stopped", Callable(self, "_on_passthrough_stopped"))


func _on_passthrough_state_changed(state: Variant = null, reason: Variant = null) -> void:
	_diagnostics["xr_passthrough_state_event"] = str(state)
	if str(state).to_lower().contains("stop") or str(reason).to_lower().contains("stop"):
		_on_passthrough_stopped(state, reason)


func _on_passthrough_started(_arg0: Variant = null, _arg1: Variant = null) -> void:
	_mark_passthrough_verified("signal")


func _on_passthrough_stopped(_arg0: Variant = null, _arg1: Variant = null) -> void:
	_diagnostics["xr_passthrough_state_event"] = PASSTHROUGH_STATE_EVENT_STOPPED
	if str(_diagnostics.get("xr_requested_mode", PRESENTATION_MODE_OPAQUE)) != PRESENTATION_MODE_PASSTHROUGH:
		return
	_log_info("XR_PASSTHROUGH_STOPPED", {})
	_fallback_to_opaque(PASSTHROUGH_FALLBACK_REASON_STATE_STOPPED)


func _mark_passthrough_verified(reason: String) -> void:
	var was_verified := bool(_diagnostics.get("passthrough_enabled", false)) \
		and bool(_diagnostics.get("xr_passthrough_started", false))
	_diagnostics["passthrough_enabled"] = true
	_diagnostics["xr_active_mode"] = PRESENTATION_MODE_PASSTHROUGH
	_diagnostics["xr_passthrough_started"] = true
	_diagnostics["xr_passthrough_fallback_reason"] = PASSTHROUGH_FALLBACK_REASON_NOT_REQUESTED
	_diagnostics["xr_passthrough_state_event"] = PASSTHROUGH_STATE_EVENT_STARTED
	_diagnostics["environment_blend_mode"] = _get_current_environment_blend_mode()
	if was_verified:
		return
	_log_info("XR_PASSTHROUGH_VERIFIED", {
		"reason": reason,
		"environment_blend_mode": int(_diagnostics["environment_blend_mode"]),
		"passthrough_started": true,
	})


func _schedule_passthrough_validation(reason: String) -> void:
	_passthrough_validation_ticket += 1
	var ticket := _passthrough_validation_ticket
	var tree := _get_tree()
	if tree == null:
		_validate_pending_passthrough_start(ticket, reason)
		return
	tree.create_timer(PASSTHROUGH_START_VALIDATION_DELAY_SEC).timeout.connect(func():
		_validate_pending_passthrough_start(ticket, reason)
	)


func _validate_pending_passthrough_start(ticket: int, reason: String) -> Dictionary:
	if ticket != _passthrough_validation_ticket:
		return get_diagnostics()
	if str(_diagnostics.get("xr_requested_mode", PRESENTATION_MODE_OPAQUE)) != PRESENTATION_MODE_PASSTHROUGH:
		return get_diagnostics()
	if _query_passthrough_started():
		_mark_passthrough_verified(reason)
		return get_diagnostics()
	_fallback_to_opaque(PASSTHROUGH_FALLBACK_REASON_NOT_STARTED)
	return get_diagnostics()


func _start_passthrough_if_possible() -> void:
	if _passthrough_extension == null or not _passthrough_extension.has_method("start_passthrough"):
		return
	var result: Variant = _passthrough_extension.start_passthrough()
	_log_info("XR_PASSTHROUGH_START_REQUEST", {
		"has_start_method": true,
		"result": result,
	})


func _stop_passthrough_if_possible() -> void:
	if _passthrough_extension == null or not _passthrough_extension.has_method("stop_passthrough"):
		return
	_passthrough_extension.stop_passthrough()


func _set_environment_blend_mode(mode: int) -> bool:
	if _interface == null:
		return false
	if _interface.has_method("set_environment_blend_mode"):
		var result: Variant = _interface.set_environment_blend_mode(mode)
		if typeof(result) == TYPE_BOOL:
			return bool(result)
		return true
	_interface.environment_blend_mode = mode
	return true


func _get_current_environment_blend_mode() -> int:
	if _interface == null:
		return XRInterface.XR_ENV_BLEND_MODE_OPAQUE
	return int(_interface.environment_blend_mode)


func _get_tree() -> SceneTree:
	var logger := _get_logger()
	if logger != null:
		return logger.get_tree()
	var main_loop: MainLoop = Engine.get_main_loop()
	if main_loop != null and main_loop is SceneTree:
		return main_loop as SceneTree
	return null


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


func _query_passthrough_started() -> bool:
	if _passthrough_extension != null and _passthrough_extension.has_method("is_passthrough_started"):
		return bool(_passthrough_extension.is_passthrough_started())
	return int(_diagnostics.get("environment_blend_mode", XRInterface.XR_ENV_BLEND_MODE_OPAQUE)) == XRInterface.XR_ENV_BLEND_MODE_ALPHA_BLEND


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
