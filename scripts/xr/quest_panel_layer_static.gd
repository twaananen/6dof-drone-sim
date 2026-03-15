extends OpenXRCompositionLayerQuad

@onready var _viewport: SubViewport = $SubViewport
@onready var _scene_root: Control = $SubViewport/QuestPanel


func _ready() -> void:
	_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	layer_viewport = _viewport
	QuestRuntimeLog.boot("UI_LAYER_READY", {
		"quad_size": [quad_size.x, quad_size.y],
		"viewport_size": [_viewport.size.x, _viewport.size.y],
	})
	QuestRuntimeLog.info("UI_LAYER_VIEWPORT_ATTACHED", {
		"viewport_path": str(_viewport.get_path()),
	})
	QuestRuntimeLog.info("UI_LAYER_SCENE_ATTACHED", {
		"scene_root": _scene_root.name,
		"viewport_path": str(_viewport.get_path()),
	})


func get_scene_root() -> Control:
	return _scene_root
