extends Node3D

@onready var controller_reader: Node = $ControllerReader
@onready var telemetry_sender: Node = $TelemetrySender
@onready var control_client: Node = $ControlClient
@onready var template_select: OptionButton = $CanvasLayer/Panel/VBox/TemplateSelect
@onready var status_label: Label = $CanvasLayer/Panel/VBox/StatusLabel
@onready var calibrate_button: Button = $CanvasLayer/Panel/VBox/Buttons/CalibrateButton
@onready var recenter_button: Button = $CanvasLayer/Panel/VBox/Buttons/RecenterButton
@onready var sensitivity_slider: HSlider = $CanvasLayer/Panel/VBox/Tuning/SensitivitySlider
@onready var deadzone_slider: HSlider = $CanvasLayer/Panel/VBox/Tuning/DeadzoneSlider
@onready var expo_slider: HSlider = $CanvasLayer/Panel/VBox/Tuning/ExpoSlider
@onready var integrator_slider: HSlider = $CanvasLayer/Panel/VBox/Tuning/IntegratorSlider

var _active_template_name: String = ""
var _last_status: Dictionary = {}


func _ready() -> void:
    calibrate_button.pressed.connect(func(): controller_reader.request_calibration())
    recenter_button.pressed.connect(func(): controller_reader.request_recenter())
    template_select.item_selected.connect(_on_template_selected)
    sensitivity_slider.value_changed.connect(_on_tuning_changed)
    deadzone_slider.value_changed.connect(_on_tuning_changed)
    expo_slider.value_changed.connect(_on_tuning_changed)
    integrator_slider.value_changed.connect(_on_tuning_changed)
    control_client.connected.connect(_on_control_connected)
    control_client.message_received.connect(_on_control_message)
    _init_xr()


func _physics_process(_delta: float) -> void:
    telemetry_sender.send_state(controller_reader.read_state())
    _update_status_label()


func _init_xr() -> void:
    var xr_interface: XRInterface = XRServer.find_interface("OpenXR")
    if xr_interface == null:
        push_warning("OpenXR interface missing")
        return
    if not xr_interface.is_initialized():
        xr_interface.initialize()
    if xr_interface.is_initialized():
        get_viewport().use_xr = true


func _on_control_connected() -> void:
    control_client.send_message({
        "type": "hello",
        "client": "quest",
    })


func _on_control_message(message: Dictionary) -> void:
    match str(message.get("type", "")):
        "template_catalog":
            _load_catalog(message.get("templates", []))
        "active_template":
            _active_template_name = str(message.get("template_name", ""))
        "status":
            _last_status = message


func _load_catalog(templates: Array) -> void:
    var previous: String = _active_template_name
    template_select.clear()
    for item in templates:
        template_select.add_item(str(item))
    if previous.is_empty() and template_select.item_count > 0:
        template_select.select(0)
    else:
        for index in range(template_select.item_count):
            if template_select.get_item_text(index) == previous:
                template_select.select(index)
                break


func _on_template_selected(index: int) -> void:
    control_client.send_message({
        "type": "select_template",
        "template_name": template_select.get_item_text(index),
    })


func _on_tuning_changed(_value: float) -> void:
    control_client.send_message({
        "type": "apply_tuning",
        "settings": {
            "sensitivity": sensitivity_slider.value,
            "deadzone": deadzone_slider.value,
            "expo": expo_slider.value,
            "integrator_gain": integrator_slider.value,
        },
    })


func _update_status_label() -> void:
    status_label.text = "Template: %s | Failsafe: %s | Packets: %s" % [
        _active_template_name,
        "active" if _last_status.get("failsafe_active", true) else "clear",
        str(_last_status.get("packets_received", 0)),
    ]
