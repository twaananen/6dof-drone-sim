extends Node

@export var controller: XRController3D

var _pending_event_flags := 0


func request_calibration() -> void:
    _pending_event_flags |= RawControllerState.EVENT_CALIBRATE


func request_recenter() -> void:
    _pending_event_flags |= RawControllerState.EVENT_RECENTER


func read_state() -> Dictionary:
    var state := RawControllerState.default_state()
    if controller == null or not controller.get_has_tracking_data():
        state["tracking_valid"] = false
        state["event_flags"] = _consume_event_flags()
        return state

    var pose = controller.get_pose()
    state["tracking_valid"] = true
    state["event_flags"] = _consume_event_flags()
    state["grip_position"] = controller.global_position
    state["grip_orientation"] = controller.global_transform.basis.get_rotation_quaternion()
    state["linear_velocity"] = pose.linear_velocity if pose != null else Vector3.ZERO
    state["angular_velocity"] = pose.angular_velocity if pose != null else Vector3.ZERO
    state["trigger"] = controller.get_float("trigger")
    state["grip"] = controller.get_float("grip")
    state["thumbstick"] = controller.get_vector2("thumbstick")
    state["buttons"] = _read_buttons()
    return state


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
    if controller.is_button_pressed("grip_click"):
        buttons |= RawControllerState.BUTTON_NORTH
    if controller.is_button_pressed("thumbstick_click"):
        buttons |= RawControllerState.BUTTON_THUMBSTICK
    if controller.is_button_pressed("menu_button"):
        buttons |= RawControllerState.BUTTON_MENU
    return buttons

