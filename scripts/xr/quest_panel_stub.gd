extends Node3D

@onready var _scene_root: Control = $SubViewport/QuestPanel


func get_scene_root() -> Control:
	return _scene_root
