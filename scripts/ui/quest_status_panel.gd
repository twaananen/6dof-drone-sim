class_name QuestStatusPanel
extends PanelContainer

@onready var title_label: Label = $VBox/Title
@onready var payload_label: Label = $VBox/Payload


func set_status(connected: bool, template_name: String, failsafe_active: bool, packets_received: int) -> void:
    title_label.text = "Quest Status"
    payload_label.text = "Connected: %s | Template: %s | Failsafe: %s | Packets: %d" % [
        "yes" if connected else "no",
        template_name,
        "active" if failsafe_active else "clear",
        packets_received,
    ]

