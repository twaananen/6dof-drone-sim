extends "res://addons/gut/test.gd"


func test_constant_input_returns_same_value() -> void:
	var f := OneEuroFilter.new(1.0, 0.3, 1.0)
	var dt := 1.0 / 90.0
	for i in 100:
		var result := f.filter(5.0, dt)
	assert_almost_eq(f.filter(5.0, dt), 5.0, 0.001)


func test_slow_oscillation_is_damped() -> void:
	var f := OneEuroFilter.new(1.0, 0.0, 1.0)
	var dt := 1.0 / 90.0
	var max_output := 0.0
	# Feed a slow sine wave and measure output amplitude after warmup.
	for i in 200:
		var t := float(i) * dt
		var input := sin(t * TAU * 2.0)  # 2 Hz oscillation
		var output := f.filter(input, dt)
		if i > 100:
			max_output = maxf(max_output, absf(output))
	# Output amplitude should be less than input amplitude of 1.0.
	assert_lt(max_output, 0.95, "Slow oscillation should be damped")


func test_fast_step_converges() -> void:
	var f := OneEuroFilter.new(1.0, 1.0, 1.0)
	var dt := 1.0 / 90.0
	# Warm up at 0.
	for i in 50:
		f.filter(0.0, dt)
	# Step to 1.0 and check convergence within 30 frames.
	var result := 0.0
	for i in 30:
		result = f.filter(1.0, dt)
	assert_almost_eq(result, 1.0, 0.05, "Should converge to step target quickly")


func test_reset_clears_state() -> void:
	var f := OneEuroFilter.new(1.0, 0.0, 1.0)
	var dt := 1.0 / 90.0
	for i in 50:
		f.filter(10.0, dt)
	f.reset()
	# After reset, first sample should return the raw value.
	var result := f.filter(0.0, dt)
	assert_almost_eq(result, 0.0, 0.001, "Reset should clear all state")


func test_zero_dt_returns_raw_value() -> void:
	var f := OneEuroFilter.new(1.0, 0.3, 1.0)
	f.filter(5.0, 1.0 / 90.0)
	var result := f.filter(10.0, 0.0)
	assert_almost_eq(result, 10.0, 0.001, "Zero dt should return raw value")


func test_first_sample_returns_raw_value() -> void:
	var f := OneEuroFilter.new(1.0, 0.3, 1.0)
	var result := f.filter(42.0, 1.0 / 90.0)
	assert_almost_eq(result, 42.0, 0.001, "First sample should pass through unfiltered")
