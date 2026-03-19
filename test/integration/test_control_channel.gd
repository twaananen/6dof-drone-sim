extends "res://addons/gut/test.gd"

const ControlServer = preload("res://scripts/network/control_server.gd")
const ControlClient = preload("res://scripts/network/control_client.gd")

var server: Node
var client: Node
var received_messages: Array = []
var client_received_messages: Array = []
var port: int = 0


func before_each() -> void:
	received_messages.clear()
	client_received_messages.clear()
	var server_info := await _spawn_server()
	server = server_info["server"]
	port = server_info["port"]
	server.message_received.connect(func(message): received_messages.append(message))

	client = ControlClient.new()
	client.server_host = "127.0.0.1"
	client.server_port = port
	client.reconnect_delay_sec = 0.05
	add_child_autofree(client)
	client.message_received.connect(func(message): client_received_messages.append(message))

	await wait_until(
		func(): return server.has_client() and client.is_socket_connected(),
		1.0,
		"Timed out waiting for control client to connect"
	)


func after_each() -> void:
	if client != null:
		client.queue_free()
		client = null
	if server != null:
		server.queue_free()
		server = null
	await wait_process_frames(2)


func _spawn_server() -> Dictionary:
	for candidate in range(31000, 32100):
		var candidate_server := ControlServer.new()
		candidate_server.listen_port = candidate
		add_child_autofree(candidate_server)
		await wait_process_frames(1)
		if candidate_server.get_listen_error() == OK:
			return {
				"server": candidate_server,
				"port": candidate,
			}
		candidate_server.queue_free()
		await wait_process_frames(1)
	fail_test("Could not find a free TCP port for control channel tests")
	return {
		"server": null,
		"port": 31000,
	}


func test_client_can_send_hello_message() -> void:
	client.send_message({
		"type": "hello",
		"client": "quest"
	})

	await wait_until(func(): return received_messages.size() == 1, 1.0, "Timed out waiting for control message")

	assert_eq(received_messages.size(), 1)
	assert_eq(received_messages[0]["type"], "hello")


func test_client_reconnects_after_disconnect() -> void:
	client._client.disconnect_from_host()

	await wait_until(
		func(): return not client.is_socket_connected(),
		1.0,
		"Timed out waiting for control client to disconnect"
	)
	await wait_until(
		func(): return client.is_socket_connected() and server.has_client(),
		1.0,
		"Timed out waiting for control client to reconnect"
	)

	assert_true(client.is_socket_connected())


func test_client_receives_multiple_status_messages_in_order() -> void:
	server.send_message({
		"type": "hello_ack",
		"backend": "linux",
	})
	server.send_message({
		"type": "session_profile",
		"profile": {
			"mode": "experimental_stream",
			"stream_client": "steam_link",
		},
	})
	server.send_message({
		"type": "status",
		"failsafe_active": false,
	})

	await wait_until(
		func(): return client_received_messages.size() == 3,
		1.0,
		"Timed out waiting for server-to-client control messages"
	)

	assert_eq(client_received_messages[0]["type"], "hello_ack")
	assert_eq(client_received_messages[1]["type"], "session_profile")
	assert_eq(client_received_messages[2]["type"], "status")


func test_client_receives_structured_template_catalog_and_active_template() -> void:
	server.send_message({
		"type": "template_catalog",
		"templates": [
			{
				"template_id": "bundled.rate_direct",
				"display_name": "Rate Direct",
				"summary": "Direct manual rate template.",
			}
		],
	})
	server.send_message({
		"type": "active_template",
		"template_id": "bundled.rate_direct",
		"template_summary": {
			"template_id": "bundled.rate_direct",
			"display_name": "Rate Direct",
		},
		"template": {
			"template_id": "bundled.rate_direct",
			"display_name": "Rate Direct",
			"outputs": {},
		},
	})

	await wait_until(
		func(): return client_received_messages.size() == 2,
		1.0,
		"Timed out waiting for template catalog messages"
	)

	assert_eq(client_received_messages[0]["type"], "template_catalog")
	assert_eq(client_received_messages[0]["templates"][0]["template_id"], "bundled.rate_direct")
	assert_eq(client_received_messages[1]["type"], "active_template")
	assert_eq(client_received_messages[1]["template_summary"]["display_name"], "Rate Direct")
