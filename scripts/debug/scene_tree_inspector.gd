class_name SceneTreeInspector
extends RefCounted

const MAX_NODES := 500


static func walk_tree(root: Node, max_depth: int = 3) -> Dictionary:
	if max_depth < 0:
		max_depth = 10
	var count := [0]
	var truncated := [false]
	var tree := _serialize_node(root, 0, max_depth, count, truncated)
	return {
		"root_path": str(root.get_path()),
		"node_count": count[0],
		"truncated": truncated[0],
		"tree": tree,
	}


static func inspect_node(node: Node, properties: Array) -> Dictionary:
	var result := {
		"path": str(node.get_path()),
		"type": node.get_class(),
		"properties": {},
	}
	for prop_name: String in properties:
		var value: Variant = node.get(prop_name)
		if value != null:
			result["properties"][prop_name] = _serialize_value(value)
		else:
			result["properties"][prop_name] = null
	return result


static func _serialize_node(node: Node, depth: int, max_depth: int, count: Array, truncated: Array) -> Dictionary:
	count[0] += 1
	if count[0] > MAX_NODES:
		truncated[0] = true
		return {"name": node.name, "type": node.get_class(), "path": str(node.get_path()), "truncated": true}

	var dict := {
		"name": str(node.name),
		"type": node.get_class(),
		"path": str(node.get_path()),
		"child_count": node.get_child_count(),
		"process_mode": int(node.process_mode),
	}

	if node is Node3D:
		dict["visible"] = node.visible
		dict["transform"] = _serialize_transform(node.transform)
		dict["global_transform"] = _serialize_transform(node.global_transform)

	if node is CanvasItem:
		dict["visible"] = node.visible

	if depth < max_depth:
		var children := []
		for child: Node in node.get_children():
			if count[0] > MAX_NODES:
				truncated[0] = true
				break
			children.append(_serialize_node(child, depth + 1, max_depth, count, truncated))
		dict["children"] = children
	else:
		dict["children"] = []

	return dict


static func _serialize_transform(t: Transform3D) -> Dictionary:
	return {
		"origin": _serialize_vector3(t.origin),
		"basis_x": _serialize_vector3(t.basis.x),
		"basis_y": _serialize_vector3(t.basis.y),
		"basis_z": _serialize_vector3(t.basis.z),
	}


static func _serialize_vector3(v: Vector3) -> Array:
	return [snapped(v.x, 0.0001), snapped(v.y, 0.0001), snapped(v.z, 0.0001)]


static func _serialize_value(value: Variant) -> Variant:
	if value is Vector3:
		return _serialize_vector3(value)
	if value is Vector2:
		return [snapped(value.x, 0.0001), snapped(value.y, 0.0001)]
	if value is Transform3D:
		return _serialize_transform(value)
	if value is Quaternion:
		return [snapped(value.x, 0.0001), snapped(value.y, 0.0001), snapped(value.z, 0.0001), snapped(value.w, 0.0001)]
	if value is Color:
		return [snapped(value.r, 0.0001), snapped(value.g, 0.0001), snapped(value.b, 0.0001), snapped(value.a, 0.0001)]
	if value is Basis:
		return {
			"x": _serialize_vector3(value.x),
			"y": _serialize_vector3(value.y),
			"z": _serialize_vector3(value.z),
		}
	if value is bool or value is int or value is float or value is String:
		return value
	if value is NodePath:
		return str(value)
	if value is Array:
		var arr := []
		for item: Variant in value:
			arr.append(_serialize_value(item))
		return arr
	return str(value)
