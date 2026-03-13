extends "res://addons/gut/test.gd"

const RawControllerState = preload("res://scripts/telemetry/raw_controller_state.gd")
const TelemetrySender = preload("res://scripts/network/telemetry_sender.gd")
const TelemetryReceiver = preload("res://scripts/network/telemetry_receiver.gd")


var sender: Node
var receiver: Node


func before_each() -> void:
    receiver = Node.new()
    receiver.set_script(TelemetryReceiver)
    receiver.listen_port = 19100
    add_child_autofree(receiver)

    sender = Node.new()
    sender.set_script(TelemetrySender)
    sender.target_host = "127.0.0.1"
    sender.target_port = 19100
    add_child_autofree(sender)

    await wait_process_frames(2)


func test_sender_and_receiver_exchange_state() -> void:
    var state := RawControllerState.default_state()
    state["tracking_valid"] = true
    state["trigger"] = 0.9
    sender.send_state(state)

    await wait_until(func(): return int(receiver.get_stats()["packets_received"]) == 1, 1.0, "Timed out waiting for UDP packet")

    assert_true(receiver.latest_state["tracking_valid"])
    assert_almost_eq(receiver.latest_state["trigger"], 0.9, 0.001)
