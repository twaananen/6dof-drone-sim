extends Node

signal tutorial_visibility_changed(visible)

const PANEL_KEY_FLIGHT := "flight"
const PANEL_KEY_CONNECTION := "connection"
const PANEL_KEY_SESSION := "session"
const PANEL_KEY_TUTORIAL := "tutorial"
const PANEL_KEY_TEMPLATE_LIBRARY := "template_library"
const PANEL_KEY_TEMPLATE_GUIDE := "template_guide"
const PANEL_KEY_TEMPLATE_EDITOR := "template_editor"

const PanelPositionStore = preload("res://scripts/ui/panel_position_store.gd")

var _xr_camera: XRCamera3D
var _tutorial_layer: Node3D
var _managed_panels: Dictionary = {}
var _panel_position_store := PanelPositionStore.new()
var _panel_recentering_connected: bool = false
var _show_tutorial_button: Button


func configure(
	xr_camera: XRCamera3D,
	tutorial_layer: Node3D,
	panels: Dictionary,
	recenter_button: Button,
	show_tutorial_button: Button,
	hide_tutorial_button: Button,
	nav_buttons: Dictionary
) -> void:
	_xr_camera = xr_camera
	_tutorial_layer = tutorial_layer
	_show_tutorial_button = show_tutorial_button
	register_default_panels(panels)
	if recenter_button != null:
		recenter_button.pressed.connect(recenter_visible_panels)
	if show_tutorial_button != null:
		show_tutorial_button.pressed.connect(show_tutorial)
	if hide_tutorial_button != null:
		hide_tutorial_button.pressed.connect(hide_tutorial)
	for key in nav_buttons.keys():
		var button := nav_buttons[key] as Button
		if button != null:
			button.pressed.connect(_on_toggle_button_pressed.bind(str(key)))
	refresh_tutorial_controls()


func register_default_panels(panels: Dictionary) -> void:
	_managed_panels.clear()
	for key in panels.keys():
		var node := panels[key] as Node3D
		if node == null:
			continue
		_register_panel(str(key), node)


func schedule_startup_recenter(xr_interface: XRInterface) -> void:
	if xr_interface == null or not xr_interface.has_signal("session_begun"):
		restore_or_recenter_all()
		return
	if _panel_recentering_connected:
		return
	_panel_recentering_connected = true
	QuestRuntimeLog.boot("UI_PANEL_RECENTER_DEFERRED", {})


func handle_xr_session_ready() -> void:
	await get_tree().process_frame
	restore_or_recenter_all()


func restore_or_recenter_all() -> void:
	for key in _managed_panels:
		var info: Dictionary = _managed_panels[key]
		var node: Node3D = info["node"]
		_restore_or_recenter_panel(node, key, info["default_offset"])


func recenter_visible_panels() -> void:
	for key in _managed_panels:
		var info: Dictionary = _managed_panels[key]
		var node: Node3D = info["node"]
		if not node.visible:
			continue
		_place_panel(node, info["default_offset"])
		_panel_position_store.clear_offsets(key)
	QuestRuntimeLog.info("UI_PANELS_RECENTERED_BY_USER", {})


func toggle_panel(key: String) -> void:
	var info: Dictionary = _managed_panels.get(key, {})
	if info.is_empty():
		return
	var node: Node3D = info["node"]
	node.visible = not node.visible
	if node.visible:
		_restore_or_recenter_panel(node, key, info["default_offset"])
	refresh_tutorial_controls()


func show_tutorial() -> void:
	if _tutorial_layer == null:
		return
	_tutorial_layer.visible = true
	var info: Dictionary = _managed_panels.get(PANEL_KEY_TUTORIAL, {})
	if not info.is_empty():
		_restore_or_recenter_panel(_tutorial_layer, PANEL_KEY_TUTORIAL, info["default_offset"])
	refresh_tutorial_controls()
	tutorial_visibility_changed.emit(true)


func hide_tutorial() -> void:
	if _tutorial_layer == null:
		return
	_tutorial_layer.visible = false
	refresh_tutorial_controls()
	tutorial_visibility_changed.emit(false)


func refresh_tutorial_controls() -> void:
	if _show_tutorial_button != null:
		_show_tutorial_button.disabled = _tutorial_layer != null and _tutorial_layer.visible


func is_tutorial_visible() -> bool:
	return _tutorial_layer != null and _tutorial_layer.visible


func _register_panel(key: String, node: Node3D) -> void:
	_managed_panels[key] = {
		"node": node,
		"default_offset": node.position - _xr_camera.position,
	}
	if node.has_signal("manipulation_ended"):
		node.manipulation_ended.connect(func(): _save_panel_position(node, key))


func _place_panel(panel: Node3D, offset: Vector3) -> void:
	var cam_pos := _xr_camera.global_position
	if not cam_pos.is_finite():
		QuestRuntimeLog.error("UI_PANEL_RECENTER_SKIPPED", {"reason": "camera_pose_invalid"})
		return
	panel.global_position = cam_pos + offset
	panel.look_at(cam_pos, Vector3.UP, true)


func _restore_or_recenter_panel(panel: Node3D, key: String, default_offset: Vector3) -> void:
	var saved: Variant = _panel_position_store.load_offsets(key)
	if saved != null:
		var offset := Vector3(float(saved.get("x", 0.0)), float(saved.get("y", 0.0)), float(saved.get("z", 0.0)))
		_place_panel(panel, offset)
		QuestRuntimeLog.info("UI_PANEL_RESTORED", {"key": key})
	else:
		_place_panel(panel, default_offset)
		QuestRuntimeLog.boot("UI_PANEL_RECENTERED", {
			"key": key,
			"position": [panel.global_position.x, panel.global_position.y, panel.global_position.z],
		})


func _save_panel_position(panel: Node3D, key: String) -> void:
	var delta := panel.global_position - _xr_camera.global_position
	_panel_position_store.save_offsets(key, {"x": delta.x, "y": delta.y, "z": delta.z})
	QuestRuntimeLog.info("UI_PANEL_POSITION_SAVED", {"key": key})


func _on_toggle_button_pressed(key: String) -> void:
	toggle_panel(key)
