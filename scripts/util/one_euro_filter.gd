class_name OneEuroFilter
extends RefCounted

## Speed-adaptive low-pass filter for scalar values.
##
## Based on "1€ Filter: A Simple Speed-based Low-pass Filter for Noisy Input
## in Interactive Systems" (Casiez, Roussel, Vogel – CHI 2012).

var _min_cutoff: float
var _beta: float
var _d_cutoff: float

var _x_prev: float
var _dx_prev: float
var _initialized: bool


func _init(min_cutoff: float = 1.0, beta: float = 0.3, d_cutoff: float = 1.0) -> void:
	_min_cutoff = min_cutoff
	_beta = beta
	_d_cutoff = d_cutoff
	_initialized = false


func filter(value: float, dt: float) -> float:
	if dt <= 0.0:
		return value

	if not _initialized:
		_x_prev = value
		_dx_prev = 0.0
		_initialized = true
		return value

	var dx := (value - _x_prev) / dt
	var dx_alpha := _smoothing_alpha(dt, _d_cutoff)
	_dx_prev = lerpf(_dx_prev, dx, dx_alpha)

	var cutoff := _min_cutoff + _beta * absf(_dx_prev)
	var x_alpha := _smoothing_alpha(dt, cutoff)
	_x_prev = lerpf(_x_prev, value, x_alpha)

	return _x_prev


func reset() -> void:
	_initialized = false


static func _smoothing_alpha(dt: float, cutoff: float) -> float:
	var tau := 1.0 / (TAU * cutoff)
	return clampf(dt / (dt + tau), 0.0, 1.0)
