class_name OneEuroTransformFilter
extends RefCounted

## One-Euro filter for Transform3D values.
##
## Filters position with three independent scalar One-Euro filters.
## Filters orientation with speed-adaptive quaternion slerp.

var _pos_x: OneEuroFilter
var _pos_y: OneEuroFilter
var _pos_z: OneEuroFilter

# Stored separately from the scalar filters because the quaternion slerp path
# computes its own adaptive alpha inline rather than delegating to a scalar filter.
var _min_cutoff: float
var _beta: float
var _d_cutoff: float

var _prev_quat: Quaternion
var _smoothed_quat: Quaternion
var _filtered_angular_speed: float
var _initialized: bool


func _init(min_cutoff: float = 1.0, beta: float = 0.3, d_cutoff: float = 1.0) -> void:
	_min_cutoff = min_cutoff
	_beta = beta
	_d_cutoff = d_cutoff
	_pos_x = OneEuroFilter.new(min_cutoff, beta, d_cutoff)
	_pos_y = OneEuroFilter.new(min_cutoff, beta, d_cutoff)
	_pos_z = OneEuroFilter.new(min_cutoff, beta, d_cutoff)
	_filtered_angular_speed = 0.0
	_initialized = false


func filter(xform: Transform3D, dt: float) -> Transform3D:
	if dt <= 0.0:
		return xform

	var origin := Vector3(
		_pos_x.filter(xform.origin.x, dt),
		_pos_y.filter(xform.origin.y, dt),
		_pos_z.filter(xform.origin.z, dt),
	)

	var current_quat := xform.basis.get_rotation_quaternion()
	if not _initialized:
		_prev_quat = current_quat
		_smoothed_quat = current_quat
		_initialized = true
		return Transform3D(Basis(current_quat), origin)

	# Ensure shortest-path interpolation.
	if _prev_quat.dot(current_quat) < 0.0:
		current_quat = -current_quat

	var angle_delta := _prev_quat.angle_to(current_quat)
	var angular_speed := angle_delta / dt
	_prev_quat = current_quat

	# Filter the angular speed (derivative), then compute adaptive alpha.
	var d_alpha := OneEuroFilter._smoothing_alpha(dt, _d_cutoff)
	_filtered_angular_speed = lerpf(_filtered_angular_speed, angular_speed, d_alpha)

	var cutoff := _min_cutoff + _beta * absf(_filtered_angular_speed)
	var alpha := OneEuroFilter._smoothing_alpha(dt, cutoff)
	_smoothed_quat = _smoothed_quat.slerp(current_quat, alpha).normalized()

	return Transform3D(Basis(_smoothed_quat), origin)


func reset() -> void:
	_pos_x.reset()
	_pos_y.reset()
	_pos_z.reset()
	_filtered_angular_speed = 0.0
	_initialized = false
