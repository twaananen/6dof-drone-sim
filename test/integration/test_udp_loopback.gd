extends "res://addons/gut/test.gd"

const RawControllerState = preload("res://scripts/telemetry/raw_controller_state.gd")
const TelemetrySender = preload("res://scripts/network/telemetry_sender.gd")
const TelemetryReceiver = preload("res://scripts/network/telemetry_receiver.gd")


var sender: Node
var receiver: Node
var port: int = 0


func before_each() -> void:
	var receiver_info := await _spawn_receiver()
	receiver = receiver_info["receiver"]
	port = receiver_info["port"]

	sender = TelemetrySender.new()
	sender.target_host = "127.0.0.1"
	sender.target_port = port
	add_child_autofree(sender)

	await wait_process_frames(2)


func _spawn_receiver() -> Dictionary:
	for candidate in range(19100, 20100):
		var candidate_receiver := TelemetryReceiver.new()
		candidate_receiver.listen_port = candidate
		candidate_receiver.restart_gap_usec = 1000
		add_child_autofree(candidate_receiver)
		await wait_process_frames(1)
		if candidate_receiver.get_bind_error() == OK:
			return {
				"receiver": candidate_receiver,
				"port": candidate,
			}
		candidate_receiver.queue_free()
		await wait_process_frames(1)
	fail_test("Could not find a free UDP port for loopback tests")
	return {
		"receiver": null,
		"port": 19100,
	}


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

	var restarted_sender := TelemetrySender.new()
	restarted_sender.target_host = "127.0.0.1"
	restarted_sender.target_port = port
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
