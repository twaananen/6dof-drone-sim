class_name OpenXRBootstrap
extends RefCounted

const STATE_XR_STARTING := "xr_starting"
const STATE_XR_READY := "xr_ready"


func initialize(interface: Variant, viewport: Variant) -> Dictionary:
	var diagnostics := {
		"state": STATE_XR_STARTING,
		"ok": false,
		"error": "",
		"alpha_blend_supported": false,
		"render_model_plugin_available": ClassDB.class_exists("OpenXRFbRenderModel"),
		"passthrough_plugin_available": ClassDB.class_exists("OpenXRFbPassthroughGeometry"),
		"passthrough_extension_available": Engine.has_singleton("OpenXRFbPassthroughExtension"),
	}

	if interface == null:
		diagnostics["error"] = "OpenXR interface missing"
		return diagnostics

	if not interface.is_initialized():
		var initialized: bool = bool(interface.initialize())
		if not initialized:
			diagnostics["error"] = "OpenXR failed to initialize"
			return diagnostics

	if not interface.is_initialized():
		diagnostics["error"] = "OpenXR failed to initialize"
		return diagnostics

	viewport.use_xr = true
	viewport.transparent_bg = true
	var modes: Array = interface.get_supported_environment_blend_modes()
	var alpha_supported := XRInterface.XR_ENV_BLEND_MODE_ALPHA_BLEND in modes
	diagnostics["alpha_blend_supported"] = alpha_supported
	if alpha_supported:
		interface.environment_blend_mode = XRInterface.XR_ENV_BLEND_MODE_ALPHA_BLEND
	else:
		diagnostics["error"] = "OpenXR alpha blend passthrough unavailable"

	diagnostics["ok"] = true
	diagnostics["state"] = STATE_XR_READY
	return diagnostics
