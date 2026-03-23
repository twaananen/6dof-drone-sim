class_name PcStatusBar
extends PanelContainer

@onready var template_label: Label = $Margin/HBox/TemplateCard/TemplateLabel
@onready var workflow_label: Label = $Margin/HBox/WorkflowCard/WorkflowLabel
@onready var connection_label: Label = $Margin/HBox/ConnectionCard/ConnectionLabel
@onready var backend_label: Label = $Margin/HBox/BackendCard/BackendLabel
@onready var packets_label: Label = $Margin/HBox/PacketsCard/PacketsLabel
@onready var failsafe_label: Label = $Margin/HBox/FailsafeCard/FailsafeLabel


func set_status(shell_status: Dictionary) -> void:
	template_label.text = "Template: %s" % str(shell_status.get("template_name", "No template"))
	workflow_label.text = "Workflow: %s" % str(shell_status.get("workflow_label", "Passthrough Standalone"))
	_apply_chip(
		connection_label,
		"Connection: %s" % ("Connected" if bool(shell_status.get("connected", false)) else "Disconnected"),
		"success" if bool(shell_status.get("connected", false)) else "danger"
	)
	_apply_chip(
		backend_label,
		"Backend: %s" % ("Ready" if bool(shell_status.get("backend_available", false)) else "Offline"),
		"success" if bool(shell_status.get("backend_available", false)) else "warning"
	)
	_apply_chip(
		packets_label,
		"Packets: %d / %d dropped" % [
			int(shell_status.get("packets_received", 0)),
			int(shell_status.get("packets_dropped", 0)),
		],
		"warning" if int(shell_status.get("packets_dropped", 0)) > 0 else "neutral"
	)
	_apply_chip(
		failsafe_label,
		"Failsafe: %s" % ("Active" if bool(shell_status.get("failsafe_active", false)) else "Clear"),
		"danger" if bool(shell_status.get("failsafe_active", false)) else "success"
	)


func _apply_chip(label: Label, text: String, tone: String) -> void:
	label.text = text
	var panel := label.get_parent() as PanelContainer
	var style := StyleBoxFlat.new()
	style.content_margin_left = 12.0
	style.content_margin_top = 8.0
	style.content_margin_right = 12.0
	style.content_margin_bottom = 8.0
	style.corner_radius_top_left = 14
	style.corner_radius_top_right = 14
	style.corner_radius_bottom_left = 14
	style.corner_radius_bottom_right = 14
	match tone:
		"success":
			style.bg_color = Color("213c34")
			style.border_color = Color("7ed957")
		"warning":
			style.bg_color = Color("3b3021")
			style.border_color = Color("ffb454")
		"danger":
			style.bg_color = Color("3a2527")
			style.border_color = Color("ff7b72")
		_:
			style.bg_color = Color("1d2732")
			style.border_color = Color("4b687f")
	style.border_width_left = 1
	style.border_width_top = 1
	style.border_width_right = 1
	style.border_width_bottom = 1
	panel.add_theme_stylebox_override("panel", style)
