extends Node

@export_node_path("XRController3D") var controller_path: NodePath
@export_range(0.0, 1.0, 0.01) var grip_activate_threshold := 0.7
@export_range(0.0, 1.0, 0.01) var grip_release_threshold := 0.55

const INPUT_SNAPSHOT_INTERVAL_MSEC := 1000

var controller: XRController3D
var _pending_event_flags := 0
var _control_active := false
var _grip_pressed := false
var _origin_capture_pending := false
var _last_tracking_valid := false
var _last_buttons := -1
var _last_logged_control_active := false
var _last_snapshot_msec := 0


func _ready() -> void:
    if controller == null and not controller_path.is_empty():
        controller = get_node_or_null(controller_path) as XRController3D
    if controller == null:
        QuestRuntimeLog.warn("XR_INPUT_READER_UNBOUND", {
            "controller_path": str(controller_path),
        })
        return
    if controller.has_signal("profile_changed"):
        controller.profile_changed.connect(_on_controller_profile_changed)
    if controller.has_signal("button_pressed"):
        controller.button_pressed.connect(_on_controller_button_pressed)
    if controller.has_signal("button_released"):
        controller.button_released.connect(_on_controller_button_released)
    QuestRuntimeLog.info("XR_INPUT_READER_READY", {
        "controller": controller.name,
        "grip_activate_threshold": grip_activate_threshold,
        "grip_release_threshold": grip_release_threshold,
    })


func request_set_origin() -> void:
    if controller != null and controller.get_has_tracking_data():
        _pending_event_flags |= RawControllerState.EVENT_SET_ORIGIN
        _origin_capture_pending = false
        return
    _origin_capture_pending = true
    QuestRuntimeLog.warn("XR_FLIGHT_ORIGIN_DEFERRED", {
        "controller": _controller_label(),
    })


func request_clear_origin() -> void:
    _pending_event_flags |= RawControllerState.EVENT_CLEAR_ORIGIN


func request_calibration() -> void:
    request_set_origin()


func request_recenter() -> void:
    request_clear_origin()


func is_control_active() -> bool:
    return _control_active


func read_state() -> Dictionary:
    var state := RawControllerState.default_state()
    if controller == null:
        state["tracking_valid"] = false
        state["control_active"] = false
        state["event_flags"] = _consume_event_flags()
        _log_state_diagnostics(state)
        return state

    _sync_grip_state()
    state["control_active"] = _control_active
    state["trigger"] = controller.get_float("trigger")
    state["grip"] = controller.get_float("grip")
    state["thumbstick"] = controller.get_vector2("thumbstick")
    state["buttons"] = _read_buttons()
    if not controller.get_has_tracking_data():
        state["tracking_valid"] = false
        state["event_flags"] = _consume_event_flags()
        _log_state_diagnostics(state)
        return state

    var pose = controller.get_pose()
    if _origin_capture_pending:
        _pending_event_flags |= RawControllerState.EVENT_SET_ORIGIN
        _origin_capture_pending = false
    state["tracking_valid"] = true
    state["event_flags"] = _consume_event_flags()
    state["grip_position"] = controller.position
    state["grip_orientation"] = controller.transform.basis.get_rotation_quaternion()
    state["linear_velocity"] = pose.linear_velocity if pose != null else Vector3.ZERO
    state["angular_velocity"] = pose.angular_velocity if pose != null else Vector3.ZERO
    _log_state_diagnostics(state)
    return state


func _sync_grip_state() -> void:
    var grip_value := controller.get_float("grip")
    var grip_pressed := _grip_pressed
    if _grip_pressed:
        grip_pressed = grip_value >= grip_release_threshold
    else:
        grip_pressed = grip_value >= grip_activate_threshold
    if grip_pressed == _grip_pressed:
        return

    _grip_pressed = grip_pressed
    _control_active = grip_pressed
    if grip_pressed:
        _origin_capture_pending = true
    else:
        _origin_capture_pending = false


func _consume_event_flags() -> int:
    var flags := _pending_event_flags
    _pending_event_flags = 0
    return flags


func _read_buttons() -> int:
    var buttons := 0
    if controller.is_button_pressed("ax_button"):
        buttons |= RawControllerState.BUTTON_SOUTH
    if controller.is_button_pressed("by_button"):
        buttons |= RawControllerState.BUTTON_EAST
    if controller.is_button_pressed("trigger_click"):
        buttons |= RawControllerState.BUTTON_WEST
    if _grip_pressed:
        buttons |= RawControllerState.BUTTON_NORTH
    if controller.is_button_pressed("thumbstick_click"):
        buttons |= RawControllerState.BUTTON_THUMBSTICK
    if controller.is_button_pressed("menu_button"):
        buttons |= RawControllerState.BUTTON_MENU
    return buttons


func _log_state_diagnostics(state: Dictionary) -> void:
    var tracking_valid := bool(state.get("tracking_valid", false))
    if tracking_valid != _last_tracking_valid:
        _last_tracking_valid = tracking_valid
        QuestRuntimeLog.info("XR_TRACKING_CHANGED", {
            "controller": _controller_label(),
            "tracking_valid": tracking_valid,
        })

    var control_active := bool(state.get("control_active", false))
    if control_active != _last_logged_control_active:
        _last_logged_control_active = control_active
        QuestRuntimeLog.info("XR_CONTROL_ACTIVE_CHANGED", {
            "controller": _controller_label(),
            "control_active": control_active,
            "grip": snappedf(float(state.get("grip", 0.0)), 0.001),
        })

    var event_flags := int(state.get("event_flags", 0))
    if event_flags & RawControllerState.EVENT_SET_ORIGIN:
        QuestRuntimeLog.info("XR_FLIGHT_ORIGIN_SET", {
            "controller": _controller_label(),
        })
    if event_flags & RawControllerState.EVENT_CLEAR_ORIGIN:
        QuestRuntimeLog.info("XR_FLIGHT_ORIGIN_CLEARED", {
            "controller": _controller_label(),
        })

    var buttons := int(state.get("buttons", 0))
    if buttons != _last_buttons:
        _last_buttons = buttons
        QuestRuntimeLog.info("XR_BUTTON_MASK_CHANGED", {
            "controller": _controller_label(),
            "buttons": buttons,
            "buttons_hex": "0x%04X" % buttons,
            "names": _button_names(buttons),
        })

    var now_msec := Time.get_ticks_msec()
    if now_msec - _last_snapshot_msec < INPUT_SNAPSHOT_INTERVAL_MSEC:
        return
    _last_snapshot_msec = now_msec
    var thumbstick: Vector2 = state.get("thumbstick", Vector2.ZERO)
    QuestRuntimeLog.info("XR_INPUT_SNAPSHOT", {
        "controller": _controller_label(),
        "tracking_valid": tracking_valid,
        "control_active": control_active,
        "grip": snappedf(float(state.get("grip", 0.0)), 0.001),
        "trigger": snappedf(float(state.get("trigger", 0.0)), 0.001),
        "thumbstick_x": snappedf(thumbstick.x, 0.001),
        "thumbstick_y": snappedf(thumbstick.y, 0.001),
        "buttons": buttons,
        "buttons_hex": "0x%04X" % buttons,
    })


func _button_names(buttons: int) -> Array[String]:
    var names: Array[String] = []
    if RawControllerState.button_pressed(buttons, RawControllerState.BUTTON_SOUTH):
        names.append("button_south")
    if RawControllerState.button_pressed(buttons, RawControllerState.BUTTON_EAST):
        names.append("button_east")
    if RawControllerState.button_pressed(buttons, RawControllerState.BUTTON_WEST):
        names.append("button_west")
    if RawControllerState.button_pressed(buttons, RawControllerState.BUTTON_NORTH):
        names.append("button_north")
    if RawControllerState.button_pressed(buttons, RawControllerState.BUTTON_THUMBSTICK):
        names.append("thumbstick")
    if RawControllerState.button_pressed(buttons, RawControllerState.BUTTON_MENU):
        names.append("menu")
    return names


func _controller_label() -> String:
    return controller.name if controller != null else "unassigned"


func _on_controller_profile_changed(role: String) -> void:
    QuestRuntimeLog.info("XR_CONTROLLER_PROFILE_CHANGED", {
        "controller": _controller_label(),
        "role": role,
    })


func _on_controller_button_pressed(name: String) -> void:
    QuestRuntimeLog.info("XR_BUTTON_PRESSED", {
        "controller": _controller_label(),
        "button": name,
    })


func _on_controller_button_released(name: String) -> void:
    QuestRuntimeLog.info("XR_BUTTON_RELEASED", {
        "controller": _controller_label(),
        "button": name,
    })
