extends Node3D

const OpenXRBootstrap = preload("res://scripts/xr/openxr_bootstrap.gd")

@onready var world_environment: WorldEnvironment = $WorldEnvironment

var _xr_bootstrap: OpenXRBootstrap = OpenXRBootstrap.new()
var _xr_diagnostics: Dictionary = {}


func _ready() -> void:
	QuestRuntimeLog.boot("BOOTSTRAP_SMOKE_READY_BEGIN", {
		"scene": "quest_bootstrap_smoke_repro",
	})

	_xr_bootstrap.world_environment = world_environment
	_xr_bootstrap.prefer_passthrough_on_startup = true
	_xr_bootstrap.fallback_to_opaque_on_passthrough_failure = true
	_xr_diagnostics = _xr_bootstrap.initialize(XRServer.find_interface("OpenXR"), get_viewport())
	if bool(_xr_diagnostics.get("ok", false)):
		QuestRuntimeLog.boot("BOOTSTRAP_SMOKE_XR_INIT_OK", {
			"display_refresh_rate": float(_xr_diagnostics.get("display_refresh_rate", 0.0)),
			"passthrough_enabled": bool(_xr_diagnostics.get("passthrough_enabled", false)),
		})
	else:
		QuestRuntimeLog.error("BOOTSTRAP_SMOKE_XR_INIT_FAILED", {
			"error": str(_xr_diagnostics.get("error", "")),
		})

	QuestRuntimeLog.boot("BOOTSTRAP_SMOKE_READY_COMPLETE", {
		"xr_state": str(_xr_diagnostics.get("state", OpenXRBootstrap.STATE_XR_STARTING)),
	})
