class_name PcAppShell
extends Control

const WORKSPACES := ["live", "templates", "sessions", "diagnostics"]

@onready var status_bar: PcStatusBar = $Margin/VBox/StatusBar
@onready var nav_rail: PcNavRail = $Margin/VBox/Body/NavRail
@onready var live_workspace: PcLiveWorkspace = $Margin/VBox/Body/WorkspaceStack/LiveWorkspace
@onready var template_workspace: PcTemplateWorkspace = $Margin/VBox/Body/WorkspaceStack/TemplateWorkspace
@onready var session_workspace: PcSessionWorkspace = $Margin/VBox/Body/WorkspaceStack/SessionWorkspace
@onready var diagnostics_workspace: PcDiagnosticsWorkspace = $Margin/VBox/Body/WorkspaceStack/DiagnosticsWorkspace

var _workspaces: Dictionary = {}
var _current_workspace: String = "live"


func _ready() -> void:
	_workspaces = {
		"live": live_workspace,
		"templates": template_workspace,
		"sessions": session_workspace,
		"diagnostics": diagnostics_workspace,
	}
	nav_rail.workspace_selected.connect(set_workspace)
	set_workspace(_current_workspace)


func set_shell_status(shell_status: Dictionary) -> void:
	status_bar.set_status(shell_status)


func set_workspace(workspace_id: String) -> void:
	if not _workspaces.has(workspace_id):
		workspace_id = "live"
	_current_workspace = workspace_id
	nav_rail.set_current_workspace(workspace_id)
	for key in _workspaces.keys():
		var workspace := _workspaces[key] as Control
		workspace.visible = key == workspace_id


func get_current_workspace() -> String:
	return _current_workspace


func set_live_data(live_data: Dictionary) -> void:
	live_workspace.set_data(live_data)


func set_session_data(session_data: Dictionary) -> void:
	session_workspace.set_data(session_data)


func set_template_data(template_data: Dictionary) -> void:
	template_workspace.set_data(template_data)


func set_diagnostics_data(diagnostics_data: Dictionary) -> void:
	diagnostics_workspace.set_data(diagnostics_data)
