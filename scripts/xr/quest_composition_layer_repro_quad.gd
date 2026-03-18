extends OpenXRCompositionLayerQuad

@onready var _viewport: SubViewport = $SubViewport


func _ready() -> void:
	_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	layer_viewport = _viewport
	QuestRuntimeLog.boot("REPRO_UI_LAYER_READY", {
		"quad_size": [quad_size.x, quad_size.y],
		"viewport_size": [_viewport.size.x, _viewport.size.y],
	})


func get_scene_root() -> Control:
	var root := get_node_or_null("SubViewport/QuestFlightPanel") as Control
	if root != null:
		return root
	return get_node_or_null("SubViewport/QuestPanel") as Control
