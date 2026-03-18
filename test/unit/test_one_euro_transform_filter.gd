extends "res://addons/gut/test.gd"


func test_stationary_transform_unchanged() -> void:
	var f := OneEuroTransformFilter.new(1.0, 0.3, 1.0)
	var dt := 1.0 / 90.0
	var xform := Transform3D(Basis.IDENTITY, Vector3(1.0, 2.0, 3.0))
	for i in 100:
		f.filter(xform, dt)
	var result := f.filter(xform, dt)
	assert_almost_eq(result.origin.x, 1.0, 0.001)
	assert_almost_eq(result.origin.y, 2.0, 0.001)
	assert_almost_eq(result.origin.z, 3.0, 0.001)


func test_position_jitter_is_reduced() -> void:
	var f := OneEuroTransformFilter.new(1.0, 0.0, 1.0)
	var dt := 1.0 / 90.0
	var max_deviation := 0.0
	# Feed a position with small random-like jitter around (1, 0, 0).
	for i in 200:
		var jitter := 0.01 * sin(float(i) * 7.3)  # Deterministic pseudo-jitter
		var xform := Transform3D(Basis.IDENTITY, Vector3(1.0 + jitter, 0.0, 0.0))
		var result := f.filter(xform, dt)
		if i > 50:
			max_deviation = maxf(max_deviation, absf(result.origin.x - 1.0))
	# Filtered output should have less deviation than input jitter of 0.01.
	assert_lt(max_deviation, 0.008, "Position jitter should be reduced")


func test_orientation_jitter_is_reduced() -> void:
	var f := OneEuroTransformFilter.new(1.0, 0.0, 1.0)
	var dt := 1.0 / 90.0
	var base_quat := Quaternion.IDENTITY
	var max_angle := 0.0
	for i in 200:
		var jitter_angle := deg_to_rad(0.5) * sin(float(i) * 11.1)
		var jittery_quat := base_quat * Quaternion(Vector3.UP, jitter_angle)
		var xform := Transform3D(Basis(jittery_quat), Vector3.ZERO)
		var result := f.filter(xform, dt)
		if i > 50:
			var result_quat := result.basis.get_rotation_quaternion()
			var angle := base_quat.angle_to(result_quat)
			max_angle = maxf(max_angle, angle)
	# Filtered angle deviation should be less than input jitter of 0.5 degrees.
	assert_lt(max_angle, deg_to_rad(0.4), "Orientation jitter should be reduced")


func test_fast_rotation_passes_through() -> void:
	var f := OneEuroTransformFilter.new(1.0, 1.0, 1.0)
	var dt := 1.0 / 90.0
	# Warm up at identity.
	for i in 50:
		f.filter(Transform3D.IDENTITY, dt)
	# Rotate 45 degrees quickly and check convergence.
	var target_quat := Quaternion(Vector3.UP, deg_to_rad(45.0))
	var target_xform := Transform3D(Basis(target_quat), Vector3.ZERO)
	var result: Transform3D
	for i in 60:
		result = f.filter(target_xform, dt)
	var result_quat := result.basis.get_rotation_quaternion()
	var angle_error := target_quat.angle_to(result_quat)
	assert_lt(angle_error, deg_to_rad(2.0), "Fast rotation should converge within a few degrees")


func test_reset_clears_state() -> void:
	var f := OneEuroTransformFilter.new(1.0, 0.0, 1.0)
	var dt := 1.0 / 90.0
	var xform := Transform3D(Basis.IDENTITY, Vector3(5.0, 5.0, 5.0))
	for i in 50:
		f.filter(xform, dt)
	f.reset()
	var new_xform := Transform3D(Basis.IDENTITY, Vector3.ZERO)
	var result := f.filter(new_xform, dt)
	assert_almost_eq(result.origin.x, 0.0, 0.001, "Reset should clear position state")
	assert_almost_eq(result.origin.y, 0.0, 0.001)
	assert_almost_eq(result.origin.z, 0.0, 0.001)
