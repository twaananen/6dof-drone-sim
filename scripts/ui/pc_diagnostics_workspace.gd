class_name PcDiagnosticsWorkspace
extends Control

@onready var connection_summary_label: Label = $Margin/Scroll/VBox/ConnectionCard/ConnectionVBox/ConnectionSummaryLabel
@onready var quest_details_label: Label = $Margin/Scroll/VBox/ConnectionCard/ConnectionVBox/QuestDetailsLabel
@onready var raw_json_edit: TextEdit = $Margin/Scroll/VBox/InputCard/InputVBox/RawJsonEdit
@onready var derived_json_edit: TextEdit = $Margin/Scroll/VBox/InputCard/InputVBox/DerivedJsonEdit
@onready var output_json_edit: TextEdit = $Margin/Scroll/VBox/OutputCard/OutputVBox/OutputJsonEdit
@onready var debug_actions_label: Label = $Margin/Scroll/VBox/DebugCard/DebugVBox/DebugActionsLabel


func set_data(diagnostics_data: Dictionary) -> void:
	var status: Dictionary = diagnostics_data.get("status", {})
	var quest_runtime: Dictionary = status.get("quest_runtime_diagnostics", {})
	connection_summary_label.text = "Control %s | Backend %s | Packets %d / %d dropped | Beacon %d" % [
		"connected" if bool(status.get("connected", false)) else "disconnected",
		"ready" if bool(status.get("backend_available", false)) else "offline",
		int(status.get("packets_received", 0)),
		int(status.get("packets_dropped", 0)),
		int(status.get("beacon_packets_sent", 0)),
	]
	quest_details_label.text = "XR %s | Discovery %s | Quest control %s | Target %s" % [
		str(quest_runtime.get("xr_state", "xr_starting")),
		str(quest_runtime.get("discovery_state", "waiting")),
		"active" if bool(quest_runtime.get("control_active", false)) else "paused",
		str(quest_runtime.get("control_target_host", "n/a")),
	]
	raw_json_edit.text = JSON.stringify(diagnostics_data.get("raw", {}), "\t")
	derived_json_edit.text = JSON.stringify(diagnostics_data.get("derived", {}), "\t")
	output_json_edit.text = JSON.stringify(diagnostics_data.get("outputs", {}), "\t")

	var debug_actions: Array = diagnostics_data.get("debug_actions", [])
	if debug_actions.is_empty():
		debug_actions_label.text = "No debug actions right now."
	else:
		var lines := PackedStringArray()
		for action in debug_actions:
			lines.append("• %s" % str(action))
		debug_actions_label.text = "\n".join(lines)
