extends Node

const OpenXRBootstrap = preload("res://scripts/xr/openxr_bootstrap.gd")

signal xr_initialized(diagnostics)
signal xr_failed(error_text, diagnostics)
signal xr_session_ready()
signal passthrough_diagnostics_changed(diagnostics)

var _world_environment: WorldEnvironment
var _viewport: Viewport
var _left_hand: XRController3D
var _right_hand: XRController3D
var _left_fallback_mesh: MeshInstance3D
var _right_fallback_mesh: MeshInstance3D
var _passthrough_toggle: BaseButton
var _xr_bootstrap: OpenXRBootstrap = OpenXRBootstrap.new()
var _xr_diagnostics: Dictionary = {}
var _xr_interface: XRInterface
var _updating_passthrough_toggle: bool = false


func configure(
	world_environment: WorldEnvironment,
	viewport: Viewport,
	left_hand: XRController3D,
	right_hand: XRController3D,
	left_fallback_mesh: MeshInstance3D,
	right_fallback_mesh: MeshInstance3D,
	passthrough_toggle: BaseButton
) -> void:
	_world_environment = world_environment
	_viewport = viewport
	_left_hand = left_hand
	_right_hand = right_hand
	_left_fallback_mesh = left_fallback_mesh
	_right_fallback_mesh = right_fallback_mesh
	_passthrough_toggle = passthrough_toggle
	if _passthrough_toggle != null:
		_passthrough_toggle.toggled.connect(_on_passthrough_toggled)


func initialize_xr() -> Dictionary:
	_xr_bootstrap.world_environment = _world_environment
	_xr_bootstrap.prefer_passthrough_on_startup = true
	_xr_bootstrap.fallback_to_opaque_on_passthrough_failure = true
	_xr_interface = XRServer.find_interface("OpenXR")
	_xr_diagnostics = _xr_bootstrap.initialize(_xr_interface, _viewport)
	_connect_session_signal()
	_update_controller_visuals()
	QuestRuntimeLog.boot("CONTROLLER_VISUALS_UPDATED", {
		"render_model_plugin_available": bool(_xr_diagnostics.get("render_model_plugin_available", false)),
	})
	sync_passthrough_toggle()
	QuestRuntimeLog.boot("PASSTHROUGH_TOGGLE_SYNCED", {
		"enabled": bool(_xr_diagnostics.get("passthrough_enabled", false)),
		"toggle_disabled": _passthrough_toggle.disabled if _passthrough_toggle != null else true,
	})
	if bool(_xr_diagnostics.get("ok", false)):
		xr_initialized.emit(get_diagnostics())
	else:
		xr_failed.emit(str(_xr_diagnostics.get("error", "OpenXR initialization failed")), get_diagnostics())
	return get_diagnostics()


func get_diagnostics() -> Dictionary:
	return _xr_diagnostics.duplicate(true)


func get_xr_interface() -> XRInterface:
	return _xr_interface


func set_passthrough_enabled(enabled: bool) -> void:
	_xr_diagnostics = _xr_bootstrap.set_passthrough_enabled(enabled)
	sync_passthrough_toggle()
	passthrough_diagnostics_changed.emit(get_diagnostics())


func sync_passthrough_toggle() -> void:
	if _passthrough_toggle == null:
		return
	_updating_passthrough_toggle = true
	_passthrough_toggle.button_pressed = bool(_xr_diagnostics.get("passthrough_enabled", false))
	_passthrough_toggle.disabled = not bool(_xr_diagnostics.get("alpha_blend_supported", false))
	_updating_passthrough_toggle = false


func _update_controller_visuals() -> void:
	if _left_fallback_mesh != null:
		_left_fallback_mesh.visible = false
	if _right_fallback_mesh != null:
		_right_fallback_mesh.visible = false
	for controller in [_left_hand, _right_hand]:
		if controller == null:
			continue
		var render_model: Node = controller.get_node_or_null("ControllerRenderModel")
		var render_model_3d := render_model as Node3D
		if render_model_3d != null:
			render_model_3d.visible = false


func _connect_session_signal() -> void:
	if _xr_interface == null or not _xr_interface.has_signal("session_begun"):
		call_deferred("_emit_session_ready")
		return
	if not _xr_interface.session_begun.is_connected(_on_xr_session_begun):
		_xr_interface.session_begun.connect(_on_xr_session_begun)


func _on_xr_session_begun() -> void:
	xr_session_ready.emit()


func _emit_session_ready() -> void:
	xr_session_ready.emit()


func _on_passthrough_toggled(enabled: bool) -> void:
	if _updating_passthrough_toggle:
		return
	_xr_diagnostics = _xr_bootstrap.set_passthrough_enabled(enabled)
	QuestRuntimeLog.info("PASSTHROUGH_TOGGLED", {
		"requested": enabled,
		"enabled": bool(_xr_diagnostics.get("passthrough_enabled", false)),
	})
	sync_passthrough_toggle()
	passthrough_diagnostics_changed.emit(get_diagnostics())
