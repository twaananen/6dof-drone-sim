extends "res://addons/gut/test.gd"

const FailsafeSupervisor = preload("res://scripts/mapping/failsafe_supervisor.gd")


func test_no_initial_packet_trips_failsafe() -> void:
	var supervisor := FailsafeSupervisor.new()
	assert_true(supervisor.update(), "Should be in failsafe with no packets received")


func test_valid_packet_clears_failsafe() -> void:
	var supervisor := FailsafeSupervisor.new()
	supervisor.note_state({"tracking_valid": true})
	assert_false(supervisor.update(), "Should clear failsafe after valid packet")


func test_timeout_trips_after_200ms() -> void:
	var supervisor := FailsafeSupervisor.new()
	supervisor.timeout_usec = 50000
	supervisor.note_state({"tracking_valid": true})
	assert_false(supervisor.update(), "Should not trip immediately")
	await get_tree().create_timer(0.1).timeout
	assert_true(supervisor.update(), "Should trip after timeout")


func test_tracking_invalid_does_not_update_timestamp() -> void:
	var supervisor := FailsafeSupervisor.new()
	supervisor.note_state({"tracking_valid": false})
	assert_true(supervisor.update(), "Invalid tracking should not prevent failsafe")


func test_force_trip_and_clear() -> void:
	var supervisor := FailsafeSupervisor.new()
	supervisor.note_state({"tracking_valid": true})
	supervisor.force_trip()
	assert_true(supervisor.is_active())
	supervisor.clear()
	assert_false(supervisor.is_active())
