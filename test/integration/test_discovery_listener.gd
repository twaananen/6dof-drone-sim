extends "res://addons/gut/test.gd"

const DiscoveryListener = preload("res://scripts/network/discovery_listener.gd")


func test_second_listener_reports_bind_failure_on_same_port() -> void:
	var port := await _find_free_udp_port()
	var first := DiscoveryListener.new()
	first.listen_port = port
	add_child_autofree(first)
	await wait_process_frames(1)
	assert_eq(first.get_bind_error(), OK)

	var second := DiscoveryListener.new()
	second.listen_port = port
	add_child_autofree(second)
	await wait_process_frames(1)

	assert_ne(second.get_bind_error(), OK)


func _find_free_udp_port() -> int:
	for candidate in range(22100, 22200):
		var listener := DiscoveryListener.new()
		listener.listen_port = candidate
		add_child_autofree(listener)
		await wait_process_frames(1)
		if listener.get_bind_error() == OK:
			listener.queue_free()
			await wait_process_frames(1)
			return candidate
		listener.queue_free()
		await wait_process_frames(1)
	fail_test("Could not find a free UDP port for discovery listener tests")
	return 22100
