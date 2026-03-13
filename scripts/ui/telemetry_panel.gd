class_name TelemetryPanel
extends PanelContainer

@onready var title_label: Label = $VBox/Title
@onready var payload_label: RichTextLabel = $VBox/Payload


func set_payload(title: String, payload: Dictionary) -> void:
    title_label.text = title
    payload_label.text = JSON.stringify(payload, "\t")

