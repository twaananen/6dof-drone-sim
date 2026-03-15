extends OpenXRCompositionLayerQuad

const NO_INTERSECTION := Vector2(-1.0, -1.0)
const CURSOR_DISTANCE := 0.002
const DOUBLE_CLICK_TIME := 400
const DOUBLE_CLICK_DIST := 5.0
const ZONE_TITLE := "title"
const ZONE_BODY := "body"
const ZONE_TOP_LEFT := "top_left"
const ZONE_TOP_RIGHT := "top_right"
const ZONE_BOTTOM_LEFT := "bottom_left"
const ZONE_BOTTOM_RIGHT := "bottom_right"
const NO_RAY_INTERSECTION := Vector3(INF, INF, INF)
const RESIZE_SIGNS := {
	ZONE_TOP_LEFT: Vector2(-1.0, 1.0),
	ZONE_TOP_RIGHT: Vector2(1.0, 1.0),
	ZONE_BOTTOM_LEFT: Vector2(-1.0, -1.0),
	ZONE_BOTTOM_RIGHT: Vector2(1.0, -1.0),
}

@export var scene: PackedScene:
	set = set_scene

@export var viewport_size := Vector2i(1536, 2048):
	set = set_viewport_size

@export var grip_move_enabled := true
@export var min_panel_width := 0.38
@export var max_panel_width := 0.95

var _scene_root: Control
var _pointer: Node3D
var _pointer_pressed := false
var _grab_pressed := false
var _prev_intersection: Vector2 = NO_INTERSECTION
var _prev_pressed_pos: Vector2
var _prev_pressed_time: int = 0
var _active_pointer: Node3D
var _manipulation_mode := ""
var _drag_origin: Vector3 = Vector3.ZERO
var _drag_normal: Vector3 = Vector3.FORWARD
var _drag_offset: Vector3 = Vector3.ZERO
var _resize_sign := Vector2.ZERO
var _resize_start_size := Vector2.ONE
var _title_bar: Control
var _top_left_handle: Control
var _top_right_handle: Control
var _bottom_left_handle: Control
var _bottom_right_handle: Control

@onready var _cursor: MeshInstance3D = $Cursor
@onready var _viewport: SubViewport = $SubViewport


func _ready() -> void:
	_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	QuestRuntimeLog.boot("UI_LAYER_READY", {
		"quad_size": [quad_size.x, quad_size.y],
		"viewport_size": [viewport_size.x, viewport_size.y],
	})
	layer_viewport = _viewport
	QuestRuntimeLog.info("UI_LAYER_VIEWPORT_ATTACHED", {
		"viewport_path": str(_viewport.get_path()),
	})
	_try_to_add_scene_root_to_viewport()
	_update_sizes()
	_cache_handles()


func set_scene(new_scene: PackedScene) -> void:
	var new_scene_root: Control
	if new_scene != null:
		new_scene_root = new_scene.instantiate() as Control
		if new_scene_root == null:
			printerr("Scene root must be a Control node!")
			QuestRuntimeLog.error("UI_LAYER_INVALID_ROOT", {
				"scene_path": new_scene.resource_path,
			})
			return

	if _scene_root != null:
		_scene_root.queue_free()
		_scene_root = null

	scene = new_scene
	_scene_root = new_scene_root

	_try_to_add_scene_root_to_viewport()
	_cache_handles()


func set_viewport_size(new_viewport_size: Vector2i) -> void:
	viewport_size = new_viewport_size
	_update_sizes()


func get_scene_root() -> Control:
	return _scene_root


func pointer_intersects(p_pointer: Node3D) -> bool:
	var pointer_transform: Transform3D = p_pointer.global_transform
	var ray_origin: Vector3 = pointer_transform.origin
	var ray_direction: Vector3 = -pointer_transform.basis.z

	if _manipulation_mode != "" and p_pointer == _active_pointer:
		_update_manipulation(ray_origin, ray_direction)
		var updated_intersection: Vector2 = intersects_ray(ray_origin, ray_direction)
		if updated_intersection != NO_INTERSECTION:
			_capture_pointer(p_pointer, updated_intersection)
		else:
			_cursor.visible = false
		return true

	var intersection: Vector2 = intersects_ray(ray_origin, ray_direction)
	if intersection != NO_INTERSECTION:
		_capture_pointer(p_pointer, intersection)
		return true

	if p_pointer == _pointer:
		if _pointer_pressed or _grab_pressed:
			return true
		pointer_leave(p_pointer)

	return false


func pointer_leave(p_pointer: Node3D) -> void:
	if p_pointer != _pointer:
		return

	if _manipulation_mode != "":
		return

	if _pointer_pressed and _prev_intersection != NO_INTERSECTION:
		_send_mouse_button_event(false)

	_pointer = null
	_pointer_pressed = false
	_grab_pressed = false
	_cursor.visible = false
	_prev_intersection = NO_INTERSECTION
	_prev_pressed_time = 0


func pointer_set_pressed(p_pointer: Node3D, p_pressed: bool) -> void:
	if _manipulation_mode != "" and _active_pointer != null and _active_pointer != p_pointer:
		return

	if p_pressed:
		if _pointer != null and _pointer != p_pointer:
			pointer_leave(_pointer)
		if p_pointer != _pointer and not pointer_intersects(p_pointer):
			return
	elif p_pointer != _pointer:
		return

	if p_pressed == _pointer_pressed:
		return

	_pointer_pressed = p_pressed
	if _manipulation_mode != "" and p_pointer == _active_pointer:
		if not p_pressed:
			_end_manipulation()
		return

	if p_pressed:
		match _get_hit_zone(_intersect_to_viewport_pos(_prev_intersection)):
			ZONE_TOP_LEFT, ZONE_TOP_RIGHT, ZONE_BOTTOM_LEFT, ZONE_BOTTOM_RIGHT:
				_begin_resize(p_pointer, _get_hit_zone(_intersect_to_viewport_pos(_prev_intersection)))
			ZONE_TITLE:
				_begin_move(p_pointer)
			_:
				_send_mouse_button_event(true)
	else:
		_send_mouse_button_event(false)
		_clear_pointer_if_idle()


func pointer_set_grab_pressed(p_pointer: Node3D, p_pressed: bool) -> void:
	if not grip_move_enabled:
		return
	if _manipulation_mode != "" and _active_pointer != null and _active_pointer != p_pointer:
		return

	if p_pressed:
		if _pointer != null and _pointer != p_pointer:
			pointer_leave(_pointer)
		if p_pointer != _pointer and not pointer_intersects(p_pointer):
			return
	elif p_pointer != _pointer:
		return

	if p_pressed == _grab_pressed:
		return

	_grab_pressed = p_pressed
	if _manipulation_mode != "" and p_pointer == _active_pointer:
		if not p_pressed:
			_end_manipulation()
		return

	if p_pressed and _prev_intersection != NO_INTERSECTION:
		_begin_move(p_pointer)
	else:
		_clear_pointer_if_idle()


func _update_sizes() -> void:
	if _viewport != null and _viewport.size != viewport_size:
		_viewport.size = viewport_size


func _try_to_add_scene_root_to_viewport() -> void:
	if !is_inside_tree() or _scene_root == null or _scene_root.get_parent() == _viewport:
		return

	_viewport.add_child(_scene_root)
	QuestRuntimeLog.info("UI_LAYER_SCENE_ATTACHED", {
		"scene_root": _scene_root.name,
		"viewport_path": str(_viewport.get_path()),
	})


func _cache_handles() -> void:
	if _scene_root == null:
		_title_bar = null
		_top_left_handle = null
		_top_right_handle = null
		_bottom_left_handle = null
		_bottom_right_handle = null
		return

	_title_bar = _scene_root.get_node_or_null("Chrome")
	_top_left_handle = _scene_root.get_node_or_null("ResizeTopLeftHandle")
	_top_right_handle = _scene_root.get_node_or_null("ResizeTopRightHandle")
	_bottom_left_handle = _scene_root.get_node_or_null("ResizeBottomLeftHandle")
	_bottom_right_handle = _scene_root.get_node_or_null("ResizeBottomRightHandle")


func _capture_pointer(p_pointer: Node3D, intersection: Vector2) -> void:
	if _pointer == null:
		_pointer = p_pointer
		_cursor.visible = true

	var cursor_position: Vector3 = _intersect_to_global_pos(intersection, CURSOR_DISTANCE)
	if p_pointer.has_method("_update_pointer_length_for_intersection"):
		p_pointer._update_pointer_length_for_intersection(cursor_position)

	if p_pointer != _pointer:
		return

	_cursor.visible = true
	_cursor.global_position = cursor_position

	if _viewport != null and _prev_intersection != NO_INTERSECTION and _manipulation_mode == "":
		var event: InputEventMouseMotion = InputEventMouseMotion.new()
		var from: Vector2 = _intersect_to_viewport_pos(_prev_intersection)
		var to: Vector2 = _intersect_to_viewport_pos(intersection)
		if _pointer_pressed:
			event.button_mask = MOUSE_BUTTON_MASK_LEFT
		event.relative = to - from
		event.position = to
		_viewport.push_input(event)

	_prev_intersection = intersection


func _intersect_to_global_pos(intersection: Vector2, depth: float = 0.0) -> Vector3:
	if intersection != NO_INTERSECTION:
		var local_pos := (intersection - Vector2(0.5, 0.5)) * quad_size
		return global_transform * Vector3(local_pos.x, -local_pos.y, depth)

	return Vector3.ZERO


func _intersect_to_viewport_pos(intersection: Vector2) -> Vector2:
	if _viewport != null and intersection != NO_INTERSECTION:
		var pos: Vector2 = intersection * Vector2(_viewport.size)
		return Vector2(pos)

	return NO_INTERSECTION


func _send_mouse_button_event(p_pressed: bool) -> void:
	if _viewport == null or _prev_intersection == NO_INTERSECTION:
		return

	var event: InputEventMouseButton = InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_LEFT
	event.button_mask = MOUSE_BUTTON_MASK_LEFT
	event.pressed = p_pressed
	event.position = _intersect_to_viewport_pos(_prev_intersection)

	if p_pressed:
		var time: int = Time.get_ticks_msec()
		if time - _prev_pressed_time < DOUBLE_CLICK_TIME and (event.position - _prev_pressed_pos).length() < DOUBLE_CLICK_DIST:
			event.double_click = true
		_prev_pressed_time = time
		_prev_pressed_pos = event.position

	_viewport.push_input(event)


func _get_hit_zone(viewport_pos: Vector2) -> String:
	if viewport_pos == NO_INTERSECTION:
		return ZONE_BODY

	if _control_contains_point(_top_left_handle, viewport_pos):
		return ZONE_TOP_LEFT
	if _control_contains_point(_top_right_handle, viewport_pos):
		return ZONE_TOP_RIGHT
	if _control_contains_point(_bottom_left_handle, viewport_pos):
		return ZONE_BOTTOM_LEFT
	if _control_contains_point(_bottom_right_handle, viewport_pos):
		return ZONE_BOTTOM_RIGHT
	if _control_contains_point(_title_bar, viewport_pos):
		return ZONE_TITLE
	return ZONE_BODY


func _control_contains_point(control: Control, viewport_pos: Vector2) -> bool:
	if control == null or not is_instance_valid(control):
		return false
	return control.get_global_rect().has_point(viewport_pos)


func _begin_move(p_pointer: Node3D) -> void:
	_active_pointer = p_pointer
	_manipulation_mode = ZONE_BODY
	_drag_origin = global_position
	_drag_normal = global_transform.basis.z.normalized()
	_drag_offset = global_position - _intersect_to_global_pos(_prev_intersection)
	_cursor.visible = false


func _begin_resize(p_pointer: Node3D, zone: String) -> void:
	_active_pointer = p_pointer
	_manipulation_mode = "resize"
	_resize_sign = RESIZE_SIGNS.get(zone, Vector2.ONE) as Vector2
	_resize_start_size = quad_size
	_drag_origin = global_position
	_drag_normal = global_transform.basis.z.normalized()
	_cursor.visible = false


func _update_manipulation(ray_origin: Vector3, ray_direction: Vector3) -> void:
	var point: Vector3 = _ray_plane_intersection(ray_origin, ray_direction, _drag_origin, _drag_normal)
	if not point.is_finite():
		return

	if _manipulation_mode == ZONE_BODY:
		global_position = point + _drag_offset
	elif _manipulation_mode == "resize":
		var local_point: Vector2 = _global_to_local(point)
		var start_half: Vector2 = _resize_start_size * 0.5
		var scale_x: float = (local_point.x * _resize_sign.x) / maxf(start_half.x, 0.001)
		var scale_y: float = (local_point.y * _resize_sign.y) / maxf(start_half.y, 0.001)
		var scale: float = maxf(scale_x, scale_y)
		var min_scale: float = min_panel_width / maxf(_resize_start_size.x, 0.001)
		var max_scale: float = max_panel_width / maxf(_resize_start_size.x, 0.001)
		scale = clampf(scale, min_scale, max_scale)
		quad_size = _resize_start_size * scale


func _end_manipulation() -> void:
	_active_pointer = null
	_manipulation_mode = ""
	_resize_sign = Vector2.ZERO
	_clear_pointer_if_idle()


func _clear_pointer_if_idle() -> void:
	if _manipulation_mode != "" or _pointer_pressed or _grab_pressed:
		return
	if _pointer == null:
		return

	var pointer_transform: Transform3D = _pointer.global_transform
	var intersection: Vector2 = intersects_ray(pointer_transform.origin, -pointer_transform.basis.z)
	if intersection == NO_INTERSECTION:
		_pointer = null
		_cursor.visible = false
		_prev_intersection = NO_INTERSECTION


func _global_to_local(point: Vector3) -> Vector2:
	var relative_point: Vector3 = point - global_position
	return Vector2(
		relative_point.dot(global_transform.basis.x),
		-relative_point.dot(global_transform.basis.y)
	)


func _ray_plane_intersection(ray_origin: Vector3, ray_direction: Vector3, plane_origin: Vector3, plane_normal: Vector3) -> Vector3:
	var denominator: float = plane_normal.dot(ray_direction)
	if absf(denominator) <= 0.0001:
		return NO_RAY_INTERSECTION

	var distance: float = plane_normal.dot(plane_origin - ray_origin) / denominator
	if distance < 0.0:
		return NO_RAY_INTERSECTION

	return ray_origin + (ray_direction * distance)
