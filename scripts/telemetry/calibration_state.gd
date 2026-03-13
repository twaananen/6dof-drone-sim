class_name CalibrationState
extends RefCounted

var _is_calibrated: bool = false
var _center_position: Vector3 = Vector3.ZERO
var _center_orientation_inverse: Quaternion = Quaternion.IDENTITY


func calibrate(position: Vector3, orientation: Quaternion) -> void:
    _center_position = position
    _center_orientation_inverse = orientation.inverse()
    _is_calibrated = true


func reset() -> void:
    _is_calibrated = false
    _center_position = Vector3.ZERO
    _center_orientation_inverse = Quaternion.IDENTITY


func is_calibrated() -> bool:
    return _is_calibrated


func apply_position(position: Vector3) -> Vector3:
    if not _is_calibrated:
        return position
    return position - _center_position


func apply_orientation(orientation: Quaternion) -> Quaternion:
    if not _is_calibrated:
        return orientation
    return _center_orientation_inverse * orientation
