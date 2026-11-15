class_name DungeonGeometry
extends RefCounted
## Builds the 3D scene for a Dungeon: each room's interior, plus the walls between cells.
##
## The camera looks from the south-east (+X, +Z), so walls are cut away to keep every room
## visible. Only back edges (north and west) with nothing behind them get tall walls. Every
## other edge gets a low barrier. Edges between connected rooms have an opening in the middle
## segment, and so does the Entrance's outside door.

## World units per grid cell: 3×3 KayKit large floor tiles.
const CELL: float = 12.0
const HALF: float = CELL * 0.5
## Each edge is three 4-unit wall pieces.
const SEGMENT_OFFSETS: Array[float] = [-4.0, 0.0, 4.0]

const DIR := "res://assets/third_party/kaykit/dungeon/"
const WALL := DIR + "wall.gltf"
const WALL_DOORWAY := DIR + "wall_doorway.gltf"
const BARRIER := DIR + "barrier.gltf"
const PILLAR := DIR + "pillar.gltf"
const TORCH := DIR + "torch_mounted.gltf"
const FLOOR := DIR + "floor_tile_large.gltf"

const TORCH_HEIGHT: float = 2.6
const TORCH_LIGHT_COLOR := Color(1.0, 0.68, 0.38)


static func cell_center(coord: Vector2i) -> Vector3:
	return Vector3(coord.x * CELL, 0.0, coord.y * CELL)


## Midpoint of the edge on the `dir` side of a cell.
static func edge_center(coord: Vector2i, dir: Vector2i) -> Vector3:
	return cell_center(coord) + Vector3(dir.x, 0.0, dir.y) * HALF


static func build(dungeon: Dungeon) -> Node3D:
	var root := Node3D.new()
	root.name = "Geometry"
	var pillars: Dictionary[Vector3, bool] = {}
	for room: DungeonRoom in dungeon.rooms.values():
		_add_interior(root, room)
		for dir: Vector2i in Dungeon.DIRECTIONS:
			_add_edge(root, dungeon, room, dir, pillars)
	for pos: Vector3 in pillars:
		_add_model(root, PILLAR, pos, 0.0)
	return root


static func _add_interior(root: Node3D, room: DungeonRoom) -> void:
	var center := cell_center(room.coord)
	if room.def.interior != null:
		var interior: Node3D = room.def.interior.instantiate()
		interior.position = center
		if interior is RoomInterior:
			(interior as RoomInterior).set_level(room.level)
		root.add_child(interior)
		return
	for x: float in SEGMENT_OFFSETS:
		for z: float in SEGMENT_OFFSETS:
			_add_model(root, FLOOR, center + Vector3(x, 0.0, z), 0.0)


static func _add_edge(root: Node3D, dungeon: Dungeon, room: DungeonRoom, dir: Vector2i,
		pillars: Dictionary[Vector3, bool]) -> void:
	var neighbor_coord := room.coord + dir
	var neighbor := dungeon.room_at(neighbor_coord)
	var is_back := dir == Vector2i.UP or dir == Vector2i.LEFT
	# A shared edge between two rooms is drawn once, by the room on its south/east side.
	if neighbor != null and not is_back:
		return

	var is_outside_door := room.id == dungeon.entrance_id and dir == dungeon.entrance_outside_dir
	var connected := neighbor != null and dungeon.neighbors(room.id).has(neighbor.id)
	var opening := connected or is_outside_door
	var tall := is_back and neighbor == null

	var mid := edge_center(room.coord, dir)
	var along := Vector3(absi(dir.y), 0.0, absi(dir.x))  # direction the edge runs
	var rot_y := 0.0 if dir.y != 0 else PI * 0.5
	for offset: float in SEGMENT_OFFSETS:
		var pos := mid + along * offset
		var is_middle := offset == 0.0
		if tall:
			_add_model(root, WALL_DOORWAY if (is_middle and opening) else WALL, pos, rot_y)
		elif not (is_middle and opening):
			_add_model(root, BARRIER, pos, rot_y)

	if tall:
		pillars[mid - along * HALF] = true
		pillars[mid + along * HALF] = true
		if not opening:
			_add_torch(root, mid, dir)


## A mounted torch on the inner face of a tall wall, with a warm light.
static func _add_torch(root: Node3D, wall_mid: Vector3, dir: Vector2i) -> void:
	var inward := -Vector3(dir.x, 0.0, dir.y)
	var pos := wall_mid + inward * 0.5 + Vector3.UP * TORCH_HEIGHT
	# The torch model sticks out along +Z. Turn it to point into the room.
	var torch := _add_model(root, TORCH, pos, atan2(inward.x, inward.z))
	var light := OmniLight3D.new()
	light.light_color = TORCH_LIGHT_COLOR
	light.light_energy = 2.0
	light.omni_range = 9.0
	light.position = Vector3(0.0, 0.6, 0.5)
	torch.add_child(light)


static func _add_model(root: Node3D, path: String, pos: Vector3, rot_y: float) -> Node3D:
	var scene: PackedScene = load(path)
	var node: Node3D = scene.instantiate()
	node.position = pos
	node.rotation.y = rot_y
	root.add_child(node)
	return node
