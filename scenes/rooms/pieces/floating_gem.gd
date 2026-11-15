extends Node3D
## A glowing gem that hovers and turns: the lich's phylactery, or the heart of the blood altar.
## Glows brighter with the room's level.

@export var color: Color = Color(0.6, 0.3, 1.0)
@export var size: float = 0.6

var _gem: MeshInstance3D
var _light: OmniLight3D
var _time: float = 0.0
var _level: int = 1


func _ready() -> void:
	# A low-poly sphere with 4 sides and 2 rings is an octahedron: a gem.
	var mesh := SphereMesh.new()
	mesh.radial_segments = 4
	mesh.rings = 2
	mesh.radius = size * 0.5
	mesh.height = size * 1.6
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.emission_enabled = true
	material.emission = color
	material.emission_energy_multiplier = 1.5
	_gem = MeshInstance3D.new()
	_gem.mesh = mesh
	_gem.material_override = material
	add_child(_gem)
	_light = OmniLight3D.new()
	_light.light_color = color
	_light.omni_range = 6.0
	add_child(_light)
	_apply_level()


func set_room(room: DungeonRoom) -> void:
	_level = room.level
	if _light != null:
		_apply_level()


func _process(delta: float) -> void:
	_time += delta
	_gem.rotation.y = _time * 0.8
	_gem.position.y = sin(_time * 1.5) * 0.15


func _apply_level() -> void:
	_light.light_energy = clampf(0.8 + 0.08 * _level, 0.8, 3.0)
