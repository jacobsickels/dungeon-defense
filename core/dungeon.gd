class_name Dungeon
extends RefCounted
## The room graph, laid out on a grid. Pure data and queries, no nodes.
##
## Rooms form a tree rooted at the Entrance. Every other room has exactly one parent
## and sits next to it on the grid. Connections are explicit: two rooms that touch
## on the grid are NOT connected unless one is the other's parent.
##
## Pathing uses BFS over the connections and doesn't assume a tree, so loops
## can be added later.

const NO_ROOM: int = -1
const DIRECTIONS: Array[Vector2i] = [Vector2i.RIGHT, Vector2i.DOWN, Vector2i.LEFT, Vector2i.UP]

var rooms: Dictionary[int, DungeonRoom] = {}
var entrance_id: int = NO_ROOM
## Side of the Entrance that opens to the outside. Nothing can be built there.
var entrance_outside_dir: Vector2i = Vector2i.LEFT

var _by_coord: Dictionary[Vector2i, int] = {}
var _next_id: int = 0


func add_entrance(def: RoomDef, coord: Vector2i, outside_dir: Vector2i = Vector2i.LEFT) -> DungeonRoom:
	assert(entrance_id == NO_ROOM, "Dungeon already has an entrance")
	entrance_outside_dir = outside_dir
	var room := _create_room(def, coord, NO_ROOM)
	entrance_id = room.id
	return room


func get_room(id: int) -> DungeonRoom:
	return rooms.get(id) as DungeonRoom


func room_at(coord: Vector2i) -> DungeonRoom:
	var id: int = _by_coord.get(coord, NO_ROOM)
	return get_room(id)


## Grid cell just outside the Entrance, where adventurers come in from.
func outside_cell() -> Vector2i:
	return get_room(entrance_id).coord + entrance_outside_dir


func is_cell_free(coord: Vector2i) -> bool:
	if _by_coord.has(coord):
		return false
	if entrance_id != NO_ROOM and coord == outside_cell():
		return false
	return true


func neighbors(id: int) -> Array[int]:
	var room := get_room(id)
	var out: Array[int] = []
	if room.parent_id != NO_ROOM:
		out.append(room.parent_id)
	out.append_array(room.child_ids)
	return out


## Directions from this room into empty cells where a branch can be built.
func open_directions(id: int) -> Array[Vector2i]:
	var room := get_room(id)
	var out: Array[Vector2i] = []
	for dir: Vector2i in DIRECTIONS:
		if is_cell_free(room.coord + dir):
			out.append(dir)
	return out


# --- Building ---------------------------------------------------------------

func can_build_branch(parent_id: int, dir: Vector2i) -> bool:
	var parent := get_room(parent_id)
	if parent == null or not DIRECTIONS.has(dir):
		return false
	return is_cell_free(parent.coord + dir)


## Builds a new room in the empty cell on `dir` side of the parent. Returns null if not allowed.
func build_branch(def: RoomDef, parent_id: int, dir: Vector2i) -> DungeonRoom:
	if not can_build_branch(parent_id, dir):
		return null
	var parent := get_room(parent_id)
	var room := _create_room(def, parent.coord + dir, parent_id)
	parent.child_ids.append(room.id)
	return room


## Inserting pushes the child's whole subtree one cell away from the parent.
## It's allowed only if every shifted room lands on a free cell, or on a cell that
## another shifted room is leaving.
func can_insert(parent_id: int, child_id: int) -> bool:
	var parent := get_room(parent_id)
	var child := get_room(child_id)
	if parent == null or child == null or child.parent_id != parent_id:
		return false
	var dir := child.coord - parent.coord
	var moving := _id_set(subtree_ids(child_id))
	var outside := outside_cell()
	for id: int in moving:
		var target := get_room(id).coord + dir
		if target == outside:
			return false
		var occupant: int = _by_coord.get(target, NO_ROOM)
		if occupant != NO_ROOM and not moving.has(occupant):
			return false
	return true


## Builds a new room between parent and child and pushes the child's subtree outward.
## Returns null if not allowed.
func insert_between(def: RoomDef, parent_id: int, child_id: int) -> DungeonRoom:
	if not can_insert(parent_id, child_id):
		return null
	var parent := get_room(parent_id)
	var child := get_room(child_id)
	var dir := child.coord - parent.coord
	var freed_coord := child.coord

	var moving := subtree_ids(child_id)
	for id: int in moving:
		_by_coord.erase(get_room(id).coord)
	for id: int in moving:
		var r := get_room(id)
		r.coord += dir
		_by_coord[r.coord] = id

	var room := _create_room(def, freed_coord, parent_id)
	parent.child_ids[parent.child_ids.find(child_id)] = room.id
	room.child_ids.append(child_id)
	child.parent_id = room.id
	return room


# --- Queries ----------------------------------------------------------------

## The room and all of its descendants.
func subtree_ids(root_id: int) -> Array[int]:
	var out: Array[int] = []
	var stack: Array[int] = [root_id]
	while not stack.is_empty():
		var id: int = stack.pop_back()
		out.append(id)
		stack.append_array(get_room(id).child_ids)
	return out


## Shortest path from one room to another, including both ends. Empty if there isn't one.
func path(from_id: int, to_id: int) -> Array[int]:
	if from_id == to_id:
		return [from_id]
	var came_from: Dictionary[int, int] = {from_id: NO_ROOM}
	var queue: Array[int] = [from_id]
	var head := 0
	while head < queue.size():
		var current := queue[head]
		head += 1
		for next: int in neighbors(current):
			if came_from.has(next):
				continue
			came_from[next] = current
			if next == to_id:
				return _rebuild_path(came_from, to_id)
			queue.append(next)
	return []


## Closest room (by number of steps) for which `predicate(room) -> bool` is true,
## counting the starting room. Returns NO_ROOM if no room matches.
func nearest_room(from_id: int, predicate: Callable) -> int:
	var seen: Dictionary[int, bool] = {from_id: true}
	var queue: Array[int] = [from_id]
	var head := 0
	while head < queue.size():
		var current := queue[head]
		head += 1
		if predicate.call(get_room(current)):
			return current
		for next: int in neighbors(current):
			if not seen.has(next):
				seen[next] = true
				queue.append(next)
	return NO_ROOM


func nearest_treasure(from_id: int) -> int:
	return nearest_room(from_id, func(r: DungeonRoom) -> bool: return r.def.is_treasure)


# --- Internals --------------------------------------------------------------

func _create_room(def: RoomDef, coord: Vector2i, parent_id: int) -> DungeonRoom:
	var room := DungeonRoom.new(_next_id, def, coord, parent_id)
	_next_id += 1
	rooms[room.id] = room
	_by_coord[coord] = room.id
	return room


func _rebuild_path(came_from: Dictionary[int, int], to_id: int) -> Array[int]:
	var out: Array[int] = []
	var current := to_id
	while current != NO_ROOM:
		out.append(current)
		current = came_from[current]
	out.reverse()
	return out


func _id_set(ids: Array[int]) -> Dictionary[int, bool]:
	var out: Dictionary[int, bool] = {}
	for id: int in ids:
		out[id] = true
	return out
