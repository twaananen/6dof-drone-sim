extends Node3D

const OpenXRBootstrap = preload("res://scripts/xr/openxr_bootstrap.gd")

@onready var world_environment: WorldEnvironment = $WorldEnvironment
@onready var xr_camera: XRCamera3D = $XROrigin3D/XRCamera3D
@onready var ui_pivot: Node3D = $XROrigin3D/QuestUiLayer
@onready var quest_ui_layer: Node = $XROrigin3D/QuestUiLayer
@onready var left_hand: XRController3D = $XROrigin3D/LeftHand
@onready var right_hand: XRController3D = $XROrigin3D/RightHand
@onready var left_fallback_mesh: MeshInstance3D = $XROrigin3D/LeftHand/FallbackMesh
@onready var right_fallback_mesh: MeshInstance3D = $XROrigin3D/RightHand/FallbackMesh

var status_label: Label
var passthrough_toggle: BaseButton
var recenter_panel_button: Button

var _xr_bootstrap: OpenXRBootstrap = OpenXRBootstrap.new()
var _xr_diagnostics: Dictionary = {}
var _updating_passthrough_toggle := false
var _xr_interface: XRInterface
var _panel_recentering_connected := false


func _ready() -> void:
	QuestRuntimeLog.boot("BOOTSTRAP_REPRO_READY_BEGIN", {
		"scene": "quest_bootstrap_repro",
	})
	if not _bind_ui_controls():
		return
	recenter_panel_button.pressed.connect(_recenter_ui_panel)
	passthrough_toggle.toggled.connect(_on_passthrough_toggled)
	QuestRuntimeLog.boot("BOOTSTRAP_REPRO_UI_SIGNALS_BOUND", {})

	_xr_bootstrap.world_environment = world_environment
	_xr_bootstrap.prefer_passthrough_on_startup = true
	_xr_bootstrap.fallback_to_opaque_on_passthrough_failure = true
	_xr_diagnostics = _xr_bootstrap.initialize(XRServer.find_interface("OpenXR"), get_viewport())
	_xr_interface = XRServer.find_interface("OpenXR")
	if bool(_xr_diagnostics.get("ok", false)):
		QuestRuntimeLog.boot("BOOTSTRAP_REPRO_XR_INIT_OK", {
			"display_refresh_rate": float(_xr_diagnostics.get("display_refresh_rate", 0.0)),
			"passthrough_enabled": bool(_xr_diagnostics.get("passthrough_enabled", false)),
		})
		_schedule_startup_recenter()
	else:
		QuestRuntimeLog.error("BOOTSTRAP_REPRO_XR_INIT_FAILED", {
			"error": str(_xr_diagnostics.get("error", "")),
		})

	_update_controller_visuals()
	_sync_passthrough_toggle()
	_update_status_label()
	QuestRuntimeLog.boot("BOOTSTRAP_REPRO_READY_COMPLETE", {
		"xr_state": str(_xr_diagnostics.get("state", OpenXRBootstrap.STATE_XR_STARTING)),
	})


func _bind_ui_controls() -> bool:
	var quest_panel := quest_ui_layer.call("get_scene_root") as Control
	if quest_panel == null:
		QuestRuntimeLog.error("BOOTSTRAP_REPRO_UI_BIND_FAILED", {
			"reason": "missing_scene_root",
		})
		return false

	status_label = quest_panel.get_node_or_null("Panel/Margin/Scroll/VBox/StatusLabel") as Label
	passthrough_toggle = quest_panel.get_node_or_null("Panel/Margin/Scroll/VBox/PassthroughToggle") as BaseButton
	recenter_panel_button = quest_panel.get_node_or_null("Panel/Margin/Scroll/VBox/ConnectionButtons/RecenterPanelButton") as Button
	if status_label == null or passthrough_toggle == null or recenter_panel_button == null:
		QuestRuntimeLog.error("BOOTSTRAP_REPRO_UI_BIND_FAILED", {
			"reason": "missing_nodes",
		})
		return false

	QuestRuntimeLog.boot("BOOTSTRAP_REPRO_UI_BIND_OK", {})
	return true


func _update_controller_visuals() -> void:
	left_fallback_mesh.visible = true
	right_fallback_mesh.visible = true
	QuestRuntimeLog.boot("BOOTSTRAP_REPRO_CONTROLLER_VISUALS_UPDATED", {})


func _schedule_startup_recenter() -> void:
	if _xr_interface == null or not _xr_interface.has_signal("session_begun"):
		_recenter_ui_panel()
		return
	if _panel_recentering_connected:
		return
	_panel_recentering_connected = true
	if _xr_interface.session_begun.is_connected(_on_xr_session_begun):
		return
	_xr_interface.session_begun.connect(_on_xr_session_begun)
	QuestRuntimeLog.boot("BOOTSTRAP_REPRO_UI_PANEL_RECENTER_DEFERRED", {})


func _on_xr_session_begun() -> void:
	await get_tree().process_frame
	_recenter_ui_panel()


func _recenter_ui_panel() -> void:
	var camera_position := xr_camera.global_position
	var camera_basis := xr_camera.global_transform.basis
	if not camera_position.is_finite() or not camera_basis.is_finite():
		QuestRuntimeLog.warn("BOOTSTRAP_REPRO_UI_PANEL_RECENTER_SKIPPED", {
			"reason": "camera_pose_invalid",
		})
		return
	var forward := -xr_camera.global_transform.basis.z
	forward.y = 0.0
	if is_zero_approx(forward.length_squared()):
		forward = Vector3(0.0, 0.0, -1.0)
	else:
		forward = forward.normalized()
	ui_pivot.global_position = xr_camera.global_position + (forward * 1.1) + Vector3(0.0, -0.12, 0.0)
	ui_pivot.look_at(xr_camera.global_position, Vector3.UP, true)
	QuestRuntimeLog.boot("BOOTSTRAP_REPRO_UI_PANEL_RECENTERED", {
		"position": [ui_pivot.global_position.x, ui_pivot.global_position.y, ui_pivot.global_position.z],
	})


func _sync_passthrough_toggle() -> void:
	_updating_passthrough_toggle = true
	passthrough_toggle.button_pressed = bool(_xr_diagnostics.get("passthrough_enabled", false))
	passthrough_toggle.disabled = not bool(_xr_diagnostics.get("alpha_blend_supported", false))
	_updating_passthrough_toggle = false
	QuestRuntimeLog.boot("BOOTSTRAP_REPRO_PASSTHROUGH_TOGGLE_SYNCED", {
		"enabled": bool(_xr_diagnostics.get("passthrough_enabled", false)),
		"toggle_disabled": passthrough_toggle.disabled,
	})


func _on_passthrough_toggled(enabled: bool) -> void:
	if _updating_passthrough_toggle:
		return
	_xr_diagnostics = _xr_bootstrap.set_passthrough_enabled(enabled)
	_sync_passthrough_toggle()
	_update_status_label()


func _update_status_label() -> void:
	status_label.text = "\n".join([
		"XR: %s" % str(_xr_diagnostics.get("state", OpenXRBootstrap.STATE_XR_STARTING)),
		"Passthrough: %s" % ("on" if bool(_xr_diagnostics.get("passthrough_enabled", false)) else "off"),
		"XR Mode: %s" % str(_xr_diagnostics.get("xr_active_mode", OpenXRBootstrap.PRESENTATION_MODE_OPAQUE)),
		"Fallback: %s" % str(_xr_diagnostics.get("xr_passthrough_fallback_reason", "")),
		"Refresh: %.0f Hz" % float(_xr_diagnostics.get("display_refresh_rate", 0.0)),
	])
