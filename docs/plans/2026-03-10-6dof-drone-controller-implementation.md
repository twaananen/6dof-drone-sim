# 6DOF VR Drone Controller - Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Build a Godot 4.x project that reads Quest 3 controller 6DOF data, maps it through a configurable mapping engine, sends mapped axes over UDP to a Linux PC, and feeds them into a uinput virtual gamepad for drone simulators.

**Architecture:** Single Godot project with three export targets (Quest 3 / Linux / macOS). Quest side: XR controller tracking + mapping engine + config UI + UDP sender. PC side: UDP receiver + uinput virtual gamepad + status UI. A standalone C helper binary handles uinput on Linux, receiving axis data via localhost UDP from the Godot PC app.

**Tech Stack:** Godot 4.4+ (GDScript), OpenXR, GUT (testing), C (uinput helper), PacketPeerUDP, JSON (templates)

**Design Doc:** `docs/plans/2026-03-10-6dof-drone-controller-design.md`

---

## Prerequisites

Before starting, ensure:
- **Godot 4.4+** installed and in PATH (`godot` command available). Download from https://godotengine.org/download
- On macOS: Xcode command line tools (`xcode-select --install`)
- On Linux: `gcc`, `pkg-config`, and write access to `/dev/uinput` (add user to `input` group or use `sudo`)
- Git configured for commits

Verify: `godot --version` should print `4.4.x` or higher.

---

## Task 1: Project Scaffolding

**Files:**
- Create: `project.godot`
- Create: `.gitignore`
- Create: `.gutconfig.json`
- Create: directory structure
- Download: `addons/gut/` (GUT testing framework)

**Step 1: Create directory structure**

```bash
mkdir -p scenes/shared scripts/{mapping,network,input,ui} templates test/{unit,integration} addons tools
```

**Step 2: Create project.godot**

Create `project.godot`:

```ini
; Engine configuration file.
config_version=5

[application]
config/name="6DOF Drone Controller"
config/features=PackedStringArray("4.4", "Mobile")

[rendering]
renderer/rendering_method="mobile"
```

Note: We do NOT set `run/main_scene` yet. We'll set it per-platform via export presets later. For now, scenes are launched manually.

**Step 3: Create .gitignore**

Create `.gitignore`:

```
# Godot
.godot/
*.translation
export_presets.cfg

# GUT
test_results.xml

# Build artifacts
tools/uinput_helper
*.o
*.so
*.dylib

# OS
.DS_Store
Thumbs.db

# Android build
android/build/
```

**Step 4: Install GUT testing framework**

```bash
# Download GUT 9.5.0 (compatible with Godot 4.4+)
cd addons
curl -L https://github.com/bitwes/Gut/releases/download/v9.5.0/gut_9.5.0.zip -o gut.zip
unzip gut.zip -d .
rm gut.zip
cd ..
```

Verify `addons/gut/plugin.cfg` exists.

**Step 5: Create .gutconfig.json**

Create `.gutconfig.json`:

```json
{
    "dirs": ["res://test/unit/", "res://test/integration/"],
    "include_subdirs": true,
    "prefix": "test_",
    "suffix": ".gd",
    "should_exit": true,
    "log_level": 1
}
```

**Step 6: Create a smoke test to verify GUT works**

Create `test/unit/test_smoke.gd`:

```gdscript
extends GutTest

func test_godot_is_running():
    assert_true(true, "GUT is working")

func test_basic_math():
    assert_eq(2 + 2, 4)
```

**Step 7: Run the smoke test**

```bash
godot --headless -s addons/gut/gut_cmdln.gd
```

Expected: Both tests pass, exit code 0.

**Step 8: Commit**

```bash
git add project.godot .gitignore .gutconfig.json addons/gut/ test/unit/test_smoke.gd
git commit -m "feat: scaffold Godot project with GUT testing"
```

---

## Task 2: Mapping Template Data Model

The mapping template defines how controller inputs map to drone axes. It's a JSON file that can be loaded, saved, and edited.

**Files:**
- Create: `scripts/mapping/mapping_template.gd`
- Test: `test/unit/test_mapping_template.gd`

**Step 1: Write the failing test**

Create `test/unit/test_mapping_template.gd`:

```gdscript
extends GutTest

const MappingTemplate = preload("res://scripts/mapping/mapping_template.gd")


class TestTemplateCreation:
    extends GutTest

    const MappingTemplate = preload("res://scripts/mapping/mapping_template.gd")

    func test_new_template_has_default_axes():
        var t := MappingTemplate.new()
        assert_has(t.axes, "throttle")
        assert_has(t.axes, "yaw")
        assert_has(t.axes, "pitch")
        assert_has(t.axes, "roll")

    func test_default_axis_has_empty_sources():
        var t := MappingTemplate.new()
        assert_eq(t.axes["pitch"]["sources"].size(), 0)

    func test_default_axis_processing_values():
        var t := MappingTemplate.new()
        var axis: Dictionary = t.axes["pitch"]
        assert_eq(axis["dead_zone"], 0.0)
        assert_eq(axis["expo"], 0.0)
        assert_eq(axis["sensitivity"], 1.0)
        assert_eq(axis["invert"], false)


class TestSourceBinding:
    extends GutTest

    const MappingTemplate = preload("res://scripts/mapping/mapping_template.gd")

    func test_add_source_to_axis():
        var t := MappingTemplate.new()
        t.add_source("pitch", "tilt_x", 1.0, "absolute")
        assert_eq(t.axes["pitch"]["sources"].size(), 1)
        assert_eq(t.axes["pitch"]["sources"][0]["source"], "tilt_x")
        assert_eq(t.axes["pitch"]["sources"][0]["weight"], 1.0)
        assert_eq(t.axes["pitch"]["sources"][0]["mode"], "absolute")

    func test_add_multiple_sources():
        var t := MappingTemplate.new()
        t.add_source("throttle", "pos_y", 1.0, "absolute")
        t.add_source("throttle", "pos_z", 0.3, "absolute")
        assert_eq(t.axes["throttle"]["sources"].size(), 2)

    func test_remove_source():
        var t := MappingTemplate.new()
        t.add_source("pitch", "tilt_x", 1.0, "absolute")
        t.add_source("pitch", "pos_z", 0.5, "absolute")
        t.remove_source("pitch", 0)
        assert_eq(t.axes["pitch"]["sources"].size(), 1)
        assert_eq(t.axes["pitch"]["sources"][0]["source"], "pos_z")


class TestSerialization:
    extends GutTest

    const MappingTemplate = preload("res://scripts/mapping/mapping_template.gd")

    func test_to_dict_and_from_dict_roundtrip():
        var t := MappingTemplate.new()
        t.template_name = "test_template"
        t.add_source("pitch", "tilt_x", 1.0, "absolute")
        t.axes["pitch"]["dead_zone"] = 0.05
        t.axes["pitch"]["expo"] = 0.3

        var dict := t.to_dict()
        var t2 := MappingTemplate.new()
        t2.from_dict(dict)

        assert_eq(t2.template_name, "test_template")
        assert_eq(t2.axes["pitch"]["sources"].size(), 1)
        assert_eq(t2.axes["pitch"]["sources"][0]["source"], "tilt_x")
        assert_eq(t2.axes["pitch"]["dead_zone"], 0.05)
        assert_eq(t2.axes["pitch"]["expo"], 0.3)

    func test_save_and_load_json():
        var t := MappingTemplate.new()
        t.template_name = "save_test"
        t.add_source("roll", "tilt_z", 0.8, "velocity")

        var path := "user://test_template.json"
        t.save_to_file(path)

        var t2 := MappingTemplate.new()
        var err := t2.load_from_file(path)
        assert_eq(err, OK)
        assert_eq(t2.template_name, "save_test")
        assert_eq(t2.axes["roll"]["sources"][0]["mode"], "velocity")

        # Cleanup
        DirAccess.remove_absolute(ProjectSettings.globalize_path(path))

    func test_load_nonexistent_file_returns_error():
        var t := MappingTemplate.new()
        var err := t.load_from_file("user://nonexistent.json")
        assert_ne(err, OK)
```

**Step 2: Run test to verify it fails**

```bash
godot --headless -s addons/gut/gut_cmdln.gd -gdir=res://test/unit/ -gtest=test_mapping_template.gd
```

Expected: FAIL (script not found / class not defined)

**Step 3: Implement MappingTemplate**

Create `scripts/mapping/mapping_template.gd`:

```gdscript
class_name MappingTemplate
extends RefCounted

## Name of this template (display name)
var template_name: String = "Untitled"

## Calibration data: center position and orientation
var calibration: Dictionary = {
    "center_position": Vector3.ZERO,
    "center_basis": Basis.IDENTITY,
}

## Per-axis mapping configuration.
## Keys: "throttle", "yaw", "pitch", "roll", "aux1".."aux4"
## Each value is a Dictionary with:
##   sources: Array of {source: String, weight: float, mode: String}
##   dead_zone: float (0.0 to 1.0)
##   expo: float (0.0 to 1.0)
##   sensitivity: float (multiplier)
##   invert: bool
##   range_min: float (source range minimum)
##   range_max: float (source range maximum)
##   output_min: float (output clamp min, default -1.0)
##   output_max: float (output clamp max, default 1.0)
var axes: Dictionary = {}

static var OUTPUT_AXIS_NAMES: PackedStringArray = [
    "throttle", "yaw", "pitch", "roll",
    "aux1", "aux2", "aux3", "aux4"
]

static var VALID_SOURCES: PackedStringArray = [
    "tilt_x", "tilt_y", "tilt_z",
    "pos_x", "pos_y", "pos_z",
    "angvel_x", "angvel_y", "angvel_z",
    "linvel_x", "linvel_y", "linvel_z",
    "trigger", "grip",
    "thumbstick_x", "thumbstick_y",
]

static var VALID_MODES: PackedStringArray = ["absolute", "delta", "velocity"]


func _init():
    for axis_name in OUTPUT_AXIS_NAMES:
        axes[axis_name] = _default_axis()


static func _default_axis() -> Dictionary:
    return {
        "sources": [],
        "dead_zone": 0.0,
        "expo": 0.0,
        "sensitivity": 1.0,
        "invert": false,
        "range_min": -1.0,
        "range_max": 1.0,
        "output_min": -1.0,
        "output_max": 1.0,
    }


func add_source(axis_name: String, source: String, weight: float, mode: String) -> void:
    if axis_name not in axes:
        return
    axes[axis_name]["sources"].append({
        "source": source,
        "weight": weight,
        "mode": mode,
    })


func remove_source(axis_name: String, index: int) -> void:
    if axis_name not in axes:
        return
    var sources: Array = axes[axis_name]["sources"]
    if index >= 0 and index < sources.size():
        sources.remove_at(index)


func to_dict() -> Dictionary:
    # Convert calibration vectors to serializable format
    var cal := {}
    cal["center_position"] = [
        calibration["center_position"].x,
        calibration["center_position"].y,
        calibration["center_position"].z,
    ]
    var b: Basis = calibration["center_basis"]
    cal["center_basis"] = [
        b.x.x, b.x.y, b.x.z,
        b.y.x, b.y.y, b.y.z,
        b.z.x, b.z.y, b.z.z,
    ]
    return {
        "template_name": template_name,
        "calibration": cal,
        "axes": axes.duplicate(true),
    }


func from_dict(dict: Dictionary) -> void:
    template_name = dict.get("template_name", "Untitled")

    # Restore calibration
    if "calibration" in dict:
        var cal: Dictionary = dict["calibration"]
        if "center_position" in cal:
            var p: Array = cal["center_position"]
            calibration["center_position"] = Vector3(p[0], p[1], p[2])
        if "center_basis" in cal:
            var b: Array = cal["center_basis"]
            calibration["center_basis"] = Basis(
                Vector3(b[0], b[1], b[2]),
                Vector3(b[3], b[4], b[5]),
                Vector3(b[6], b[7], b[8]),
            )

    # Restore axes (merge with defaults for missing keys)
    if "axes" in dict:
        for axis_name in OUTPUT_AXIS_NAMES:
            if axis_name in dict["axes"]:
                var loaded: Dictionary = dict["axes"][axis_name]
                var merged: Dictionary = _default_axis()
                for key in loaded:
                    merged[key] = loaded[key]
                axes[axis_name] = merged


func save_to_file(path: String) -> Error:
    var json_string := JSON.stringify(to_dict(), "\t")
    var file := FileAccess.open(path, FileAccess.WRITE)
    if file == null:
        return FileAccess.get_open_error()
    file.store_string(json_string)
    file.close()
    return OK


func load_from_file(path: String) -> Error:
    var file := FileAccess.open(path, FileAccess.READ)
    if file == null:
        return FileAccess.get_open_error()
    var content := file.get_as_text()
    file.close()

    var json := JSON.new()
    var error := json.parse(content)
    if error != OK:
        return error
    from_dict(json.data)
    return OK
```

**Step 4: Run tests to verify they pass**

```bash
godot --headless -s addons/gut/gut_cmdln.gd -gdir=res://test/unit/ -gtest=test_mapping_template.gd
```

Expected: All tests PASS.

**Step 5: Commit**

```bash
git add scripts/mapping/mapping_template.gd test/unit/test_mapping_template.gd
git commit -m "feat: add MappingTemplate data model with JSON serialization"
```

---

## Task 3: Mapping Engine - Core Processing

The mapping engine takes raw input values and a template, and produces mapped output axes. This is the heart of the project.

**Files:**
- Create: `scripts/mapping/mapping_engine.gd`
- Test: `test/unit/test_mapping_engine.gd`

**Step 1: Write failing tests for single-source absolute mapping**

Create `test/unit/test_mapping_engine.gd`:

```gdscript
extends GutTest

const MappingEngine = preload("res://scripts/mapping/mapping_engine.gd")
const MappingTemplate = preload("res://scripts/mapping/mapping_template.gd")


class TestSingleSourceAbsolute:
    extends GutTest

    const MappingEngine = preload("res://scripts/mapping/mapping_engine.gd")
    const MappingTemplate = preload("res://scripts/mapping/mapping_template.gd")

    var engine: MappingEngine
    var template: MappingTemplate

    func before_each():
        engine = MappingEngine.new()
        template = MappingTemplate.new()
        template.add_source("pitch", "tilt_x", 1.0, "absolute")
        engine.set_template(template)

    func test_zero_input_gives_zero_output():
        var inputs := {"tilt_x": 0.0}
        var outputs := engine.process(inputs)
        assert_almost_eq(outputs["pitch"], 0.0, 0.001)

    func test_full_positive_input():
        # tilt_x at range_max (1.0) -> output 1.0
        var inputs := {"tilt_x": 1.0}
        var outputs := engine.process(inputs)
        assert_almost_eq(outputs["pitch"], 1.0, 0.001)

    func test_full_negative_input():
        var inputs := {"tilt_x": -1.0}
        var outputs := engine.process(inputs)
        assert_almost_eq(outputs["pitch"], -1.0, 0.001)

    func test_half_input():
        var inputs := {"tilt_x": 0.5}
        var outputs := engine.process(inputs)
        assert_almost_eq(outputs["pitch"], 0.5, 0.001)

    func test_unmapped_axis_is_zero():
        var inputs := {"tilt_x": 1.0}
        var outputs := engine.process(inputs)
        assert_almost_eq(outputs["throttle"], 0.0, 0.001)

    func test_missing_input_source_treated_as_zero():
        var inputs := {}  # tilt_x not provided
        var outputs := engine.process(inputs)
        assert_almost_eq(outputs["pitch"], 0.0, 0.001)


class TestMultiSourceMixing:
    extends GutTest

    const MappingEngine = preload("res://scripts/mapping/mapping_engine.gd")
    const MappingTemplate = preload("res://scripts/mapping/mapping_template.gd")

    var engine: MappingEngine
    var template: MappingTemplate

    func before_each():
        engine = MappingEngine.new()
        template = MappingTemplate.new()

    func test_two_sources_weighted():
        template.add_source("throttle", "pos_y", 1.0, "absolute")
        template.add_source("throttle", "pos_z", 0.5, "absolute")
        engine.set_template(template)
        var inputs := {"pos_y": 0.6, "pos_z": 0.4}
        var outputs := engine.process(inputs)
        # weighted sum: 0.6*1.0 + 0.4*0.5 = 0.8, clamped to [-1,1]
        assert_almost_eq(outputs["throttle"], 0.8, 0.001)

    func test_weighted_sum_clamped_to_output_range():
        template.add_source("throttle", "pos_y", 1.0, "absolute")
        template.add_source("throttle", "pos_z", 1.0, "absolute")
        engine.set_template(template)
        var inputs := {"pos_y": 1.0, "pos_z": 1.0}
        var outputs := engine.process(inputs)
        # weighted sum: 1.0 + 1.0 = 2.0, clamped to 1.0
        assert_almost_eq(outputs["throttle"], 1.0, 0.001)


class TestDeadZone:
    extends GutTest

    const MappingEngine = preload("res://scripts/mapping/mapping_engine.gd")
    const MappingTemplate = preload("res://scripts/mapping/mapping_template.gd")

    var engine: MappingEngine
    var template: MappingTemplate

    func before_each():
        engine = MappingEngine.new()
        template = MappingTemplate.new()
        template.add_source("pitch", "tilt_x", 1.0, "absolute")
        template.axes["pitch"]["dead_zone"] = 0.1
        engine.set_template(template)

    func test_input_within_dead_zone_gives_zero():
        var outputs := engine.process({"tilt_x": 0.05})
        assert_almost_eq(outputs["pitch"], 0.0, 0.001)

    func test_negative_input_within_dead_zone_gives_zero():
        var outputs := engine.process({"tilt_x": -0.05})
        assert_almost_eq(outputs["pitch"], 0.0, 0.001)

    func test_input_at_dead_zone_boundary_gives_zero():
        var outputs := engine.process({"tilt_x": 0.1})
        assert_almost_eq(outputs["pitch"], 0.0, 0.001)

    func test_input_just_above_dead_zone():
        # Just above 0.1 dead zone should give a small positive value
        var outputs := engine.process({"tilt_x": 0.2})
        assert_gt(outputs["pitch"], 0.0)

    func test_full_input_with_dead_zone_reaches_one():
        # Input at 1.0 with 0.1 dead zone should still reach 1.0
        # (dead zone rescales the remaining range)
        var outputs := engine.process({"tilt_x": 1.0})
        assert_almost_eq(outputs["pitch"], 1.0, 0.001)


class TestExpo:
    extends GutTest

    const MappingEngine = preload("res://scripts/mapping/mapping_engine.gd")
    const MappingTemplate = preload("res://scripts/mapping/mapping_template.gd")

    var engine: MappingEngine
    var template: MappingTemplate

    func before_each():
        engine = MappingEngine.new()
        template = MappingTemplate.new()
        template.add_source("pitch", "tilt_x", 1.0, "absolute")
        engine.set_template(template)

    func test_zero_expo_is_linear():
        template.axes["pitch"]["expo"] = 0.0
        engine.set_template(template)
        var outputs := engine.process({"tilt_x": 0.5})
        assert_almost_eq(outputs["pitch"], 0.5, 0.001)

    func test_full_expo_is_cubic():
        template.axes["pitch"]["expo"] = 1.0
        engine.set_template(template)
        var outputs := engine.process({"tilt_x": 0.5})
        # expo=1.0: output = sign(0.5) * (1.0 * 0.5^3 + 0.0 * 0.5) = 0.125
        assert_almost_eq(outputs["pitch"], 0.125, 0.001)

    func test_expo_at_full_deflection_still_reaches_one():
        template.axes["pitch"]["expo"] = 0.7
        engine.set_template(template)
        var outputs := engine.process({"tilt_x": 1.0})
        assert_almost_eq(outputs["pitch"], 1.0, 0.001)

    func test_expo_is_symmetric_for_negative():
        template.axes["pitch"]["expo"] = 0.5
        engine.set_template(template)
        var pos := engine.process({"tilt_x": 0.5})
        var neg := engine.process({"tilt_x": -0.5})
        assert_almost_eq(pos["pitch"], -neg["pitch"], 0.001)


class TestSensitivityAndInvert:
    extends GutTest

    const MappingEngine = preload("res://scripts/mapping/mapping_engine.gd")
    const MappingTemplate = preload("res://scripts/mapping/mapping_template.gd")

    var engine: MappingEngine
    var template: MappingTemplate

    func before_each():
        engine = MappingEngine.new()
        template = MappingTemplate.new()
        template.add_source("pitch", "tilt_x", 1.0, "absolute")
        engine.set_template(template)

    func test_sensitivity_multiplier():
        template.axes["pitch"]["sensitivity"] = 2.0
        engine.set_template(template)
        var outputs := engine.process({"tilt_x": 0.3})
        assert_almost_eq(outputs["pitch"], 0.6, 0.001)

    func test_sensitivity_clamped_to_output_range():
        template.axes["pitch"]["sensitivity"] = 3.0
        engine.set_template(template)
        var outputs := engine.process({"tilt_x": 0.5})
        assert_almost_eq(outputs["pitch"], 1.0, 0.001)

    func test_invert_flips_sign():
        template.axes["pitch"]["invert"] = true
        engine.set_template(template)
        var outputs := engine.process({"tilt_x": 0.5})
        assert_almost_eq(outputs["pitch"], -0.5, 0.001)


class TestSourceRangeMapping:
    extends GutTest

    const MappingEngine = preload("res://scripts/mapping/mapping_engine.gd")
    const MappingTemplate = preload("res://scripts/mapping/mapping_template.gd")

    var engine: MappingEngine
    var template: MappingTemplate

    func before_each():
        engine = MappingEngine.new()
        template = MappingTemplate.new()
        template.add_source("pitch", "tilt_x", 1.0, "absolute")
        engine.set_template(template)

    func test_custom_range_maps_correctly():
        # Source range -45 to 45 degrees, input at 22.5 -> 0.5 normalized
        template.axes["pitch"]["range_min"] = -45.0
        template.axes["pitch"]["range_max"] = 45.0
        engine.set_template(template)
        var outputs := engine.process({"tilt_x": 22.5})
        assert_almost_eq(outputs["pitch"], 0.5, 0.001)

    func test_input_beyond_range_is_clamped():
        template.axes["pitch"]["range_min"] = -0.5
        template.axes["pitch"]["range_max"] = 0.5
        engine.set_template(template)
        var outputs := engine.process({"tilt_x": 1.0})
        assert_almost_eq(outputs["pitch"], 1.0, 0.001)


class TestDeltaMode:
    extends GutTest

    const MappingEngine = preload("res://scripts/mapping/mapping_engine.gd")
    const MappingTemplate = preload("res://scripts/mapping/mapping_template.gd")

    var engine: MappingEngine
    var template: MappingTemplate

    func before_each():
        engine = MappingEngine.new()
        template = MappingTemplate.new()
        template.add_source("pitch", "tilt_x", 1.0, "delta")
        engine.set_template(template)

    func test_first_frame_is_zero():
        # No previous value, so delta is 0
        var outputs := engine.process({"tilt_x": 0.5})
        assert_almost_eq(outputs["pitch"], 0.0, 0.001)

    func test_delta_between_frames():
        engine.process({"tilt_x": 0.3})
        var outputs := engine.process({"tilt_x": 0.5})
        # delta = 0.5 - 0.3 = 0.2
        assert_almost_eq(outputs["pitch"], 0.2, 0.001)

    func test_no_change_gives_zero():
        engine.process({"tilt_x": 0.5})
        var outputs := engine.process({"tilt_x": 0.5})
        assert_almost_eq(outputs["pitch"], 0.0, 0.001)

    func test_negative_delta():
        engine.process({"tilt_x": 0.5})
        var outputs := engine.process({"tilt_x": 0.3})
        assert_almost_eq(outputs["pitch"], -0.2, 0.001)


class TestVelocityMode:
    extends GutTest

    const MappingEngine = preload("res://scripts/mapping/mapping_engine.gd")
    const MappingTemplate = preload("res://scripts/mapping/mapping_template.gd")

    var engine: MappingEngine
    var template: MappingTemplate

    func before_each():
        engine = MappingEngine.new()
        template = MappingTemplate.new()
        template.add_source("pitch", "tilt_x", 1.0, "velocity")
        engine.set_template(template)

    func test_velocity_uses_delta_divided_by_dt():
        engine.process({"tilt_x": 0.3})
        # dt=0.01 (100Hz), change=0.2, velocity=0.2/0.01=20.0
        # then normalized by range -> will be clamped
        var outputs := engine.process_with_dt({"tilt_x": 0.5}, 0.01)
        # The raw velocity is large; after range normalization it should be meaningful
        assert_ne(outputs["pitch"], 0.0)

    func test_no_change_gives_zero_velocity():
        engine.process({"tilt_x": 0.5})
        var outputs := engine.process_with_dt({"tilt_x": 0.5}, 0.01)
        assert_almost_eq(outputs["pitch"], 0.0, 0.001)
```

**Step 2: Run tests to verify they fail**

```bash
godot --headless -s addons/gut/gut_cmdln.gd -gdir=res://test/unit/ -gtest=test_mapping_engine.gd
```

Expected: FAIL (script not found)

**Step 3: Implement MappingEngine**

Create `scripts/mapping/mapping_engine.gd`:

```gdscript
class_name MappingEngine
extends RefCounted

var _template: MappingTemplate
var _previous_inputs: Dictionary = {}

const MappingTemplate = preload("res://scripts/mapping/mapping_template.gd")


func set_template(template: MappingTemplate) -> void:
    _template = template
    _previous_inputs.clear()


func process(inputs: Dictionary) -> Dictionary:
    return process_with_dt(inputs, 0.01)  # default 100Hz assumption


func process_with_dt(inputs: Dictionary, dt: float) -> Dictionary:
    var outputs: Dictionary = {}

    if _template == null:
        for axis_name in MappingTemplate.OUTPUT_AXIS_NAMES:
            outputs[axis_name] = 0.0
        return outputs

    for axis_name in MappingTemplate.OUTPUT_AXIS_NAMES:
        var axis_config: Dictionary = _template.axes[axis_name]
        var raw_value := _compute_mixed_value(axis_config, inputs, dt)
        var processed := _apply_processing(raw_value, axis_config)
        outputs[axis_name] = processed

    # Store inputs for delta/velocity modes next frame
    _previous_inputs = inputs.duplicate()

    return outputs


func _compute_mixed_value(axis_config: Dictionary, inputs: Dictionary, dt: float) -> float:
    var sources: Array = axis_config["sources"]
    if sources.is_empty():
        return 0.0

    var mixed := 0.0
    for binding in sources:
        var source_name: String = binding["source"]
        var weight: float = binding["weight"]
        var mode: String = binding["mode"]
        var raw: float = inputs.get(source_name, 0.0)

        var value := 0.0
        match mode:
            "absolute":
                value = raw
            "delta":
                var prev: float = _previous_inputs.get(source_name, raw)
                value = raw - prev
            "velocity":
                var prev: float = _previous_inputs.get(source_name, raw)
                if dt > 0.0:
                    value = (raw - prev) / dt
                else:
                    value = 0.0

        mixed += value * weight

    return mixed


func _apply_processing(value: float, axis_config: Dictionary) -> float:
    var range_min: float = axis_config["range_min"]
    var range_max: float = axis_config["range_max"]
    var dead_zone: float = axis_config["dead_zone"]
    var expo: float = axis_config["expo"]
    var sensitivity: float = axis_config["sensitivity"]
    var invert: bool = axis_config["invert"]
    var output_min: float = axis_config["output_min"]
    var output_max: float = axis_config["output_max"]

    # 1. Normalize to -1..1 based on source range
    var range_span := range_max - range_min
    if range_span > 0.0:
        var center := (range_min + range_max) / 2.0
        var half_range := range_span / 2.0
        value = clampf((value - center) / half_range, -1.0, 1.0)

    # 2. Apply dead zone (rescale remaining range to 0..1)
    if dead_zone > 0.0:
        var abs_val := absf(value)
        if abs_val <= dead_zone:
            value = 0.0
        else:
            value = signf(value) * (abs_val - dead_zone) / (1.0 - dead_zone)

    # 3. Apply expo curve: output = sign(x) * (expo * x^3 + (1-expo) * x)
    if expo > 0.0:
        var abs_val := absf(value)
        value = signf(value) * (expo * abs_val * abs_val * abs_val + (1.0 - expo) * abs_val)

    # 4. Apply sensitivity
    value *= sensitivity

    # 5. Apply invert
    if invert:
        value = -value

    # 6. Clamp to output range
    value = clampf(value, output_min, output_max)

    return value
```

**Step 4: Run tests to verify they pass**

```bash
godot --headless -s addons/gut/gut_cmdln.gd -gdir=res://test/unit/ -gtest=test_mapping_engine.gd
```

Expected: All tests PASS.

**Step 5: Commit**

```bash
git add scripts/mapping/mapping_engine.gd test/unit/test_mapping_engine.gd
git commit -m "feat: add MappingEngine with multi-source mixing, dead zone, expo, modes"
```

---

## Task 4: Calibration System

Records a controller's rest position/orientation as the reference center, and offsets all future readings.

**Files:**
- Create: `scripts/mapping/calibration.gd`
- Test: `test/unit/test_calibration.gd`

**Step 1: Write failing tests**

Create `test/unit/test_calibration.gd`:

```gdscript
extends GutTest

const Calibration = preload("res://scripts/mapping/calibration.gd")


func test_uncalibrated_returns_raw_values():
    var cal := Calibration.new()
    var raw := {
        "position": Vector3(0.3, 1.2, -0.5),
        "basis": Basis.IDENTITY,
    }
    var result := cal.apply(raw)
    assert_almost_eq(result["position"], raw["position"], Vector3(0.001, 0.001, 0.001))


func test_calibrate_sets_center():
    var cal := Calibration.new()
    var rest := {
        "position": Vector3(0.3, 1.2, -0.5),
        "basis": Basis.IDENTITY,
    }
    cal.calibrate(rest)
    var result := cal.apply(rest)
    assert_almost_eq(result["position"], Vector3.ZERO, Vector3(0.001, 0.001, 0.001))


func test_calibrated_position_is_relative():
    var cal := Calibration.new()
    cal.calibrate({
        "position": Vector3(0.3, 1.2, -0.5),
        "basis": Basis.IDENTITY,
    })
    var moved := {
        "position": Vector3(0.5, 1.4, -0.3),
        "basis": Basis.IDENTITY,
    }
    var result := cal.apply(moved)
    assert_almost_eq(result["position"], Vector3(0.2, 0.2, 0.2), Vector3(0.001, 0.001, 0.001))


func test_calibrated_orientation_is_relative():
    var cal := Calibration.new()
    # Calibrate at 45 degrees around Y
    var rest_basis := Basis(Vector3.UP, deg_to_rad(45.0))
    cal.calibrate({
        "position": Vector3.ZERO,
        "basis": rest_basis,
    })
    # Tilt to 90 degrees around Y -> relative should be ~45 degrees
    var tilted_basis := Basis(Vector3.UP, deg_to_rad(90.0))
    var result := cal.apply({
        "position": Vector3.ZERO,
        "basis": tilted_basis,
    })
    var euler := result["basis"].get_euler()
    assert_almost_eq(euler.y, deg_to_rad(45.0), 0.01)


func test_to_dict_and_from_dict():
    var cal := Calibration.new()
    cal.calibrate({
        "position": Vector3(1.0, 2.0, 3.0),
        "basis": Basis.IDENTITY,
    })
    var dict := cal.to_dict()
    var cal2 := Calibration.new()
    cal2.from_dict(dict)
    var result := cal2.apply({
        "position": Vector3(1.0, 2.0, 3.0),
        "basis": Basis.IDENTITY,
    })
    assert_almost_eq(result["position"], Vector3.ZERO, Vector3(0.001, 0.001, 0.001))
```

**Step 2: Run tests to verify they fail**

```bash
godot --headless -s addons/gut/gut_cmdln.gd -gdir=res://test/unit/ -gtest=test_calibration.gd
```

Expected: FAIL

**Step 3: Implement Calibration**

Create `scripts/mapping/calibration.gd`:

```gdscript
class_name Calibration
extends RefCounted

var _is_calibrated: bool = false
var _center_position: Vector3 = Vector3.ZERO
var _center_basis_inverse: Basis = Basis.IDENTITY


func calibrate(raw: Dictionary) -> void:
    _center_position = raw["position"]
    _center_basis_inverse = raw["basis"].inverse()
    _is_calibrated = true


func apply(raw: Dictionary) -> Dictionary:
    var position: Vector3 = raw["position"]
    var basis: Basis = raw["basis"]

    if _is_calibrated:
        position = position - _center_position
        basis = _center_basis_inverse * basis

    return {
        "position": position,
        "basis": basis,
    }


func is_calibrated() -> bool:
    return _is_calibrated


func reset() -> void:
    _is_calibrated = false
    _center_position = Vector3.ZERO
    _center_basis_inverse = Basis.IDENTITY


func to_dict() -> Dictionary:
    return {
        "is_calibrated": _is_calibrated,
        "center_position": [_center_position.x, _center_position.y, _center_position.z],
        "center_basis_inverse": [
            _center_basis_inverse.x.x, _center_basis_inverse.x.y, _center_basis_inverse.x.z,
            _center_basis_inverse.y.x, _center_basis_inverse.y.y, _center_basis_inverse.y.z,
            _center_basis_inverse.z.x, _center_basis_inverse.z.y, _center_basis_inverse.z.z,
        ],
    }


func from_dict(dict: Dictionary) -> void:
    _is_calibrated = dict.get("is_calibrated", false)
    if "center_position" in dict:
        var p: Array = dict["center_position"]
        _center_position = Vector3(p[0], p[1], p[2])
    if "center_basis_inverse" in dict:
        var b: Array = dict["center_basis_inverse"]
        _center_basis_inverse = Basis(
            Vector3(b[0], b[1], b[2]),
            Vector3(b[3], b[4], b[5]),
            Vector3(b[6], b[7], b[8]),
        )
```

**Step 4: Run tests to verify they pass**

```bash
godot --headless -s addons/gut/gut_cmdln.gd -gdir=res://test/unit/ -gtest=test_calibration.gd
```

Expected: All tests PASS.

**Step 5: Commit**

```bash
git add scripts/mapping/calibration.gd test/unit/test_calibration.gd
git commit -m "feat: add Calibration system for center-point offset"
```

---

## Task 5: UDP Protocol - Packet Format

Binary packet packing/unpacking. Shared between sender and receiver.

**Files:**
- Create: `scripts/network/protocol.gd`
- Test: `test/unit/test_protocol.gd`

**Step 1: Write failing tests**

Create `test/unit/test_protocol.gd`:

```gdscript
extends GutTest

const Protocol = preload("res://scripts/network/protocol.gd")


class TestPacking:
    extends GutTest

    const Protocol = preload("res://scripts/network/protocol.gd")

    func test_pack_produces_correct_size():
        var axes := [0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0]
        var packet := Protocol.pack_axes(axes, 0, 0, 42)
        # 4 (magic) + 4 (seq) + 8 (timestamp) + 1 (count) + 8*4 (axes) + 2 (buttons) = 51
        assert_eq(packet.size(), 51)

    func test_pack_has_magic_bytes():
        var axes := [0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0]
        var packet := Protocol.pack_axes(axes, 0, 0, 0)
        assert_eq(packet[0], 0x36)  # '6'
        assert_eq(packet[1], 0x44)  # 'D'
        assert_eq(packet[2], 0x4F)  # 'O'
        assert_eq(packet[3], 0x46)  # 'F'


class TestUnpacking:
    extends GutTest

    const Protocol = preload("res://scripts/network/protocol.gd")

    func test_roundtrip():
        var axes := [0.1, -0.5, 0.75, 1.0, 0.0, -1.0, 0.3, 0.0]
        var seq := 42
        var timestamp := 1234567890
        var buttons := 0b0000000000000101  # buttons 0 and 2 pressed
        var packet := Protocol.pack_axes(axes, seq, timestamp, buttons)
        var result := Protocol.unpack_axes(packet)

        assert_eq(result["valid"], true)
        assert_eq(result["sequence"], seq)
        assert_eq(result["timestamp"], timestamp)
        assert_eq(result["buttons"], buttons)
        assert_eq(result["axes"].size(), 8)
        for i in 8:
            assert_almost_eq(result["axes"][i], axes[i], 0.001)

    func test_invalid_magic_returns_invalid():
        var bad_packet := PackedByteArray([0, 0, 0, 0])
        var result := Protocol.unpack_axes(bad_packet)
        assert_eq(result["valid"], false)

    func test_too_short_packet_returns_invalid():
        var result := Protocol.unpack_axes(PackedByteArray([0x36, 0x44]))
        assert_eq(result["valid"], false)


class TestHeartbeat:
    extends GutTest

    const Protocol = preload("res://scripts/network/protocol.gd")

    func test_heartbeat_pack():
        var packet := Protocol.pack_heartbeat()
        assert_eq(packet.size(), 4)

    func test_heartbeat_roundtrip():
        var packet := Protocol.pack_heartbeat()
        assert_eq(Protocol.is_heartbeat(packet), true)

    func test_non_heartbeat():
        var axes := [0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0]
        var packet := Protocol.pack_axes(axes, 0, 0, 0)
        assert_eq(Protocol.is_heartbeat(packet), false)
```

**Step 2: Run tests to verify they fail**

```bash
godot --headless -s addons/gut/gut_cmdln.gd -gdir=res://test/unit/ -gtest=test_protocol.gd
```

Expected: FAIL

**Step 3: Implement Protocol**

Create `scripts/network/protocol.gd`:

```gdscript
class_name Protocol
extends RefCounted

# Magic bytes
const MAGIC := PackedByteArray([0x36, 0x44, 0x4F, 0x46])  # "6DOF"
const HEARTBEAT_MAGIC := PackedByteArray([0x41, 0x4C, 0x49, 0x56])  # "ALIV"

# Header size: magic(4) + sequence(4) + timestamp(8) + axis_count(1) = 17
const HEADER_SIZE := 17
# Buttons field size
const BUTTONS_SIZE := 2


static func pack_axes(axes: Array, sequence: int, timestamp: int, buttons: int) -> PackedByteArray:
    var buf := StreamPeerBuffer.new()
    buf.big_endian = false

    # Magic
    buf.put_data(MAGIC)
    # Sequence
    buf.put_u32(sequence)
    # Timestamp
    buf.put_u64(timestamp)
    # Axis count
    buf.put_u8(axes.size())
    # Axis values
    for val in axes:
        buf.put_float(val)
    # Buttons bitmask
    buf.put_u16(buttons)

    return buf.data_array


static func unpack_axes(packet: PackedByteArray) -> Dictionary:
    if packet.size() < HEADER_SIZE + BUTTONS_SIZE:
        return {"valid": false}

    var buf := StreamPeerBuffer.new()
    buf.big_endian = false
    buf.data_array = packet
    buf.seek(0)

    # Check magic
    var magic_data := buf.get_data(4)
    var magic_bytes: PackedByteArray = magic_data[1]
    if magic_bytes != MAGIC:
        return {"valid": false}

    var sequence := buf.get_u32()
    var timestamp := buf.get_u64()
    var axis_count := buf.get_u8()

    # Verify packet has enough data for axes + buttons
    var expected_size := HEADER_SIZE + axis_count * 4 + BUTTONS_SIZE
    if packet.size() < expected_size:
        return {"valid": false}

    var axes: Array[float] = []
    for i in axis_count:
        axes.append(buf.get_float())

    var buttons := buf.get_u16()

    return {
        "valid": true,
        "sequence": sequence,
        "timestamp": timestamp,
        "axis_count": axis_count,
        "axes": axes,
        "buttons": buttons,
    }


static func pack_heartbeat() -> PackedByteArray:
    return HEARTBEAT_MAGIC


static func is_heartbeat(packet: PackedByteArray) -> bool:
    return packet.size() == 4 and packet == HEARTBEAT_MAGIC
```

**Step 4: Run tests to verify they pass**

```bash
godot --headless -s addons/gut/gut_cmdln.gd -gdir=res://test/unit/ -gtest=test_protocol.gd
```

Expected: All tests PASS.

**Step 5: Commit**

```bash
git add scripts/network/protocol.gd test/unit/test_protocol.gd
git commit -m "feat: add UDP protocol with binary packet packing/unpacking"
```

---

## Task 6: UDP Sender and Receiver

Network layer nodes for Quest (sender) and PC (receiver).

**Files:**
- Create: `scripts/network/udp_sender.gd`
- Create: `scripts/network/udp_receiver.gd`
- Test: `test/integration/test_udp_loopback.gd`

**Step 1: Implement UDP Sender**

Create `scripts/network/udp_sender.gd`:

```gdscript
extends Node

## Target PC IP address
@export var target_host: String = "127.0.0.1"
## Target PC port
@export var target_port: int = 9000

var _peer := PacketPeerUDP.new()
var _sequence: int = 0
var _connected: bool = false
var _heartbeat_received_time: float = 0.0

## Whether we've received a heartbeat from the PC recently
var is_pc_connected: bool = false


func _ready():
    # Bind to any port to receive heartbeats back
    _peer.bind(0)
    _peer.set_dest_address(target_host, target_port)
    _connected = true


func send_axes(axes: Array, buttons: int = 0) -> void:
    if not _connected:
        return
    var timestamp := int(Time.get_unix_time_from_system() * 1_000_000.0)
    var packet := Protocol.pack_axes(axes, _sequence, timestamp, buttons)
    _peer.put_packet(packet)
    _sequence += 1


func _process(_delta):
    # Check for heartbeat replies
    while _peer.get_available_packet_count() > 0:
        var packet := _peer.get_packet()
        if Protocol.is_heartbeat(packet):
            _heartbeat_received_time = Time.get_ticks_msec() / 1000.0
            is_pc_connected = true

    # Mark disconnected if no heartbeat for 3 seconds
    var now := Time.get_ticks_msec() / 1000.0
    if now - _heartbeat_received_time > 3.0:
        is_pc_connected = false


func _exit_tree():
    _peer.close()
```

**Step 2: Implement UDP Receiver**

Create `scripts/network/udp_receiver.gd`:

```gdscript
extends Node

## Port to listen on
@export var listen_port: int = 9000
## Heartbeat interval in seconds
@export var heartbeat_interval: float = 1.0

signal axes_received(axes: Array, buttons: int)
signal connection_changed(connected: bool)

var _peer := PacketPeerUDP.new()
var _sender_ip: String = ""
var _sender_port: int = 0
var _heartbeat_timer: float = 0.0
var _last_receive_time: float = 0.0
var _is_quest_connected: bool = false
var _last_sequence: int = -1
var _packets_received: int = 0
var _packets_dropped: int = 0

## Latest received data
var latest_axes: Array = []
var latest_buttons: int = 0
var is_quest_connected: bool = false


func _ready():
    var err := _peer.bind(listen_port)
    if err != OK:
        push_error("Failed to bind UDP port %d: %s" % [listen_port, error_string(err)])
        return
    print("UDP receiver listening on port %d" % listen_port)


func _process(delta):
    # Receive packets
    while _peer.get_available_packet_count() > 0:
        var packet := _peer.get_packet()
        _sender_ip = _peer.get_packet_ip()
        _sender_port = _peer.get_packet_port()

        var result := Protocol.unpack_axes(packet)
        if result["valid"]:
            _packets_received += 1
            # Detect dropped packets
            if _last_sequence >= 0 and result["sequence"] > _last_sequence + 1:
                _packets_dropped += result["sequence"] - _last_sequence - 1
            _last_sequence = result["sequence"]

            latest_axes = result["axes"]
            latest_buttons = result["buttons"]
            _last_receive_time = Time.get_ticks_msec() / 1000.0
            axes_received.emit(result["axes"], result["buttons"])

    # Connection tracking
    var now := Time.get_ticks_msec() / 1000.0
    var was_connected := _is_quest_connected
    _is_quest_connected = (now - _last_receive_time) < 1.0 if _last_receive_time > 0.0 else false
    is_quest_connected = _is_quest_connected
    if _is_quest_connected != was_connected:
        connection_changed.emit(_is_quest_connected)

    # Send heartbeat back to Quest
    _heartbeat_timer += delta
    if _heartbeat_timer >= heartbeat_interval and _sender_ip != "":
        _heartbeat_timer = 0.0
        _peer.set_dest_address(_sender_ip, _sender_port)
        _peer.put_packet(Protocol.pack_heartbeat())


func get_stats() -> Dictionary:
    return {
        "packets_received": _packets_received,
        "packets_dropped": _packets_dropped,
        "sender_ip": _sender_ip,
        "sender_port": _sender_port,
    }


func _exit_tree():
    _peer.close()
```

**Step 3: Write integration test (loopback)**

Create `test/integration/test_udp_loopback.gd`:

```gdscript
extends GutTest

## Tests UDP sender and receiver talking to each other on localhost.

var sender_node: Node
var receiver_node: Node

const UdpSender = preload("res://scripts/network/udp_sender.gd")
const UdpReceiver = preload("res://scripts/network/udp_receiver.gd")

func before_each():
    # Create receiver first (binds the port)
    receiver_node = Node.new()
    receiver_node.set_script(UdpReceiver)
    receiver_node.listen_port = 19876  # test port
    add_child_autofree(receiver_node)

    # Create sender targeting localhost
    sender_node = Node.new()
    sender_node.set_script(UdpSender)
    sender_node.target_host = "127.0.0.1"
    sender_node.target_port = 19876
    add_child_autofree(sender_node)

    # Give them a frame to initialize
    await wait_frames(2)


func test_send_and_receive_axes():
    var test_axes := [0.1, -0.2, 0.3, -0.4, 0.5, -0.6, 0.7, -0.8]
    sender_node.send_axes(test_axes, 5)

    # Wait for packet to arrive
    await wait_frames(3)

    assert_eq(receiver_node.latest_axes.size(), 8)
    for i in 8:
        assert_almost_eq(receiver_node.latest_axes[i], test_axes[i], 0.001)
    assert_eq(receiver_node.latest_buttons, 5)


func test_connection_detected():
    sender_node.send_axes([0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0])
    await wait_frames(5)
    assert_true(receiver_node.is_quest_connected)
```

**Step 4: Run tests**

```bash
godot --headless -s addons/gut/gut_cmdln.gd -gdir=res://test/ -ginclude_subdirs
```

Expected: All tests PASS (unit and integration).

**Step 5: Commit**

```bash
git add scripts/network/udp_sender.gd scripts/network/udp_receiver.gd test/integration/test_udp_loopback.gd
git commit -m "feat: add UDP sender/receiver with heartbeat and stats"
```

---

## Task 7: XR Controller Reader

Reads Quest controller 6DOF data and converts it to the flat input dictionary the mapping engine expects.

**Files:**
- Create: `scripts/input/xr_controller_reader.gd`

This component can only be fully tested on a Quest 3. No unit test (hardware dependency). It will be integration-tested later via the Quest main scene.

**Step 1: Implement XR Controller Reader**

Create `scripts/input/xr_controller_reader.gd`:

```gdscript
extends Node

## Which hand to read (set the XRController3D node in the inspector)
@export var controller: XRController3D

var _calibration: Calibration = Calibration.new()


## Read all input sources from the controller and return a flat Dictionary
## matching the source names expected by MappingTemplate.
func read_inputs() -> Dictionary:
    if controller == null or not controller.get_has_tracking_data():
        return {}

    var pose: XRPose = controller.get_pose()
    if pose == null:
        return {}

    var raw_position: Vector3 = controller.global_position
    var raw_basis: Basis = controller.global_transform.basis

    # Apply calibration offset
    var calibrated := _calibration.apply({
        "position": raw_position,
        "basis": raw_basis,
    })

    var pos: Vector3 = calibrated["position"]
    var basis: Basis = calibrated["basis"]
    var euler: Vector3 = basis.get_euler()  # radians

    var inputs: Dictionary = {
        # Orientation (tilt) in degrees for more intuitive range values
        "tilt_x": rad_to_deg(euler.x),   # pitch
        "tilt_y": rad_to_deg(euler.y),   # yaw
        "tilt_z": rad_to_deg(euler.z),   # roll
        # Position in meters
        "pos_x": pos.x,
        "pos_y": pos.y,
        "pos_z": pos.z,
        # Velocities
        "angvel_x": pose.angular_velocity.x,
        "angvel_y": pose.angular_velocity.y,
        "angvel_z": pose.angular_velocity.z,
        "linvel_x": pose.linear_velocity.x,
        "linvel_y": pose.linear_velocity.y,
        "linvel_z": pose.linear_velocity.z,
        # Analog inputs
        "trigger": controller.get_float("trigger"),
        "grip": controller.get_float("grip"),
        "thumbstick_x": controller.get_vector2("thumbstick").x,
        "thumbstick_y": controller.get_vector2("thumbstick").y,
    }

    return inputs


## Read button states as a bitmask
func read_buttons() -> int:
    if controller == null:
        return 0
    var buttons := 0
    if controller.is_button_pressed("ax_button"):
        buttons |= (1 << 0)
    if controller.is_button_pressed("by_button"):
        buttons |= (1 << 1)
    if controller.is_button_pressed("trigger_click"):
        buttons |= (1 << 2)
    if controller.is_button_pressed("grip_click"):
        buttons |= (1 << 3)
    if controller.is_button_pressed("thumbstick_click"):
        buttons |= (1 << 4)
    if controller.is_button_pressed("menu_button"):
        buttons |= (1 << 5)
    return buttons


## Calibrate using the current controller position/orientation as center
func calibrate() -> void:
    if controller == null or not controller.get_has_tracking_data():
        return
    _calibration.calibrate({
        "position": controller.global_position,
        "basis": controller.global_transform.basis,
    })


## Get the raw pose data (for UI visualization)
func get_raw_pose() -> Dictionary:
    if controller == null or not controller.get_has_tracking_data():
        return {}
    return {
        "position": controller.global_position,
        "basis": controller.global_transform.basis,
    }


func get_calibration() -> Calibration:
    return _calibration
```

**Step 2: Commit**

```bash
git add scripts/input/xr_controller_reader.gd
git commit -m "feat: add XR controller reader for Quest 6DOF input"
```

---

## Task 8: uinput Helper Binary (Linux)

A standalone C program that creates a virtual gamepad via uinput and receives axis values over localhost UDP.

**Files:**
- Create: `tools/uinput_helper.c`
- Create: `tools/Makefile`

**Step 1: Write uinput helper**

Create `tools/uinput_helper.c`:

```c
/*
 * uinput_helper - Creates a virtual gamepad via Linux uinput.
 * Receives axis values over UDP on localhost and writes them
 * as joystick events.
 *
 * Usage: uinput_helper [port]
 * Default port: 9001
 *
 * Protocol: receives packed floats via UDP.
 *   Packet: [uint8 axis_count] [float32 axis0] [float32 axis1] ... [uint16 buttons]
 *   Axes are in -1.0 to 1.0 range, mapped to ABS range -32767 to 32767.
 */

#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>
#include <fcntl.h>
#include <errno.h>
#include <signal.h>
#include <stdint.h>
#include <linux/uinput.h>
#include <sys/socket.h>
#include <netinet/in.h>
#include <arpa/inet.h>

#define DEFAULT_PORT 9001
#define MAX_AXES 8
#define MAX_BUTTONS 16
#define ABS_MAX_VAL 32767

static volatile int running = 1;

static void sighandler(int sig) {
    (void)sig;
    running = 0;
}

static int abs_codes[MAX_AXES] = {
    ABS_X, ABS_Y, ABS_Z, ABS_RX, ABS_RY, ABS_RZ, ABS_THROTTLE, ABS_RUDDER
};

static int create_uinput_device(void) {
    int fd = open("/dev/uinput", O_WRONLY | O_NONBLOCK);
    if (fd < 0) {
        perror("open /dev/uinput");
        return -1;
    }

    /* Enable EV_ABS for axes */
    if (ioctl(fd, UI_SET_EVBIT, EV_ABS) < 0) goto err;

    /* Enable each axis */
    for (int i = 0; i < MAX_AXES; i++) {
        if (ioctl(fd, UI_SET_ABSBIT, abs_codes[i]) < 0) goto err;
    }

    /* Enable EV_KEY for buttons */
    if (ioctl(fd, UI_SET_EVBIT, EV_KEY) < 0) goto err;
    for (int i = 0; i < MAX_BUTTONS; i++) {
        if (ioctl(fd, UI_SET_KEYBIT, BTN_TRIGGER + i) < 0) goto err;
    }

    /* Set up device description */
    struct uinput_user_dev uidev;
    memset(&uidev, 0, sizeof(uidev));
    snprintf(uidev.name, UINPUT_MAX_NAME_SIZE, "6DOF Drone Controller");
    uidev.id.bustype = BUS_USB;
    uidev.id.vendor  = 0x6D0F;  /* custom */
    uidev.id.product = 0x0001;
    uidev.id.version = 1;

    for (int i = 0; i < MAX_AXES; i++) {
        uidev.absmin[abs_codes[i]] = -ABS_MAX_VAL;
        uidev.absmax[abs_codes[i]] = ABS_MAX_VAL;
        uidev.absfuzz[abs_codes[i]] = 0;
        uidev.absflat[abs_codes[i]] = 0;
    }

    if (write(fd, &uidev, sizeof(uidev)) != sizeof(uidev)) goto err;
    if (ioctl(fd, UI_DEV_CREATE) < 0) goto err;

    printf("Created virtual gamepad: 6DOF Drone Controller\n");
    return fd;

err:
    perror("uinput setup");
    close(fd);
    return -1;
}

static void emit_event(int fd, int type, int code, int value) {
    struct input_event ev;
    memset(&ev, 0, sizeof(ev));
    ev.type = type;
    ev.code = code;
    ev.value = value;
    write(fd, &ev, sizeof(ev));
}

static void emit_sync(int fd) {
    emit_event(fd, EV_SYN, SYN_REPORT, 0);
}

static int create_udp_socket(int port) {
    int sockfd = socket(AF_INET, SOCK_DGRAM, 0);
    if (sockfd < 0) {
        perror("socket");
        return -1;
    }

    struct sockaddr_in addr;
    memset(&addr, 0, sizeof(addr));
    addr.sin_family = AF_INET;
    addr.sin_addr.s_addr = inet_addr("127.0.0.1");
    addr.sin_port = htons(port);

    if (bind(sockfd, (struct sockaddr*)&addr, sizeof(addr)) < 0) {
        perror("bind");
        close(sockfd);
        return -1;
    }

    /* Non-blocking so we can check running flag */
    int flags = fcntl(sockfd, F_GETFL, 0);
    fcntl(sockfd, F_SETFL, flags | O_NONBLOCK);

    return sockfd;
}

int main(int argc, char *argv[]) {
    int port = DEFAULT_PORT;
    if (argc > 1) {
        port = atoi(argv[1]);
    }

    signal(SIGINT, sighandler);
    signal(SIGTERM, sighandler);

    int uinput_fd = create_uinput_device();
    if (uinput_fd < 0) return 1;

    /* Small delay for device to register */
    usleep(200000);

    int sockfd = create_udp_socket(port);
    if (sockfd < 0) {
        close(uinput_fd);
        return 1;
    }

    printf("Listening on 127.0.0.1:%d\n", port);

    uint8_t buf[256];
    while (running) {
        ssize_t n = recv(sockfd, buf, sizeof(buf), 0);
        if (n < 1) {
            if (errno == EAGAIN || errno == EWOULDBLOCK) {
                usleep(1000);  /* 1ms poll */
                continue;
            }
            if (errno == EINTR) continue;
            perror("recv");
            break;
        }

        /* Parse: [uint8 axis_count] [float32 * count] [uint16 buttons] */
        uint8_t axis_count = buf[0];
        if (axis_count > MAX_AXES) axis_count = MAX_AXES;
        size_t expected = 1 + axis_count * 4 + 2;
        if ((size_t)n < expected) continue;

        /* Emit axis events */
        for (int i = 0; i < axis_count; i++) {
            float fval;
            memcpy(&fval, &buf[1 + i * 4], sizeof(float));
            int ival = (int)(fval * ABS_MAX_VAL);
            if (ival > ABS_MAX_VAL) ival = ABS_MAX_VAL;
            if (ival < -ABS_MAX_VAL) ival = -ABS_MAX_VAL;
            emit_event(uinput_fd, EV_ABS, abs_codes[i], ival);
        }

        /* Emit button events */
        uint16_t buttons;
        memcpy(&buttons, &buf[1 + axis_count * 4], sizeof(uint16_t));
        for (int i = 0; i < MAX_BUTTONS; i++) {
            emit_event(uinput_fd, EV_KEY, BTN_TRIGGER + i, (buttons >> i) & 1);
        }

        emit_sync(uinput_fd);
    }

    printf("\nShutting down...\n");
    ioctl(uinput_fd, UI_DEV_DESTROY);
    close(uinput_fd);
    close(sockfd);
    return 0;
}
```

**Step 2: Create Makefile**

Create `tools/Makefile`:

```makefile
CC = gcc
CFLAGS = -Wall -Wextra -O2
TARGET = uinput_helper

.PHONY: all clean

all: $(TARGET)

$(TARGET): uinput_helper.c
	$(CC) $(CFLAGS) -o $@ $<

clean:
	rm -f $(TARGET)
```

**Step 3: Build (Linux only)**

```bash
cd tools && make
```

Expected: `tools/uinput_helper` binary created. On macOS this will fail (no linux headers) - that's expected; this only builds on Linux.

**Step 4: Commit**

```bash
git add tools/uinput_helper.c tools/Makefile
git commit -m "feat: add uinput helper binary for Linux virtual gamepad"
```

---

## Task 9: uinput Writer (GDScript Wrapper)

GDScript that launches the uinput helper and sends axis data to it.

**Files:**
- Create: `scripts/input/uinput_writer.gd`

**Step 1: Implement uinput writer**

Create `scripts/input/uinput_writer.gd`:

```gdscript
extends Node

## Port the uinput helper listens on (localhost)
@export var helper_port: int = 9001
## Path to the uinput_helper binary (relative to executable or absolute)
@export var helper_path: String = ""

var _peer := PacketPeerUDP.new()
var _helper_pid: int = -1
var _is_active: bool = false


func _ready():
    if OS.get_name() != "Linux":
        print("uinput_writer: not on Linux, running in dummy mode")
        return

    _start_helper()
    _setup_udp()


func _start_helper() -> void:
    var path := _resolve_helper_path()
    if path == "":
        push_error("uinput_helper binary not found")
        return

    if not FileAccess.file_exists(path):
        push_error("uinput_helper not found at: %s" % path)
        return

    _helper_pid = OS.create_process(path, [str(helper_port)])
    if _helper_pid <= 0:
        push_error("Failed to start uinput_helper")
        return

    print("Started uinput_helper (PID %d) on port %d" % [_helper_pid, helper_port])
    # Give it time to create the device
    await get_tree().create_timer(0.3).timeout
    _is_active = true


func _resolve_helper_path() -> String:
    if helper_path != "":
        return helper_path
    # Look for the binary relative to the Godot executable
    var exe_dir := OS.get_executable_path().get_base_dir()
    var candidates := [
        exe_dir.path_join("uinput_helper"),
        exe_dir.path_join("tools/uinput_helper"),
        ProjectSettings.globalize_path("res://tools/uinput_helper"),
    ]
    for path in candidates:
        if FileAccess.file_exists(path):
            return path
    return ""


func _setup_udp() -> void:
    _peer.set_dest_address("127.0.0.1", helper_port)


## Send mapped axis values and button state to the uinput helper.
## axes: Array of floats (-1.0 to 1.0), up to 8 values
## buttons: uint16 bitmask
func write_axes(axes: Array, buttons: int = 0) -> void:
    if not _is_active:
        return

    var buf := StreamPeerBuffer.new()
    buf.big_endian = false
    buf.put_u8(axes.size())
    for val in axes:
        buf.put_float(val)
    buf.put_u16(buttons)
    _peer.put_packet(buf.data_array)


func is_active() -> bool:
    return _is_active


func _exit_tree():
    _peer.close()
    if _helper_pid > 0:
        OS.kill(_helper_pid)
        print("Stopped uinput_helper (PID %d)" % _helper_pid)
```

**Step 2: Commit**

```bash
git add scripts/input/uinput_writer.gd
git commit -m "feat: add uinput writer that manages helper binary lifecycle"
```

---

## Task 10: PC Main Scene

The PC app: receives UDP from Quest, forwards to uinput, shows status.

**Files:**
- Create: `scenes/pc_main.tscn` (via script, since .tscn is text-based)
- Create: `scripts/pc_main.gd`

**Step 1: Create PC main script**

Create `scripts/pc_main.gd`:

```gdscript
extends Control

@onready var receiver: Node = $UdpReceiver
@onready var writer: Node = $UinputWriter
@onready var status_label: Label = $VBoxContainer/StatusLabel
@onready var axes_label: Label = $VBoxContainer/AxesLabel
@onready var stats_label: Label = $VBoxContainer/StatsLabel

const UdpReceiver = preload("res://scripts/network/udp_receiver.gd")
const UinputWriter = preload("res://scripts/input/uinput_writer.gd")

var _update_timer: float = 0.0


func _ready():
    receiver.axes_received.connect(_on_axes_received)
    receiver.connection_changed.connect(_on_connection_changed)


func _on_axes_received(axes: Array, buttons: int) -> void:
    writer.write_axes(axes, buttons)


func _on_connection_changed(connected: bool) -> void:
    if connected:
        print("Quest connected from %s" % receiver.get_stats()["sender_ip"])
    else:
        print("Quest disconnected")


func _process(delta):
    _update_timer += delta
    if _update_timer < 0.1:  # Update UI at 10Hz
        return
    _update_timer = 0.0

    # Status
    var connected := receiver.is_quest_connected
    status_label.text = "Quest: %s | uinput: %s" % [
        "CONNECTED" if connected else "waiting...",
        "ACTIVE" if writer.is_active() else "inactive (not Linux)",
    ]

    # Axes
    var axes := receiver.latest_axes
    if axes.size() >= 4:
        var names := ["THR", "YAW", "PIT", "ROL", "AX1", "AX2", "AX3", "AX4"]
        var parts := []
        for i in mini(axes.size(), 8):
            parts.append("%s:%+.2f" % [names[i], axes[i]])
        axes_label.text = " | ".join(parts)
    else:
        axes_label.text = "No data"

    # Stats
    var stats := receiver.get_stats()
    stats_label.text = "Packets: %d | Dropped: %d | From: %s" % [
        stats["packets_received"],
        stats["packets_dropped"],
        stats["sender_ip"] if stats["sender_ip"] != "" else "n/a",
    ]
```

**Step 2: Create PC main scene**

Create `scenes/pc_main.tscn`:

```
[gd_scene load_steps=4 format=3]

[ext_resource type="Script" path="res://scripts/pc_main.gd" id="1"]
[ext_resource type="Script" path="res://scripts/network/udp_receiver.gd" id="2"]
[ext_resource type="Script" path="res://scripts/input/uinput_writer.gd" id="3"]

[node name="PcMain" type="Control"]
layout_mode = 3
anchors_preset = 15
anchor_right = 1.0
anchor_bottom = 1.0
grow_horizontal = 2
grow_vertical = 2
script = ExtResource("1")

[node name="UdpReceiver" type="Node" parent="."]
script = ExtResource("2")

[node name="UinputWriter" type="Node" parent="."]
script = ExtResource("3")

[node name="VBoxContainer" type="VBoxContainer" parent="."]
layout_mode = 1
anchors_preset = 15
anchor_right = 1.0
anchor_bottom = 1.0
grow_horizontal = 2
grow_vertical = 2
theme_override_constants/separation = 20

[node name="TitleLabel" type="Label" parent="VBoxContainer"]
layout_mode = 2
text = "6DOF Drone Controller - PC Receiver"
horizontal_alignment = 1

[node name="StatusLabel" type="Label" parent="VBoxContainer"]
layout_mode = 2
text = "Quest: waiting... | uinput: checking..."

[node name="AxesLabel" type="Label" parent="VBoxContainer"]
layout_mode = 2
text = "No data"

[node name="StatsLabel" type="Label" parent="VBoxContainer"]
layout_mode = 2
text = "Packets: 0 | Dropped: 0"
```

**Step 3: Test locally (no Quest needed)**

```bash
godot --path . scenes/pc_main.tscn
```

Expected: Window opens showing "Quest: waiting..." and "uinput: inactive (not Linux)" on macOS, or "uinput: ACTIVE" on Linux (if uinput_helper is built).

**Step 4: Commit**

```bash
git add scenes/pc_main.tscn scripts/pc_main.gd
git commit -m "feat: add PC receiver scene with status UI"
```

---

## Task 11: Quest Main Scene

XR app with passthrough, controller tracking, mapping engine, and UDP sending.

**Files:**
- Create: `scenes/quest_main.tscn`
- Create: `scripts/quest_main.gd`

**Step 1: Create Quest main script**

Create `scripts/quest_main.gd`:

```gdscript
extends Node3D

@onready var xr_origin: XROrigin3D = $XROrigin3D
@onready var camera: XRCamera3D = $XROrigin3D/XRCamera3D
@onready var right_hand: XRController3D = $XROrigin3D/RightHand
@onready var left_hand: XRController3D = $XROrigin3D/LeftHand
@onready var controller_reader: Node = $ControllerReader
@onready var udp_sender: Node = $UdpSender
@onready var world_env: WorldEnvironment = $WorldEnvironment

var xr_interface: XRInterface
var mapping_engine := MappingEngine.new()
var current_template := MappingTemplate.new()

## Target PC IP (TODO: make configurable via UI)
@export var target_ip: String = "192.168.1.100"
@export var target_port: int = 9000


func _ready():
    _init_xr()
    _load_default_template()
    udp_sender.target_host = target_ip
    udp_sender.target_port = target_port

    # Calibrate button
    right_hand.button_pressed.connect(_on_right_button)


func _init_xr():
    xr_interface = XRServer.find_interface("OpenXR")
    if xr_interface and xr_interface.is_initialized():
        print("OpenXR initialized")
        var vp := get_viewport()
        vp.use_xr = true
        DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
        _enable_passthrough(true)
    else:
        push_warning("OpenXR not available - running in desktop mode")


func _enable_passthrough(enable: bool) -> void:
    var openxr: OpenXRInterface = xr_interface as OpenXRInterface
    if openxr == null:
        return
    if enable and openxr.get_supported_environment_blend_modes().has(
            XRInterface.XR_ENV_BLEND_MODE_ALPHA_BLEND):
        get_viewport().transparent_bg = true
        world_env.environment.background_mode = Environment.BG_COLOR
        world_env.environment.background_color = Color(0, 0, 0, 0)
        openxr.environment_blend_mode = XRInterface.XR_ENV_BLEND_MODE_ALPHA_BLEND
    else:
        push_warning("Passthrough not supported, using opaque mode")


func _load_default_template():
    # Try to load last-used template, fall back to simple_tilt
    var path := "user://last_template.json"
    if FileAccess.file_exists(path):
        current_template.load_from_file(path)
    else:
        var bundled := "res://templates/simple_tilt.json"
        if FileAccess.file_exists(bundled):
            current_template.load_from_file(bundled)
        else:
            # Bare minimum: tilt-based mapping
            current_template.template_name = "Default Tilt"
            current_template.add_source("pitch", "tilt_x", 1.0, "absolute")
            current_template.axes["pitch"]["range_min"] = -45.0
            current_template.axes["pitch"]["range_max"] = 45.0
            current_template.add_source("roll", "tilt_z", 1.0, "absolute")
            current_template.axes["roll"]["range_min"] = -45.0
            current_template.axes["roll"]["range_max"] = 45.0
            current_template.add_source("yaw", "tilt_y", 1.0, "absolute")
            current_template.axes["yaw"]["range_min"] = -90.0
            current_template.axes["yaw"]["range_max"] = 90.0
            current_template.add_source("throttle", "pos_y", 1.0, "absolute")
            current_template.axes["throttle"]["range_min"] = -0.3
            current_template.axes["throttle"]["range_max"] = 0.3
    mapping_engine.set_template(current_template)


func _physics_process(_delta):
    var inputs := controller_reader.read_inputs()
    if inputs.is_empty():
        return

    var outputs := mapping_engine.process(inputs)
    var buttons := controller_reader.read_buttons()

    # Send as array in standard order
    var axes: Array = [
        outputs["throttle"],
        outputs["yaw"],
        outputs["pitch"],
        outputs["roll"],
        outputs["aux1"],
        outputs["aux2"],
        outputs["aux3"],
        outputs["aux4"],
    ]
    udp_sender.send_axes(axes, buttons)


func _on_right_button(button_name: String):
    match button_name:
        "by_button":
            # B/Y button = calibrate
            controller_reader.calibrate()
            print("Calibrated!")
        "menu_button":
            # Menu = toggle config UI (TODO)
            pass


func set_template(template: MappingTemplate) -> void:
    current_template = template
    mapping_engine.set_template(template)
    # Save as last-used
    template.save_to_file("user://last_template.json")
```

**Step 2: Create Quest main scene**

Create `scenes/quest_main.tscn`:

```
[gd_scene load_steps=5 format=3]

[ext_resource type="Script" path="res://scripts/quest_main.gd" id="1"]
[ext_resource type="Script" path="res://scripts/input/xr_controller_reader.gd" id="2"]
[ext_resource type="Script" path="res://scripts/network/udp_sender.gd" id="3"]

[sub_resource type="Environment" id="env_1"]
background_mode = 1
background_color = Color(0, 0, 0, 0)

[node name="QuestMain" type="Node3D"]
script = ExtResource("1")

[node name="WorldEnvironment" type="WorldEnvironment" parent="."]
environment = SubResource("env_1")

[node name="XROrigin3D" type="XROrigin3D" parent="."]

[node name="XRCamera3D" type="XRCamera3D" parent="XROrigin3D"]

[node name="RightHand" type="XRController3D" parent="XROrigin3D"]
tracker = &"right_hand"

[node name="LeftHand" type="XRController3D" parent="XROrigin3D"]
tracker = &"left_hand"

[node name="ControllerReader" type="Node" parent="."]
script = ExtResource("2")
controller = NodePath("../XROrigin3D/RightHand")

[node name="UdpSender" type="Node" parent="."]
script = ExtResource("3")
```

**Step 3: Commit**

```bash
git add scenes/quest_main.tscn scripts/quest_main.gd
git commit -m "feat: add Quest main scene with XR, passthrough, mapping, UDP"
```

---

## Task 12: Bundled Templates

Create the three starter mapping templates.

**Files:**
- Create: `templates/simple_tilt.json`
- Create: `templates/position_fly.json`
- Create: `templates/rate_mode.json`

**Step 1: Create simple_tilt.json**

Create `templates/simple_tilt.json`:

```json
{
	"template_name": "Simple Tilt",
	"calibration": {
		"center_position": [0, 0, 0],
		"center_basis": [1, 0, 0, 0, 1, 0, 0, 0, 1]
	},
	"axes": {
		"throttle": {
			"sources": [
				{"source": "pos_y", "weight": 1.0, "mode": "absolute"}
			],
			"dead_zone": 0.05,
			"expo": 0.0,
			"sensitivity": 1.0,
			"invert": false,
			"range_min": -0.3,
			"range_max": 0.3,
			"output_min": -1.0,
			"output_max": 1.0
		},
		"yaw": {
			"sources": [
				{"source": "tilt_y", "weight": 1.0, "mode": "absolute"}
			],
			"dead_zone": 0.08,
			"expo": 0.0,
			"sensitivity": 1.0,
			"invert": false,
			"range_min": -90.0,
			"range_max": 90.0,
			"output_min": -1.0,
			"output_max": 1.0
		},
		"pitch": {
			"sources": [
				{"source": "tilt_x", "weight": 1.0, "mode": "absolute"}
			],
			"dead_zone": 0.05,
			"expo": 0.0,
			"sensitivity": 1.0,
			"invert": false,
			"range_min": -45.0,
			"range_max": 45.0,
			"output_min": -1.0,
			"output_max": 1.0
		},
		"roll": {
			"sources": [
				{"source": "tilt_z", "weight": 1.0, "mode": "absolute"}
			],
			"dead_zone": 0.05,
			"expo": 0.0,
			"sensitivity": 1.0,
			"invert": false,
			"range_min": -45.0,
			"range_max": 45.0,
			"output_min": -1.0,
			"output_max": 1.0
		},
		"aux1": {
			"sources": [],
			"dead_zone": 0.0,
			"expo": 0.0,
			"sensitivity": 1.0,
			"invert": false,
			"range_min": -1.0,
			"range_max": 1.0,
			"output_min": -1.0,
			"output_max": 1.0
		},
		"aux2": {
			"sources": [],
			"dead_zone": 0.0,
			"expo": 0.0,
			"sensitivity": 1.0,
			"invert": false,
			"range_min": -1.0,
			"range_max": 1.0,
			"output_min": -1.0,
			"output_max": 1.0
		},
		"aux3": {
			"sources": [],
			"dead_zone": 0.0,
			"expo": 0.0,
			"sensitivity": 1.0,
			"invert": false,
			"range_min": -1.0,
			"range_max": 1.0,
			"output_min": -1.0,
			"output_max": 1.0
		},
		"aux4": {
			"sources": [],
			"dead_zone": 0.0,
			"expo": 0.0,
			"sensitivity": 1.0,
			"invert": false,
			"range_min": -1.0,
			"range_max": 1.0,
			"output_min": -1.0,
			"output_max": 1.0
		}
	}
}
```

**Step 2: Create position_fly.json**

Create `templates/position_fly.json`:

```json
{
	"template_name": "Position Fly",
	"calibration": {
		"center_position": [0, 0, 0],
		"center_basis": [1, 0, 0, 0, 1, 0, 0, 0, 1]
	},
	"axes": {
		"throttle": {
			"sources": [
				{"source": "pos_y", "weight": 1.0, "mode": "absolute"},
				{"source": "pos_z", "weight": 0.3, "mode": "absolute"}
			],
			"dead_zone": 0.05,
			"expo": 0.0,
			"sensitivity": 1.0,
			"invert": false,
			"range_min": -0.3,
			"range_max": 0.3,
			"output_min": -1.0,
			"output_max": 1.0
		},
		"yaw": {
			"sources": [
				{"source": "pos_x", "weight": 1.0, "mode": "absolute"}
			],
			"dead_zone": 0.08,
			"expo": 0.0,
			"sensitivity": 1.0,
			"invert": false,
			"range_min": -0.3,
			"range_max": 0.3,
			"output_min": -1.0,
			"output_max": 1.0
		},
		"pitch": {
			"sources": [
				{"source": "pos_z", "weight": 1.0, "mode": "absolute"}
			],
			"dead_zone": 0.05,
			"expo": 0.0,
			"sensitivity": 1.0,
			"invert": true,
			"range_min": -0.3,
			"range_max": 0.3,
			"output_min": -1.0,
			"output_max": 1.0
		},
		"roll": {
			"sources": [
				{"source": "tilt_z", "weight": 1.0, "mode": "absolute"}
			],
			"dead_zone": 0.05,
			"expo": 0.0,
			"sensitivity": 1.0,
			"invert": false,
			"range_min": -45.0,
			"range_max": 45.0,
			"output_min": -1.0,
			"output_max": 1.0
		},
		"aux1": {
			"sources": [],
			"dead_zone": 0.0,
			"expo": 0.0,
			"sensitivity": 1.0,
			"invert": false,
			"range_min": -1.0,
			"range_max": 1.0,
			"output_min": -1.0,
			"output_max": 1.0
		},
		"aux2": {
			"sources": [],
			"dead_zone": 0.0,
			"expo": 0.0,
			"sensitivity": 1.0,
			"invert": false,
			"range_min": -1.0,
			"range_max": 1.0,
			"output_min": -1.0,
			"output_max": 1.0
		},
		"aux3": {
			"sources": [],
			"dead_zone": 0.0,
			"expo": 0.0,
			"sensitivity": 1.0,
			"invert": false,
			"range_min": -1.0,
			"range_max": 1.0,
			"output_min": -1.0,
			"output_max": 1.0
		},
		"aux4": {
			"sources": [],
			"dead_zone": 0.0,
			"expo": 0.0,
			"sensitivity": 1.0,
			"invert": false,
			"range_min": -1.0,
			"range_max": 1.0,
			"output_min": -1.0,
			"output_max": 1.0
		}
	}
}
```

**Step 3: Create rate_mode.json**

Create `templates/rate_mode.json`:

```json
{
	"template_name": "Rate Mode",
	"calibration": {
		"center_position": [0, 0, 0],
		"center_basis": [1, 0, 0, 0, 1, 0, 0, 0, 1]
	},
	"axes": {
		"throttle": {
			"sources": [
				{"source": "linvel_y", "weight": 1.0, "mode": "absolute"}
			],
			"dead_zone": 0.1,
			"expo": 0.0,
			"sensitivity": 1.0,
			"invert": false,
			"range_min": -2.0,
			"range_max": 2.0,
			"output_min": -1.0,
			"output_max": 1.0
		},
		"yaw": {
			"sources": [
				{"source": "angvel_y", "weight": 1.0, "mode": "absolute"}
			],
			"dead_zone": 0.1,
			"expo": 0.0,
			"sensitivity": 1.0,
			"invert": false,
			"range_min": -3.0,
			"range_max": 3.0,
			"output_min": -1.0,
			"output_max": 1.0
		},
		"pitch": {
			"sources": [
				{"source": "angvel_x", "weight": 1.0, "mode": "absolute"}
			],
			"dead_zone": 0.1,
			"expo": 0.0,
			"sensitivity": 1.0,
			"invert": false,
			"range_min": -3.0,
			"range_max": 3.0,
			"output_min": -1.0,
			"output_max": 1.0
		},
		"roll": {
			"sources": [
				{"source": "angvel_z", "weight": 1.0, "mode": "absolute"}
			],
			"dead_zone": 0.1,
			"expo": 0.0,
			"sensitivity": 1.0,
			"invert": false,
			"range_min": -3.0,
			"range_max": 3.0,
			"output_min": -1.0,
			"output_max": 1.0
		},
		"aux1": {
			"sources": [],
			"dead_zone": 0.0,
			"expo": 0.0,
			"sensitivity": 1.0,
			"invert": false,
			"range_min": -1.0,
			"range_max": 1.0,
			"output_min": -1.0,
			"output_max": 1.0
		},
		"aux2": {
			"sources": [],
			"dead_zone": 0.0,
			"expo": 0.0,
			"sensitivity": 1.0,
			"invert": false,
			"range_min": -1.0,
			"range_max": 1.0,
			"output_min": -1.0,
			"output_max": 1.0
		},
		"aux3": {
			"sources": [],
			"dead_zone": 0.0,
			"expo": 0.0,
			"sensitivity": 1.0,
			"invert": false,
			"range_min": -1.0,
			"range_max": 1.0,
			"output_min": -1.0,
			"output_max": 1.0
		},
		"aux4": {
			"sources": [],
			"dead_zone": 0.0,
			"expo": 0.0,
			"sensitivity": 1.0,
			"invert": false,
			"range_min": -1.0,
			"range_max": 1.0,
			"output_min": -1.0,
			"output_max": 1.0
		}
	}
}
```

**Step 4: Commit**

```bash
git add templates/
git commit -m "feat: add bundled mapping templates (tilt, position, rate mode)"
```

---

## Task 13: Config UI

AR overlay panel for template management and axis configuration on Quest. Also used as a desktop panel on PC for testing.

**Files:**
- Create: `scripts/ui/config_ui.gd`
- Create: `scripts/ui/template_manager.gd`
- Create: `scripts/ui/axis_visualizer.gd`
- Create: `scenes/shared/config_panel.tscn`
- Create: `scenes/shared/axis_visualizer.tscn`

**Step 1: Create template manager**

Create `scripts/ui/template_manager.gd`:

```gdscript
class_name TemplateManager
extends RefCounted

const TEMPLATES_DIR := "user://templates/"
const BUNDLED_DIR := "res://templates/"

var _templates: Dictionary = {}  # name -> file path


func _init():
    _ensure_dir_exists()
    _scan_templates()


func _ensure_dir_exists() -> void:
    DirAccess.make_dir_recursive_absolute(
        ProjectSettings.globalize_path(TEMPLATES_DIR))


func _scan_templates() -> void:
    _templates.clear()
    # Scan bundled templates
    _scan_dir(BUNDLED_DIR)
    # Scan user templates (overwrites bundled with same name)
    _scan_dir(TEMPLATES_DIR)


func _scan_dir(dir_path: String) -> void:
    var dir := DirAccess.open(dir_path)
    if dir == null:
        return
    dir.list_dir_begin()
    var file_name := dir.get_next()
    while file_name != "":
        if file_name.ends_with(".json"):
            var full_path := dir_path + file_name
            var t := MappingTemplate.new()
            if t.load_from_file(full_path) == OK:
                _templates[t.template_name] = full_path
        file_name = dir.get_next()


func list_names() -> PackedStringArray:
    return PackedStringArray(_templates.keys())


func load_template(name: String) -> MappingTemplate:
    if name not in _templates:
        return null
    var t := MappingTemplate.new()
    if t.load_from_file(_templates[name]) != OK:
        return null
    return t


func save_template(template: MappingTemplate) -> Error:
    var filename := template.template_name.to_snake_case() + ".json"
    var path := TEMPLATES_DIR + filename
    var err := template.save_to_file(path)
    if err == OK:
        _templates[template.template_name] = path
    return err


func delete_template(name: String) -> Error:
    if name not in _templates:
        return ERR_DOES_NOT_EXIST
    var path: String = _templates[name]
    # Only delete user templates, not bundled
    if path.begins_with(TEMPLATES_DIR):
        var global_path := ProjectSettings.globalize_path(path)
        DirAccess.remove_absolute(global_path)
    _templates.erase(name)
    return OK
```

**Step 2: Create axis visualizer**

Create `scripts/ui/axis_visualizer.gd`:

```gdscript
extends Control

## Array of axis names to display
@export var axis_names: PackedStringArray = ["THR", "YAW", "PIT", "ROL"]

var _values: Array[float] = []
var _bar_height := 20.0
var _bar_spacing := 5.0


func _ready():
    _values.resize(axis_names.size())
    _values.fill(0.0)
    custom_minimum_size.y = axis_names.size() * (_bar_height + _bar_spacing)


func set_values(values: Array) -> void:
    for i in mini(values.size(), _values.size()):
        _values[i] = values[i]
    queue_redraw()


func _draw():
    var w := size.x
    var center_x := w / 2.0
    var bar_w := w * 0.4  # max bar width per side

    for i in axis_names.size():
        var y := i * (_bar_height + _bar_spacing)
        var val: float = _values[i] if i < _values.size() else 0.0

        # Label
        draw_string(ThemeDB.fallback_font, Vector2(4, y + _bar_height - 4),
            axis_names[i], HORIZONTAL_ALIGNMENT_LEFT, -1, 14)

        # Background
        draw_rect(Rect2(center_x - bar_w, y, bar_w * 2, _bar_height),
            Color(0.2, 0.2, 0.2))

        # Center line
        draw_line(Vector2(center_x, y), Vector2(center_x, y + _bar_height),
            Color(0.5, 0.5, 0.5), 1.0)

        # Value bar
        var bar_length := val * bar_w
        var bar_color := Color(0.2, 0.8, 0.2) if val >= 0 else Color(0.8, 0.2, 0.2)
        if bar_length >= 0:
            draw_rect(Rect2(center_x, y + 2, bar_length, _bar_height - 4), bar_color)
        else:
            draw_rect(Rect2(center_x + bar_length, y + 2, -bar_length, _bar_height - 4), bar_color)

        # Value text
        draw_string(ThemeDB.fallback_font, Vector2(w - 60, y + _bar_height - 4),
            "%+.2f" % val, HORIZONTAL_ALIGNMENT_RIGHT, -1, 12)
```

**Step 3: Create config panel scene**

This will be created as a scene file. Due to its complexity with many UI elements, the full scene tree is:

Create `scenes/shared/config_panel.tscn` and `scripts/ui/config_ui.gd`:

```gdscript
# scripts/ui/config_ui.gd
extends Control

signal template_changed(template: MappingTemplate)
signal calibrate_requested()

var _template_manager := TemplateManager.new()
var _current_template: MappingTemplate

@onready var template_option: OptionButton = $VBox/TemplateRow/TemplateOption
@onready var save_button: Button = $VBox/TemplateRow/SaveButton
@onready var axis_viz: Control = $VBox/AxisVisualizer
@onready var ip_edit: LineEdit = $VBox/NetworkRow/IpEdit
@onready var calibrate_button: Button = $VBox/CalibrateButton
@onready var connection_label: Label = $VBox/ConnectionLabel


func _ready():
    _refresh_template_list()
    template_option.item_selected.connect(_on_template_selected)
    save_button.pressed.connect(_on_save_pressed)
    calibrate_button.pressed.connect(func(): calibrate_requested.emit())

    # Load first template
    if template_option.item_count > 0:
        _on_template_selected(0)


func _refresh_template_list():
    template_option.clear()
    for name in _template_manager.list_names():
        template_option.add_item(name)


func _on_template_selected(index: int):
    var name := template_option.get_item_text(index)
    _current_template = _template_manager.load_template(name)
    if _current_template:
        template_changed.emit(_current_template)


func _on_save_pressed():
    if _current_template:
        _template_manager.save_template(_current_template)


func update_axes(values: Array) -> void:
    if axis_viz:
        axis_viz.set_values(values)


func update_connection_status(quest_connected: bool, pc_connected: bool) -> void:
    if connection_label:
        connection_label.text = "Quest: %s | PC: %s" % [
            "OK" if quest_connected else "---",
            "OK" if pc_connected else "---",
        ]


func get_target_ip() -> String:
    return ip_edit.text if ip_edit else "127.0.0.1"
```

Create `scenes/shared/config_panel.tscn`:

```
[gd_scene load_steps=3 format=3]

[ext_resource type="Script" path="res://scripts/ui/config_ui.gd" id="1"]
[ext_resource type="Script" path="res://scripts/ui/axis_visualizer.gd" id="2"]

[node name="ConfigPanel" type="Control"]
custom_minimum_size = Vector2(400, 300)
layout_mode = 3
anchors_preset = 0
script = ExtResource("1")

[node name="Panel" type="Panel" parent="."]
layout_mode = 1
anchors_preset = 15
anchor_right = 1.0
anchor_bottom = 1.0
grow_horizontal = 2
grow_vertical = 2

[node name="VBox" type="VBoxContainer" parent="."]
layout_mode = 1
anchors_preset = 15
anchor_right = 1.0
anchor_bottom = 1.0
offset_left = 10.0
offset_top = 10.0
offset_right = -10.0
offset_bottom = -10.0
grow_horizontal = 2
grow_vertical = 2
theme_override_constants/separation = 8

[node name="TitleLabel" type="Label" parent="VBox"]
layout_mode = 2
text = "6DOF Controller Config"
horizontal_alignment = 1

[node name="TemplateRow" type="HBoxContainer" parent="VBox"]
layout_mode = 2

[node name="TemplateLabel" type="Label" parent="VBox/TemplateRow"]
layout_mode = 2
text = "Template:"

[node name="TemplateOption" type="OptionButton" parent="VBox/TemplateRow"]
layout_mode = 2
size_flags_horizontal = 3

[node name="SaveButton" type="Button" parent="VBox/TemplateRow"]
layout_mode = 2
text = "Save"

[node name="NetworkRow" type="HBoxContainer" parent="VBox"]
layout_mode = 2

[node name="IpLabel" type="Label" parent="VBox/NetworkRow"]
layout_mode = 2
text = "PC IP:"

[node name="IpEdit" type="LineEdit" parent="VBox/NetworkRow"]
layout_mode = 2
size_flags_horizontal = 3
text = "192.168.1.100"
placeholder_text = "PC IP address"

[node name="CalibrateButton" type="Button" parent="VBox"]
layout_mode = 2
text = "Calibrate (hold controller in neutral position)"

[node name="ConnectionLabel" type="Label" parent="VBox"]
layout_mode = 2
text = "Quest: --- | PC: ---"

[node name="AxisVisualizer" type="Control" parent="VBox"]
layout_mode = 2
custom_minimum_size = Vector2(0, 120)
script = ExtResource("2")
axis_names = PackedStringArray("THR", "YAW", "PIT", "ROL")
```

**Step 4: Commit**

```bash
git add scripts/ui/ scenes/shared/
git commit -m "feat: add config UI with template manager and axis visualizer"
```

---

## Task 14: Export Configuration and Integration

Set up export presets and verify the full pipeline works.

**Step 1: Add OpenXR Vendors plugin for Quest**

The Godot OpenXR Vendors plugin is required for Quest export. Install via the Godot Asset Library (in editor) or download from https://github.com/GodotVR/godot_openxr_vendors.

After installing, the `addons/godotopenxrvendors/` directory will exist.

Update `project.godot` to enable XR:

Add these sections to `project.godot`:

```ini
[xr]
openxr/enabled=true
shaders/enabled=true
openxr/environment_blend_mode=1
openxr/foveation_level=3
```

**Step 2: Set up export presets**

Using the Godot editor (Project > Export), create three presets:
1. **Quest 3 (Android)**: XR mode = OpenXR, Min SDK 24, Target SDK 34, Gradle Build enabled
2. **Linux**: Standard Linux/X11 export
3. **macOS**: Standard macOS export

These are stored in `export_presets.cfg` (gitignored since it contains local paths).

**Step 3: End-to-end test on localhost**

To test the full pipeline without a Quest:
1. Open the PC scene: `godot --path . scenes/pc_main.tscn`
2. In a separate terminal, send test UDP packets using a simple GDScript:

Create `test/integration/test_send_fake_axes.gd` (run as a standalone script):

```gdscript
extends SceneTree

## Send fake axis data to the PC receiver for testing.
## Run with: godot --headless --script test/integration/test_send_fake_axes.gd

func _init():
    var peer := PacketPeerUDP.new()
    peer.set_dest_address("127.0.0.1", 9000)

    print("Sending fake axis data to localhost:9000...")
    var seq := 0
    for i in 200:
        var t := float(i) / 200.0 * TAU
        var axes := [
            sin(t) * 0.5,       # throttle: oscillate
            cos(t) * 0.3,       # yaw
            sin(t * 2) * 0.7,   # pitch
            cos(t * 3) * 0.4,   # roll
            0.0, 0.0, 0.0, 0.0, # aux
        ]
        var timestamp := int(Time.get_unix_time_from_system() * 1_000_000.0)
        var packet := Protocol.pack_axes(axes, seq, timestamp, 0)
        peer.put_packet(packet)
        seq += 1
        OS.delay_msec(10)  # ~100Hz

    print("Done. Sent 200 packets.")
    peer.close()
    quit()
```

**Step 4: Commit**

```bash
git add test/integration/test_send_fake_axes.gd
git commit -m "feat: add export configuration and end-to-end test script"
```

---

## Summary of Commits

| # | Commit | What it builds |
|---|--------|----------------|
| 1 | Project scaffolding + GUT | Empty Godot project with testing |
| 2 | MappingTemplate | Data model for control mappings |
| 3 | MappingEngine | Core mapping logic with all features |
| 4 | Calibration | Center-point offset system |
| 5 | Protocol | Binary packet format |
| 6 | UDP sender/receiver | Network layer |
| 7 | XR controller reader | Quest input reading |
| 8 | uinput helper | Linux virtual gamepad (C binary) |
| 9 | uinput writer | GDScript wrapper for helper |
| 10 | PC main scene | Receiver app |
| 11 | Quest main scene | XR sender app |
| 12 | Bundled templates | 3 starter presets |
| 13 | Config UI | Template management + visualization |
| 14 | Export + integration test | Full pipeline verification |

## Testing Sequence

1. **Unit tests** (Tasks 2-5): `godot --headless -s addons/gut/gut_cmdln.gd`
2. **Loopback test** (Task 6): GUT integration test, localhost UDP
3. **Fake sender test** (Task 14): PC scene + test script, visual verification
4. **Quest test**: Deploy APK to Quest, connect to PC receiver, fly in Liftoff

## Notes for Implementation

- The `MappingTemplate` and `MappingEngine` `class_name` declarations may conflict with the `const` preload pattern in tests. If so, use `class_name` and drop the `const` preload lines in test files, referencing the classes directly.
- The Quest scene needs the OpenXR Vendors plugin installed via the Godot editor before it can export to APK.
- On Linux, the uinput_helper needs `/dev/uinput` write access. Either `sudo` or add user to `input` group: `sudo usermod -aG input $USER`.
- Steam Input may intercept the virtual joystick. Disable per-game in Steam: right-click game > Properties > Controller > Disable Steam Input.
