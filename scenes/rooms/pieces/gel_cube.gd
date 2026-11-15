extends Node3D
## A gelatinous cube: a see-through green block that slides back and forth along the path,
## engulfing whoever walks through. It grows with the room's level.

const COLOR := Color(0.35, 0.9, 0.35, 0.38)
const MIN_SIZE: float = 2.0
const MAX_SIZE: float = 5.0
## Size gained per level until MAX_SIZE.
const GROWTH: float = 0.2
## Seconds for one trip across the room and back.
const SLIDE_PERIOD: float = 9.0
## Each side of the room the cube's center can reach.
const SLIDE_RANGE: float = 3.0

var _cube: MeshInstance3D
var _size: float = MIN_SIZE
var _time: float = 0.0


func _ready() -> void:
	var material := StandardMaterial3D.new()
	material.albedo_color = COLOR
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.roughness = 0.15
	material.metallic_specular = 0.8
	material.rim_enabled = true
	material.rim = 0.6
	var box := BoxMesh.new()
	box.size = Vector3.ONE
	_cube = MeshInstance3D.new()
	_cube.mesh = box
	_cube.material_override = material
	_cube.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_cube)
	_apply_size()


func set_room(room: DungeonRoom) -> void:
	_size = clampf(MIN_SIZE + GROWTH * (room.level - 1), MIN_SIZE, MAX_SIZE)
	if _cube != null:
		_apply_size()


func _process(delta: float) -> void:
	_time += delta
	_cube.position.x = sin(_time * TAU / SLIDE_PERIOD) * SLIDE_RANGE
	# A slow wobble, like jelly.
	var wobble := 1.0 + 0.04 * sin(_time * 3.1)
	_cube.scale = Vector3(_size / wobble, _size * wobble, _size / wobble)
	_cube.position.y = _cube.scale.y * 0.5


func _apply_size() -> void:
	_cube.scale = Vector3.ONE * _size
	_cube.position.y = _size * 0.5
