class_name TemplateGuidePanel
extends PanelContainer

@onready var title_label: Label = $Margin/VBox/Title
@onready var body_label: RichTextLabel = $Margin/VBox/Body


func set_summary(summary: Dictionary) -> void:
	title_label.text = str(summary.get("display_name", "Template Guide"))
	var lines := PackedStringArray()
	var overview := str(summary.get("summary", ""))
	if not overview.is_empty():
		lines.append(overview)
	lines.append("")
	lines.append("Scheme: %s" % str(summary.get("control_scheme_label", summary.get("control_scheme", ""))))
	lines.append("Difficulty: %s" % str(summary.get("difficulty_label", summary.get("difficulty", ""))))
	lines.append("")
	for line in summary.get("mode_lines", []):
		lines.append(str(line))
	for line in summary.get("assist_lines", []):
		lines.append(str(line))
	if not summary.get("binding_lines", []).is_empty():
		lines.append("")
		lines.append("Bindings:")
		for line in summary.get("binding_lines", []):
			lines.append("- %s" % str(line))
	if not summary.get("warnings", []).is_empty():
		lines.append("")
		lines.append("Warnings:")
		for line in summary.get("warnings", []):
			lines.append("- %s" % str(line))
	if not summary.get("usage_tips", []).is_empty():
		lines.append("")
		lines.append("Usage Tips:")
		for line in summary.get("usage_tips", []):
			lines.append("- %s" % str(line))
	body_label.text = "\n".join(lines)
