extends Node3D

const MAX_HIGHLIGHT_DISTANCE := 0.25

@onready var _sphere: MeshInstance3D = $Sphere


func show_from_transform(origin_transform: Transform3D) -> void:
	global_transform = origin_transform
	visible = true
	_set_highlight(Vector3.FORWARD, 0.0)


func hide_indicator() -> void:
	visible = false
	_set_highlight(Vector3.FORWARD, 0.0)


func update_displacement(current_position: Vector3) -> void:
	if not visible:
		return

	var displacement := current_position - global_transform.origin
	var magnitude := displacement.length()
	if magnitude <= 0.0001:
		_set_highlight(Vector3.FORWARD, 0.0)
		return

	var local_direction := global_transform.basis.inverse() * displacement.normalized()
	_set_highlight(local_direction.normalized(), clampf(magnitude / MAX_HIGHLIGHT_DISTANCE, 0.0, 1.0))


func _set_highlight(direction: Vector3, strength: float) -> void:
	var material := _sphere.get_active_material(0) as ShaderMaterial
	if material == null:
		return
	material.set_shader_parameter("highlight_direction", direction)
	material.set_shader_parameter("highlight_strength", strength)
