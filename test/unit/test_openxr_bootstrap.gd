extends "res://addons/gut/test.gd"

const OpenXRBootstrap = preload("res://scripts/xr/openxr_bootstrap.gd")


class FakeViewport:
	extends RefCounted
	var use_xr: bool = false
	var transparent_bg: bool = false
	var vrs_mode: int = -1


class FakeXRInterface:
	extends RefCounted
	var initialized: bool = false
	var init_result: bool = true
	var supported_modes: Array = []
	var environment_blend_mode: int = -1
	var display_refresh_rate: float = 72.0
	var available_display_refresh_rates: Array = [72.0, 90.0]

	func is_initialized() -> bool:
		return initialized

	func initialize() -> bool:
		initialized = init_result
		return init_result

	func get_supported_environment_blend_modes() -> Array:
		return supported_modes

	func get_display_refresh_rate() -> float:
		return display_refresh_rate

	func get_available_display_refresh_rates() -> Array:
		return available_display_refresh_rates

	func set_display_refresh_rate(new_rate: float) -> void:
		display_refresh_rate = new_rate


class FakePassthroughExtension:
	extends RefCounted
	var preferred: bool = false
	var supported: bool = true

	func is_passthrough_preferred() -> bool:
		return preferred

	func is_passthrough_supported() -> bool:
		return supported


func before_each() -> void:
	_logger().clear_entries()


func test_initialize_reports_missing_interface() -> void:
	var bootstrap := OpenXRBootstrap.new()
	var diagnostics := bootstrap.initialize(null, FakeViewport.new())

	assert_false(diagnostics["ok"])
	assert_eq(diagnostics["error"], "OpenXR interface missing")
	assert_eq(_logger().get_entries()[-1]["event"], "XR_INIT_FAILED")


func test_initialize_reports_failed_initialization() -> void:
	var bootstrap := OpenXRBootstrap.new()
	var viewport := FakeViewport.new()
	var xr_interface := FakeXRInterface.new()
	xr_interface.init_result = false

	var diagnostics := bootstrap.initialize(xr_interface, viewport)

	assert_false(diagnostics["ok"])
	assert_eq(diagnostics["error"], "OpenXR failed to initialize")
	assert_false(viewport.use_xr)
	assert_eq(_logger().get_entries()[-1]["event"], "XR_INIT_FAILED")


func test_initialize_surfaces_missing_alpha_blend_support() -> void:
	var bootstrap := OpenXRBootstrap.new()
	var viewport := FakeViewport.new()
	var xr_interface := FakeXRInterface.new()
	var passthrough_extension := FakePassthroughExtension.new()
	xr_interface.supported_modes = [XRInterface.XR_ENV_BLEND_MODE_OPAQUE]

	var diagnostics := bootstrap.initialize(xr_interface, viewport, passthrough_extension)

	assert_true(diagnostics["ok"])
	assert_false(diagnostics["alpha_blend_supported"])
	assert_false(diagnostics["passthrough_enabled"])
	assert_true(viewport.use_xr)
	assert_false(viewport.transparent_bg)
	assert_true(_has_event("XR_BLEND_MODES"))
	assert_false(_has_event("XR_REFRESH_RATE_CONFIGURED"))


func test_initialize_enables_passthrough_when_preferred() -> void:
	var bootstrap := OpenXRBootstrap.new()
	var viewport := FakeViewport.new()
	var xr_interface := FakeXRInterface.new()
	var passthrough_extension := FakePassthroughExtension.new()
	passthrough_extension.preferred = true
	xr_interface.supported_modes = [XRInterface.XR_ENV_BLEND_MODE_OPAQUE, XRInterface.XR_ENV_BLEND_MODE_ALPHA_BLEND]

	var diagnostics := bootstrap.initialize(xr_interface, viewport, passthrough_extension)
	diagnostics = bootstrap.on_session_begun()

	assert_true(diagnostics["ok"])
	assert_true(diagnostics["passthrough_enabled"])
	assert_true(viewport.transparent_bg)
	assert_eq(xr_interface.environment_blend_mode, XRInterface.XR_ENV_BLEND_MODE_ALPHA_BLEND)
	assert_eq(diagnostics["display_refresh_rate"], 90.0)
	assert_true(_has_phase("XR_INIT_OK"))
	assert_true(_has_event("XR_REFRESH_RATE_CONFIGURED"))


func test_set_passthrough_enabled_switches_back_to_opaque() -> void:
	var bootstrap := OpenXRBootstrap.new()
	var viewport := FakeViewport.new()
	var xr_interface := FakeXRInterface.new()
	var passthrough_extension := FakePassthroughExtension.new()
	passthrough_extension.preferred = true
	xr_interface.supported_modes = [XRInterface.XR_ENV_BLEND_MODE_OPAQUE, XRInterface.XR_ENV_BLEND_MODE_ALPHA_BLEND]

	bootstrap.initialize(xr_interface, viewport, passthrough_extension)
	bootstrap.on_session_begun()
	var diagnostics := bootstrap.set_passthrough_enabled(false)

	assert_false(diagnostics["passthrough_enabled"])
	assert_false(viewport.transparent_bg)
	assert_eq(xr_interface.environment_blend_mode, XRInterface.XR_ENV_BLEND_MODE_OPAQUE)
	assert_eq(_logger().get_entries()[-1]["event"], "XR_PASSTHROUGH_STATE")


func _has_event(event_name: String) -> bool:
	for entry in _logger().get_entries():
		if str(entry.get("event", "")) == event_name:
			return true
	return false


func _has_phase(phase_name: String) -> bool:
	for entry in _logger().get_entries():
		if str(entry.get("phase", "")) == phase_name:
			return true
	return false


func _logger() -> Node:
	return get_tree().root.get_node("QuestRuntimeLog")
