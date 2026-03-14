extends "res://addons/gut/test.gd"

const QuestConnectionState = preload("res://scripts/network/quest_connection_state.gd")


func test_connection_state_tracks_expected_transitions() -> void:
	var state := QuestConnectionState.new()

	state.set_xr_starting()
	assert_eq(state.state, QuestConnectionState.STATE_XR_STARTING)

	state.set_waiting_for_beacon()
	assert_eq(state.state, QuestConnectionState.STATE_WAITING_FOR_BEACON)

	state.set_beacon_received("192.168.0.2", 9101, 9100)
	assert_eq(state.state, QuestConnectionState.STATE_BEACON_RECEIVED)
	assert_eq(state.server_host, "192.168.0.2")

	state.set_tcp_connecting("192.168.0.2", 9101, 9100)
	assert_eq(state.state, QuestConnectionState.STATE_TCP_CONNECTING)

	state.set_tcp_connected("192.168.0.2", 9101, 9100)
	assert_eq(state.state, QuestConnectionState.STATE_TCP_CONNECTED)

	state.set_profile_synced()
	assert_eq(state.state, QuestConnectionState.STATE_PROFILE_SYNCED)

	state.set_manual_override("192.168.0.8", 9101, 9100)
	assert_eq(state.state, QuestConnectionState.STATE_MANUAL_OVERRIDE)
	assert_eq(state.server_host, "192.168.0.8")

	state.set_error("bind failed")
	assert_eq(state.state, QuestConnectionState.STATE_ERROR)
	assert_eq(state.last_error, "bind failed")
