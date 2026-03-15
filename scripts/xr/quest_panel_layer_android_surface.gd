extends OpenXRCompositionLayerQuad

const XR_RUNTIME_OCULUS_PREFIX := "Oculus"
const XR_RUNTIME_PICO_PREFIX := "Pico"

@onready var _viewport: SubViewport = $SubViewport
@onready var _scene_root: Control = $SubViewport/QuestPanel

var _xr_interface: OpenXRInterface
var _session_connected := false
var _surface_ready := false


func _ready() -> void:
	_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	QuestRuntimeLog.boot("UI_LAYER_READY", {
		"android_surface_size": [android_surface_size.x, android_surface_size.y],
		"quad_size": [quad_size.x, quad_size.y],
		"use_android_surface": use_android_surface,
		"viewport_size": [_viewport.size.x, _viewport.size.y],
	})
	QuestRuntimeLog.info("UI_LAYER_VIEWPORT_ATTACHED", {
		"viewport_path": str(_viewport.get_path()),
	})
	QuestRuntimeLog.info("UI_LAYER_SCENE_ATTACHED", {
		"scene_root": _scene_root.name,
		"viewport_path": str(_viewport.get_path()),
	})
	set_process(true)
	_try_bind_xr_interface()


func _process(_delta: float) -> void:
	if _surface_ready:
		set_process(false)
		return

	_try_bind_xr_interface()
	_try_draw_android_surface()


func get_scene_root() -> Control:
	return _scene_root


func _try_bind_xr_interface() -> void:
	if _session_connected:
		return

	var xr_interface := XRServer.find_interface("OpenXR") as OpenXRInterface
	if xr_interface == null or not xr_interface.is_initialized():
		return

	_xr_interface = xr_interface
	_session_connected = true
	_configure_vertical_flip()
	if not _xr_interface.session_begun.is_connected(_on_openxr_session_begun):
		_xr_interface.session_begun.connect(_on_openxr_session_begun)
	QuestRuntimeLog.info("UI_LAYER_ANDROID_SURFACE_WAITING", {
		"runtime_name": str(_xr_interface.get_system_info().get("XRRuntimeName", "")),
	})


func _configure_vertical_flip() -> void:
	if _xr_interface == null:
		return

	var system_info := _xr_interface.get_system_info()
	var xr_runtime_name := str(system_info.get("XRRuntimeName", ""))
	var renderer := RenderingServer.get_current_rendering_driver_name()
	var flip_composition_layer := false

	if xr_runtime_name.begins_with(XR_RUNTIME_OCULUS_PREFIX):
		# Quest 3 testing in this project shows the Android surface upright only without
		# the OpenGL vertical-flip workaround that some examples apply.
		flip_composition_layer = false
	elif xr_runtime_name.begins_with(XR_RUNTIME_PICO_PREFIX):
		flip_composition_layer = renderer == "vulkan"

	set("XR_FB_composition_layer_image_layout/vertical_flip", flip_composition_layer)
	QuestRuntimeLog.info("UI_LAYER_ANDROID_SURFACE_FLIP_CONFIGURED", {
		"renderer": renderer,
		"runtime_name": xr_runtime_name,
		"vertical_flip": flip_composition_layer,
	})


func _on_openxr_session_begun() -> void:
	_try_draw_android_surface()


func _try_draw_android_surface() -> void:
	if _surface_ready or not use_android_surface or not OS.has_feature("android"):
		return

	var android_surface = get_android_surface()
	if android_surface == null:
		return

	if _draw_test_pattern(android_surface):
		_surface_ready = true
		QuestRuntimeLog.info("UI_LAYER_ANDROID_SURFACE_READY", {
			"android_surface_size": [android_surface_size.x, android_surface_size.y],
		})


func _draw_test_pattern(surface) -> bool:
	var Paint = JavaClassWrapper.wrap("android.graphics.Paint")
	var canvas = surface.lockCanvas(null)
	if canvas == null:
		QuestRuntimeLog.error("UI_LAYER_ANDROID_SURFACE_DRAW_FAILED", {
			"reason": "lock_canvas_returned_null",
		})
		return false

	var width := float(android_surface_size.x)
	var height := float(android_surface_size.y)

	var background = Paint.Paint()
	background.setARGB(255, 20, 24, 31)
	canvas.drawRect(0.0, 0.0, width, height, background)

	var banner = Paint.Paint()
	banner.setARGB(255, 32, 94, 166)
	canvas.drawRect(48.0, 48.0, width - 48.0, 240.0, banner)

	var accent = Paint.Paint()
	accent.setARGB(255, 240, 199, 93)
	canvas.drawRect(48.0, 300.0, width - 48.0, 360.0, accent)

	var text = Paint.Paint()
	text.setARGB(255, 245, 248, 255)
	text.setAntiAlias(true)
	text.setTextSize(72.0)
	canvas.drawText("Android surface layer test", 72.0, 154.0, text)

	var subtext = Paint.Paint()
	subtext.setARGB(255, 211, 219, 230)
	subtext.setAntiAlias(true)
	subtext.setTextSize(44.0)
	canvas.drawText("If this renders, Android-surface composition layers work here.", 72.0, 440.0, subtext)
	canvas.drawText("The hidden Godot panel is still running behind this test surface.", 72.0, 516.0, subtext)

	surface.unlockCanvasAndPost(canvas)

	var exc = JavaClassWrapper.get_exception()
	if exc:
		QuestRuntimeLog.error("UI_LAYER_ANDROID_SURFACE_DRAW_FAILED", {
			"exception": str(exc),
		})
		return false

	return true
