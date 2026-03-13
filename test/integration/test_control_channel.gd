extends "res://addons/gut/test.gd"

const ControlServer = preload("res://scripts/network/control_server.gd")
const ControlClient = preload("res://scripts/network/control_client.gd")

var server: Node
var client: Node
var received_messages: Array = []


func before_each() -> void:
    received_messages.clear()

    server = Node.new()
    server.set_script(ControlServer)
    server.listen_port = 19101
    add_child_autofree(server)
    server.message_received.connect(func(message): received_messages.append(message))

    client = Node.new()
    client.set_script(ControlClient)
    client.server_host = "127.0.0.1"
    client.server_port = 19101
    add_child_autofree(client)

    await wait_until(
        func(): return server.has_client() and client.is_socket_connected(),
        1.0,
        "Timed out waiting for control client to connect"
    )


func test_client_can_send_hello_message() -> void:
    client.send_message({
        "type": "hello",
        "client": "quest"
    })

    await wait_until(func(): return received_messages.size() == 1, 1.0, "Timed out waiting for control message")

    assert_eq(received_messages.size(), 1)
    assert_eq(received_messages[0]["type"], "hello")
