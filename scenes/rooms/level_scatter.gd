@tool
class_name LevelScatter
extends MultiMeshInstance3D
## Draws a room's hazards: one copy of `mesh` per room level, at the spots from HazardLayout,
## the same spots the simulation uses to hit adventurers. Use it inside a RoomInterior scene,
## which passes the level in. One MultiMesh means one draw call however many copies there are.

@export var mesh: Mesh:
	set(value):
		mesh = value
		_rebuild()
## Level shown in the editor preview.
@export var preview_level: int = 9:
	set(value):
		preview_level = value
		if Engine.is_editor_hint():
			set_level(value)

## Kept so a rebuild (which can happen after set_level, e.g. in _ready) shows the same count.
var _level: int = 0


func _ready() -> void:
	if Engine.is_editor_hint():
		_level = preview_level
	_rebuild()


func set_level(level: int) -> void:
	_level = level
	if multimesh == null:
		_rebuild()
	else:
		_apply_level()


func _rebuild() -> void:
	var spots: Array[Vector2] = HazardLayout.spots()
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = mesh
	mm.instance_count = spots.size()
	var rng := RandomNumberGenerator.new()
	for i: int in spots.size():
		# A fixed random turn per spot, only for looks.
		rng.seed = i
		var turn := Basis(Vector3.UP, rng.randf_range(0.0, TAU))
		mm.set_instance_transform(i, Transform3D(turn, Vector3(spots[i].x, 0.0, spots[i].y)))
	multimesh = mm
	_apply_level()


func _apply_level() -> void:
	multimesh.visible_instance_count = clampi(_level, 0, multimesh.instance_count)
