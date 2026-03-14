class_name DiscoveryProtocol
extends RefCounted

const SERVICE_NAME := "6dof-drone-pc"
const DISCOVERY_PORT := 9102


static func build_payload(control_port: int, telemetry_port: int) -> PackedByteArray:
	return JSON.stringify({
		"service": SERVICE_NAME,
		"control_port": control_port,
		"telemetry_port": telemetry_port,
	}).to_utf8_buffer()


static func parse_packet(data: PackedByteArray) -> Dictionary:
	if data.is_empty():
		return {
			"valid": false,
			"error": "empty_packet",
		}

	var json := JSON.new()
	if json.parse(data.get_string_from_utf8()) != OK:
		return {
			"valid": false,
			"error": "invalid_json",
		}
	if typeof(json.data) != TYPE_DICTIONARY:
		return {
			"valid": false,
			"error": "invalid_payload",
		}

	var message: Dictionary = json.data
	if str(message.get("service", "")) != SERVICE_NAME:
		return {
			"valid": false,
			"error": "wrong_service",
		}

	return {
		"valid": true,
		"service": SERVICE_NAME,
		"control_port": int(message.get("control_port", 9101)),
		"telemetry_port": int(message.get("telemetry_port", 9100)),
	}
