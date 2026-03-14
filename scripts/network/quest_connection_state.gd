class_name QuestConnectionState
extends RefCounted

const STATE_XR_STARTING := "xr_starting"
const STATE_WAITING_FOR_BEACON := "waiting_for_beacon"
const STATE_BEACON_RECEIVED := "beacon_received"
const STATE_TCP_CONNECTING := "tcp_connecting"
const STATE_TCP_CONNECTED := "tcp_connected"
const STATE_PROFILE_SYNCED := "profile_synced"
const STATE_MANUAL_OVERRIDE := "manual_override"
const STATE_ERROR := "error"

var state: String = STATE_XR_STARTING
var last_error: String = ""
var server_host: String = ""
var control_port: int = 0
var telemetry_port: int = 0


func set_xr_starting() -> void:
	state = STATE_XR_STARTING
	last_error = ""


func set_waiting_for_beacon() -> void:
	state = STATE_WAITING_FOR_BEACON
	last_error = ""


func set_beacon_received(host: String, new_control_port: int, new_telemetry_port: int) -> void:
	state = STATE_BEACON_RECEIVED
	server_host = host
	control_port = new_control_port
	telemetry_port = new_telemetry_port
	last_error = ""


func set_tcp_connecting(host: String, new_control_port: int, new_telemetry_port: int) -> void:
	state = STATE_TCP_CONNECTING
	server_host = host
	control_port = new_control_port
	telemetry_port = new_telemetry_port
	last_error = ""


func set_tcp_connected(host: String, new_control_port: int, new_telemetry_port: int) -> void:
	state = STATE_TCP_CONNECTED
	server_host = host
	control_port = new_control_port
	telemetry_port = new_telemetry_port
	last_error = ""


func set_profile_synced() -> void:
	state = STATE_PROFILE_SYNCED
	last_error = ""


func set_manual_override(host: String, new_control_port: int, new_telemetry_port: int) -> void:
	state = STATE_MANUAL_OVERRIDE
	server_host = host
	control_port = new_control_port
	telemetry_port = new_telemetry_port
	last_error = ""


func set_error(message: String) -> void:
	state = STATE_ERROR
	last_error = message


func to_dict() -> Dictionary:
	return {
		"state": state,
		"last_error": last_error,
		"server_host": server_host,
		"control_port": control_port,
		"telemetry_port": telemetry_port,
	}
