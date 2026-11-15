@tool
class_name LevelScatter
extends MultiMeshInstance3D
## Draws a room's hazards as copies of one static `mesh` (spikes): one per hazard, at its
## room's HazardLayout spots, the same spots the simulation uses to hit adventurers. One
## MultiMesh means one draw call however many copies there are. For hazards that animate
## (skeletons, chests), use LevelSpawner instead.

@export var mesh: Mesh:
	set(value):
		mesh = value
		_rebuild()
## Editor preview only: how many copies to show, and with which layout.
@export var preview_count: int = 9:
	set(value):
		preview_count = value
		if Engine.is_editor_hint():
			_count = value
			_rebuild()
@export var preview_layout: HazardLayout

var _layout: HazardLayout
## Kept so a rebuild (which can happen after set_room, e.g. in _ready) shows the same count.
var _count: int = 0


func _ready() -> void:
	if Engine.is_editor_hint():
		_count = preview_count
		_layout = preview_layout
	_rebuild()


func set_room(room: DungeonRoom) -> void:
	_layout = room.def.layout()
	_count = room.hazard_count()
	_rebuild()


func _rebuild() -> void:
	var layout := _layout if _layout != null else HazardLayout.default_layout()
	var spots: Array[Vector2] = layout.spots()
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
	mm.visible_instance_count = clampi(_count, 0, spots.size())
	multimesh = mm
