extends "res://addons/gut/test.gd"


func _build_test_tree() -> Node3D:
	var root := Node3D.new()
	root.name = "TestRoot"
	root.position = Vector3(1.0, 2.0, 3.0)

	var child_a := Node3D.new()
	child_a.name = "ChildA"
	child_a.visible = false
	root.add_child(child_a)

	var child_b := Node.new()
	child_b.name = "ChildB"
	root.add_child(child_b)

	var grandchild := MeshInstance3D.new()
	grandchild.name = "Grandchild"
	child_a.add_child(grandchild)

	return root


func test_walk_tree_returns_hierarchy() -> void:
	var root := _build_test_tree()
	add_child_autofree(root)
	await wait_process_frames(1)

	var result := SceneTreeInspector.walk_tree(root, 3)

	assert_eq(result["node_count"], 4)
	assert_false(result["truncated"])
	assert_eq(result["tree"]["name"], "TestRoot")
	assert_eq(result["tree"]["type"], "Node3D")
	assert_eq(result["tree"]["child_count"], 2)

	var children: Array = result["tree"]["children"]
	assert_eq(children.size(), 2)
	assert_eq(children[0]["name"], "ChildA")
	assert_eq(children[0]["visible"], false)
	assert_eq(children[1]["name"], "ChildB")
	assert_eq(children[1]["type"], "Node")


func test_walk_tree_includes_transform_for_node3d() -> void:
	var root := _build_test_tree()
	add_child_autofree(root)
	await wait_process_frames(1)

	var result := SceneTreeInspector.walk_tree(root, 1)
	var tree: Dictionary = result["tree"]

	assert_true(tree.has("transform"))
	assert_true(tree.has("global_transform"))
	var origin: Array = tree["transform"]["origin"]
	assert_eq(origin[0], 1.0)
	assert_eq(origin[1], 2.0)
	assert_eq(origin[2], 3.0)


func test_walk_tree_does_not_include_transform_for_node() -> void:
	var root := _build_test_tree()
	add_child_autofree(root)
	await wait_process_frames(1)

	var result := SceneTreeInspector.walk_tree(root, 2)
	var child_b: Dictionary = result["tree"]["children"][1]

	assert_eq(child_b["name"], "ChildB")
	assert_false(child_b.has("transform"))
	assert_false(child_b.has("visible"))


func test_walk_tree_respects_depth_limit() -> void:
	var root := _build_test_tree()
	add_child_autofree(root)
	await wait_process_frames(1)

	var result := SceneTreeInspector.walk_tree(root, 1)
	var child_a: Dictionary = result["tree"]["children"][0]

	assert_eq(child_a["child_count"], 1)
	assert_eq(child_a["children"].size(), 0)


func test_walk_tree_depth_zero_returns_root_only() -> void:
	var root := _build_test_tree()
	add_child_autofree(root)
	await wait_process_frames(1)

	var result := SceneTreeInspector.walk_tree(root, 0)

	assert_eq(result["node_count"], 1)
	assert_eq(result["tree"]["children"].size(), 0)
	assert_eq(result["tree"]["child_count"], 2)


func test_walk_tree_truncates_at_max_nodes() -> void:
	var root := Node.new()
	root.name = "BigRoot"
	for i in range(SceneTreeInspector.MAX_NODES + 10):
		var child := Node.new()
		child.name = "Child%d" % i
		root.add_child(child)
	add_child_autofree(root)
	await wait_process_frames(1)

	var result := SceneTreeInspector.walk_tree(root, 1)

	assert_true(result["truncated"])
	assert_true(result["node_count"] <= SceneTreeInspector.MAX_NODES + 1)


func test_inspect_node_returns_properties() -> void:
	var root := _build_test_tree()
	add_child_autofree(root)
	await wait_process_frames(1)

	var result := SceneTreeInspector.inspect_node(root, ["visible", "position", "name"])

	assert_eq(result["type"], "Node3D")
	assert_eq(result["properties"]["visible"], true)
	assert_eq(result["properties"]["name"], "TestRoot")
	var pos: Array = result["properties"]["position"]
	assert_eq(pos[0], 1.0)
	assert_eq(pos[1], 2.0)
	assert_eq(pos[2], 3.0)


func test_serialize_value_handles_types() -> void:
	assert_eq(SceneTreeInspector._serialize_value(Vector3(1, 2, 3)), [1.0, 2.0, 3.0])
	assert_eq(SceneTreeInspector._serialize_value(Vector2(4, 5)), [4.0, 5.0])
	assert_eq(SceneTreeInspector._serialize_value(Color(1, 0, 0, 1)), [1.0, 0.0, 0.0, 1.0])
	assert_eq(SceneTreeInspector._serialize_value(true), true)
	assert_eq(SceneTreeInspector._serialize_value(42), 42)
	assert_eq(SceneTreeInspector._serialize_value("hello"), "hello")
	assert_eq(SceneTreeInspector._serialize_value(NodePath("some/path")), "some/path")
