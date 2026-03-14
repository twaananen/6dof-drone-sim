extends "res://addons/gut/test.gd"

const OpenXRBootstrap = preload("res://scripts/xr/openxr_bootstrap.gd")


class FakeViewport:
	extends RefCounted
	var use_xr: bool = false
	var transparent_bg: bool = false


class FakeXRInterface:
	extends RefCounted
	var initialized: bool = false
	var init_result: bool = true
	var supported_modes: Array = []
	var environment_blend_mode: int = -1

	func is_initialized() -> bool:
		return initialized

	func initialize() -> bool:
		initialized = init_result
		return init_result

	func get_supported_environment_blend_modes() -> Array:
		return supported_modes


func test_initialize_reports_missing_interface() -> void:
	var bootstrap := OpenXRBootstrap.new()
	var diagnostics := bootstrap.initialize(null, FakeViewport.new())

	assert_false(diagnostics["ok"])
	assert_eq(diagnostics["error"], "OpenXR interface missing")


func test_initialize_reports_failed_initialization() -> void:
	var bootstrap := OpenXRBootstrap.new()
	var viewport := FakeViewport.new()
	var xr_interface := FakeXRInterface.new()
	xr_interface.init_result = false

	var diagnostics := bootstrap.initialize(xr_interface, viewport)

	assert_false(diagnostics["ok"])
	assert_eq(diagnostics["error"], "OpenXR failed to initialize")
	assert_false(viewport.use_xr)


func test_initialize_surfaces_missing_alpha_blend_support() -> void:
	var bootstrap := OpenXRBootstrap.new()
	var viewport := FakeViewport.new()
	var xr_interface := FakeXRInterface.new()
	xr_interface.supported_modes = [XRInterface.XR_ENV_BLEND_MODE_OPAQUE]

	var diagnostics := bootstrap.initialize(xr_interface, viewport)

	assert_true(diagnostics["ok"])
	assert_false(diagnostics["alpha_blend_supported"])
	assert_eq(diagnostics["error"], "OpenXR alpha blend passthrough unavailable")
	assert_true(viewport.use_xr)
	assert_true(viewport.transparent_bg)
