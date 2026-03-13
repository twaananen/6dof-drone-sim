extends Control

const MappingEngine = preload("res://scripts/mapping/mapping_engine.gd")
const MappingTemplate = preload("res://scripts/mapping/mapping_template.gd")
const FailsafeSupervisor = preload("res://scripts/mapping/failsafe_supervisor.gd")
const SourceDeriver = preload("res://scripts/telemetry/source_deriver.gd")
const TemplateManager = preload("res://scripts/ui/template_manager.gd")

@onready var telemetry_receiver: Node = $TelemetryReceiver
@onready var control_server: Node = $ControlServer
@onready var backend: Node = $LinuxGamepadBackend
@onready var quest_status_panel: QuestStatusPanel = $VBox/StatusPanel
@onready var template_editor: TemplateEditor = $VBox/MainSplit/TemplateEditor
@onready var raw_panel: TelemetryPanel = $VBox/MainSplit/Panels/RawPanel
@onready var derived_panel: TelemetryPanel = $VBox/MainSplit/Panels/DerivedPanel
@onready var output_panel: TelemetryPanel = $VBox/MainSplit/Panels/OutputPanel

var _source_deriver: SourceDeriver = SourceDeriver.new()
var _mapping_engine: MappingEngine = MappingEngine.new()
var _failsafe: FailsafeSupervisor = FailsafeSupervisor.new()
var _template_manager: TemplateManager = TemplateManager.new()
var _active_template: MappingTemplate
var _last_timestamp_usec: int = 0
var _last_outputs: Dictionary = {}
var _was_failsafe_active: bool = true
var _last_status_send_usec: int = 0
var _pending_raw_state: Dictionary
var _pending_derived: Dictionary
var _pending_outputs: Dictionary
var _ui_dirty: bool = false


func _ready() -> void:
	telemetry_receiver.state_received.connect(_on_state_received)
	control_server.message_received.connect(_on_control_message)
	control_server.client_connected.connect(_send_initial_status)
	template_editor.template_applied.connect(_apply_template)
	template_editor.template_saved.connect(_on_template_saved)
	template_editor.template_deleted.connect(_on_template_deleted)

	var template_names: PackedStringArray = _template_manager.list_names()
	if template_names.size() > 0:
		var template: MappingTemplate = _template_manager.load_template(template_names[0])
		if template != null:
			_apply_template(template)


func _process(_delta: float) -> void:
	if _active_template == null:
		return
	quest_status_panel.set_status(
		control_server.has_client(),
		_active_template.template_name,
		_failsafe.is_active(),
		telemetry_receiver.packets_received
	)
	if _ui_dirty:
		_ui_dirty = false
		raw_panel.set_payload("Raw Telemetry", _serialize_state_for_ui(_pending_raw_state))
		derived_panel.set_payload("Derived Sources", _pending_derived)
		output_panel.set_payload("Mapped Outputs", _pending_outputs)


func _on_state_received(state: Dictionary) -> void:
	if state.get("event_flags", 0) & RawControllerState.EVENT_CALIBRATE:
		_source_deriver.calibrate_from_state(state)
		_mapping_engine.clear_integrators()
	if state.get("event_flags", 0) & RawControllerState.EVENT_RECENTER:
		_source_deriver.reset_calibration()
		_mapping_engine.clear_integrators()

	_failsafe.note_state(state)
	var dt: float = 0.0
	var timestamp_usec := int(state.get("timestamp_usec", 0))
	if _last_timestamp_usec > 0 and timestamp_usec > _last_timestamp_usec:
		dt = float(timestamp_usec - _last_timestamp_usec) / 1000000.0
	_last_timestamp_usec = timestamp_usec

	var derived: Dictionary = _source_deriver.derive_sources(state)
	var outputs: Dictionary
	if not _failsafe.update():
		if _was_failsafe_active:
			_mapping_engine.clear_integrators()
			_was_failsafe_active = false
		outputs = _mapping_engine.process(derived, dt)
	else:
		_was_failsafe_active = true
		_mapping_engine.clear_integrators()
		outputs = _mapping_engine.neutral_outputs()

	_last_outputs = outputs
	backend.push_state(outputs)

	_pending_raw_state = state
	_pending_derived = derived
	_pending_outputs = outputs
	_ui_dirty = true

	var now_usec := Time.get_ticks_usec()
	if now_usec - _last_status_send_usec > 100000:
		_send_status_update()
		_last_status_send_usec = now_usec


func _apply_template(template: MappingTemplate) -> void:
	_active_template = template
	_mapping_engine.set_template(template)
	template_editor.set_template(template)
	_send_initial_status()


func _on_template_saved(template: MappingTemplate) -> void:
	_template_manager.refresh()
	_apply_template(template)


func _on_template_deleted(_template_name: String) -> void:
	_template_manager.refresh()
	_send_initial_status()


func _on_control_message(message: Dictionary) -> void:
	match str(message.get("type", "")):
		"hello":
			_send_initial_status()
		"select_template":
			var name: String = str(message.get("template_name", ""))
			var template: MappingTemplate = _template_manager.load_template(name)
			if template != null:
				_apply_template(template)
		"apply_tuning":
			_apply_global_tuning(message.get("settings", {}))


func _apply_global_tuning(settings: Dictionary) -> void:
	if _active_template == null:
		return
	for output_name in _active_template.outputs.keys():
		var output: Dictionary = _active_template.outputs[output_name]
		if "sensitivity" in settings:
			output["sensitivity"] = settings["sensitivity"]
		if "deadzone" in settings:
			output["deadzone"] = settings["deadzone"]
		if "expo" in settings:
			output["expo"] = settings["expo"]
		if "integrator_gain" in settings:
			for binding in output["bindings"]:
				if binding.get("mode", "") == "integrator":
					binding["weight"] = settings["integrator_gain"]
	_mapping_engine.set_template(_active_template)
	_send_status_update()


func _send_initial_status() -> void:
	if not control_server.has_client():
		return
	control_server.send_message({
		"type": "hello_ack",
		"backend": "linux",
		"failsafe_timeout_ms": _failsafe.timeout_usec / 1000,
	})
	control_server.send_message({
		"type": "template_catalog",
		"templates": _template_manager.list_names(),
	})
	_send_status_update()


func _send_status_update() -> void:
	if not control_server.has_client():
		return
	control_server.send_message({
		"type": "active_template",
		"template_name": _active_template.template_name if _active_template != null else "",
	})
	control_server.send_message({
		"type": "status",
		"failsafe_active": _failsafe.is_active(),
		"packets_received": telemetry_receiver.packets_received,
		"backend_available": backend.is_available(),
		"last_outputs": _last_outputs,
	})


func _serialize_state_for_ui(state: Dictionary) -> Dictionary:
	return {
		"sequence": state.get("sequence", 0),
		"timestamp_usec": state.get("timestamp_usec", 0),
		"tracking_valid": state.get("tracking_valid", false),
		"event_flags": state.get("event_flags", 0),
		"buttons": state.get("buttons", 0),
		"grip_position": str(state.get("grip_position", Vector3.ZERO)),
		"grip_orientation": str(state.get("grip_orientation", Quaternion.IDENTITY)),
		"linear_velocity": str(state.get("linear_velocity", Vector3.ZERO)),
		"angular_velocity": str(state.get("angular_velocity", Vector3.ZERO)),
		"trigger": state.get("trigger", 0.0),
		"grip": state.get("grip", 0.0),
		"thumbstick": str(state.get("thumbstick", Vector2.ZERO)),
	}
