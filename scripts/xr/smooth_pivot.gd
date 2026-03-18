class_name SmoothPivot
extends Node3D

## Smoothing pivot inserted between an XRController3D and its children.
##
## Applies a One-Euro filter to the parent controller's transform so that
## all children (pointer ray, wand visual) inherit a jitter-free pose.
## Also bridges XRController3D input signals to children that expect a
## controller parent (e.g. FunctionPointer).

@export_group("Smoothing")
@export var smoothing_enabled := true
@export_range(0.1, 10.0, 0.1) var min_cutoff := 1.0
@export_range(0.0, 5.0, 0.1) var beta := 0.3
@export_range(0.1, 5.0, 0.1) var d_cutoff := 1.0

var _filter: OneEuroTransformFilter
var _controller: XRController3D


func _ready() -> void:
	_filter = OneEuroTransformFilter.new(min_cutoff, beta, d_cutoff)
	_bridge_controller_signals()


func _bridge_controller_signals() -> void:
	var parent_node := get_parent()
	if not parent_node is XRController3D:
		return
	_controller = parent_node as XRController3D
	for child in get_children():
		if child.has_method("_on_controller_input_float_changed"):
			_controller.input_float_changed.connect(child._on_controller_input_float_changed)
		if child.has_method("_on_controller_button_pressed"):
			_controller.button_pressed.connect(child._on_controller_button_pressed)
		if child.has_method("_on_controller_button_released"):
			_controller.button_released.connect(child._on_controller_button_released)


func _process(delta: float) -> void:
	var parent_node: Node3D = get_parent() as Node3D
	if parent_node == null:
		return

	if not smoothing_enabled:
		transform = Transform3D.IDENTITY
		return

	var parent_gt: Transform3D = parent_node.global_transform
	var smoothed_gt: Transform3D = _filter.filter(parent_gt, delta)
	transform = parent_gt.affine_inverse() * smoothed_gt
