class_name LevelSpawner
extends Node3D
## Places one `piece` scene per hazard at the room's HazardLayout spots (the spots the simulation
## hits from), for hazards that animate. When hazard i hits someone, piece i's `trigger()` runs:
## a skeleton swings, a chest bites. For static hazards, LevelScatter is cheaper.

@export var piece: PackedScene
## Turn pieces to face the walkway (z = 0). Otherwise each gets a fixed random turn.
@export var face_path: bool = true
## Height above the floor, for floating pieces.
@export var height: float = 0.0

var _pieces: Array[Node3D] = []


func set_room(room: DungeonRoom) -> void:
	for p: Node3D in _pieces:
		p.queue_free()
	_pieces.clear()
	if piece == null:
		return
	var spots: Array[Vector2] = room.def.layout().spots()
	var rng := RandomNumberGenerator.new()
	for i: int in room.hazard_count():
		var node: Node3D = piece.instantiate()
		node.position = Vector3(spots[i].x, height, spots[i].y)
		if face_path:
			# Models face +Z: pieces on the -Z side already face the path.
			node.rotation.y = 0.0 if spots[i].y < 0.0 else PI
		else:
			rng.seed = i
			node.rotation.y = rng.randf_range(0.0, TAU)
		if node.has_method(&"set_phase"):
			node.call(&"set_phase", float(i) * 0.37)
		add_child(node)
		_pieces.append(node)


func trigger_hazard(index: int) -> void:
	if index >= 0 and index < _pieces.size() and _pieces[index].has_method(&"trigger"):
		_pieces[index].call(&"trigger")
