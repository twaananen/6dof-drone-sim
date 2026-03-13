extends "res://addons/gut/test.gd"

const FailsafeSupervisor = preload("res://scripts/mapping/failsafe_supervisor.gd")


func test_timeout_trips_after_200ms() -> void:
    var supervisor := FailsafeSupervisor.new()
    supervisor.note_state({"tracking_valid": true, "timestamp_usec": 1000})
    assert_false(supervisor.update(200000))
    assert_true(supervisor.update(250001))
