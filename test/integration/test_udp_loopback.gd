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
    receiver.restart_gap_usec = 1000
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


func test_receiver_accepts_sender_restart_after_idle_gap() -> void:
    var first_state := RawControllerState.default_state()
    first_state["tracking_valid"] = true
    first_state["trigger"] = 0.2
    sender.send_state(first_state)

    await wait_until(func(): return int(receiver.get_stats()["packets_received"]) == 1, 1.0, "Timed out waiting for first UDP packet")

    var restarted_sender := Node.new()
    restarted_sender.set_script(TelemetrySender)
    restarted_sender.target_host = "127.0.0.1"
    restarted_sender.target_port = 19100
    add_child_autofree(restarted_sender)

    await wait_process_frames(2)
    await get_tree().create_timer(0.01).timeout

    var restarted_state := RawControllerState.default_state()
    restarted_state["tracking_valid"] = true
    restarted_state["trigger"] = 0.7
    restarted_sender.send_state(restarted_state)

    await wait_until(func(): return int(receiver.get_stats()["packets_received"]) == 2, 1.0, "Timed out waiting for restarted sender packet")

    assert_eq(receiver.latest_state["sequence"], 0)
    assert_almost_eq(receiver.latest_state["trigger"], 0.7, 0.001)
