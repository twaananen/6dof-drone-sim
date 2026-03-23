class_name PcNavRail
extends PanelContainer

signal workspace_selected(workspace_id)

@onready var live_button: Button = $Margin/VBox/LiveButton
@onready var templates_button: Button = $Margin/VBox/TemplatesButton
@onready var sessions_button: Button = $Margin/VBox/SessionsButton
@onready var diagnostics_button: Button = $Margin/VBox/DiagnosticsButton

var _buttons: Dictionary = {}
var _current_workspace: String = "live"


func _ready() -> void:
	_buttons = {
		"live": live_button,
		"templates": templates_button,
		"sessions": sessions_button,
		"diagnostics": diagnostics_button,
	}
	live_button.pressed.connect(_on_workspace_pressed.bind("live"))
	templates_button.pressed.connect(_on_workspace_pressed.bind("templates"))
	sessions_button.pressed.connect(_on_workspace_pressed.bind("sessions"))
	diagnostics_button.pressed.connect(_on_workspace_pressed.bind("diagnostics"))
	set_current_workspace(_current_workspace)


func set_current_workspace(workspace_id: String) -> void:
	_current_workspace = workspace_id if _buttons.has(workspace_id) else "live"
	for key in _buttons.keys():
		var button := _buttons[key] as Button
		button.disabled = key == _current_workspace


func _on_workspace_pressed(workspace_id: String) -> void:
	if workspace_id == _current_workspace:
		return
	set_current_workspace(workspace_id)
	workspace_selected.emit(workspace_id)
