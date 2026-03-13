extends "res://addons/gut/test.gd"

const FailsafeSupervisor = preload("res://scripts/mapping/failsafe_supervisor.gd")


func test_no_initial_packet_trips_failsafe() -> void:
	var supervisor := FailsafeSupervisor.new()
	assert_true(supervisor.update(0), "Should be in failsafe with no packets received")


func test_valid_packet_clears_failsafe() -> void:
	var supervisor := FailsafeSupervisor.new()
	supervisor.note_state({"tracking_valid": true}, 1000)
	assert_false(supervisor.update(1000), "Should clear failsafe after valid packet")


func test_timeout_trips_after_200ms() -> void:
	var supervisor := FailsafeSupervisor.new()
	supervisor.timeout_usec = 50000
	supervisor.note_state({"tracking_valid": true}, 1000)
	assert_false(supervisor.update(1000), "Should not trip immediately")
	assert_true(supervisor.update(51001), "Should trip after timeout")


func test_tracking_invalid_does_not_update_timestamp() -> void:
	var supervisor := FailsafeSupervisor.new()
	supervisor.note_state({"tracking_valid": false}, 1000)
	assert_true(supervisor.update(1000), "Invalid tracking should not prevent failsafe")


func test_force_trip_and_clear() -> void:
	var supervisor := FailsafeSupervisor.new()
	supervisor.note_state({"tracking_valid": true}, 1000)
	supervisor.force_trip()
	assert_true(supervisor.is_active())
	supervisor.clear()
	assert_false(supervisor.is_active())
	assert_false(supervisor.update(1000), "Clear should leave the supervisor clear at the current tick")
