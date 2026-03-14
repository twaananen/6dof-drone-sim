extends "res://addons/gut/test.gd"

const DiscoveryProtocol = preload("res://scripts/network/discovery_protocol.gd")


func test_build_payload_round_trips_through_parser() -> void:
	var payload := DiscoveryProtocol.build_payload(9101, 9100)
	var parsed := DiscoveryProtocol.parse_packet(payload)

	assert_true(parsed["valid"])
	assert_eq(parsed["service"], DiscoveryProtocol.SERVICE_NAME)
	assert_eq(parsed["control_port"], 9101)
	assert_eq(parsed["telemetry_port"], 9100)


func test_parse_packet_rejects_malformed_json() -> void:
	var parsed := DiscoveryProtocol.parse_packet("{not-json".to_utf8_buffer())

	assert_false(parsed["valid"])
	assert_eq(parsed["error"], "invalid_json")


func test_parse_packet_rejects_wrong_service() -> void:
	var payload := JSON.stringify({
		"service": "another-service",
		"control_port": 1,
		"telemetry_port": 2,
	}).to_utf8_buffer()
	var parsed := DiscoveryProtocol.parse_packet(payload)

	assert_false(parsed["valid"])
	assert_eq(parsed["error"], "wrong_service")
