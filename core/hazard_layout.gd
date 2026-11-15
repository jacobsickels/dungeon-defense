class_name HazardLayout
extends Resource
## Where a room's hazards (spikes, skeletons, chests, ...) stand, in room-local units (the room
## is 12×12, centered). Shared by the simulation, which hits adventurers as they pass each
## hazard, and the view, which draws them, so the two always agree. A RoomDef points at one.
## Rooms without one use `HazardLayout.default_layout()`.
##
## Hazard i is the i-th spot of a grid, nearest the center first and stretched so spots along
## the walking path (the X axis) come before spots to the side. Each spot has a small fixed
## jitter so rows don't look machine-placed.

## Rooms are crossed from x = -HALF_ROOM to x = +HALF_ROOM.
const HALF_ROOM: float = 6.0

@export var spacing: float = 1.0
## Spots run -extent..extent cells on each axis (x along the path, y across it).
@export var extent: Vector2i = Vector2i(5, 5)
## > 1 fills along the path (X) before spreading sideways (Z).
@export var path_bias: float = 2.5
## Random offset per spot, as a fraction of spacing.
@export_range(0.0, 0.45) var jitter: float = 0.15
## Leaves the walkway (the z = 0 row) clear, for things adventurers walk past rather than over.
@export var keep_path_clear: bool = false

static var _default: HazardLayout

var _spots: Array[Vector2] = []
## Per hazard count: progress points where hazards are passed (sorted) and which hazard each is.
var _pass_cache: Dictionary[int, Array] = {}


## The layout spikes use: an 11×11 grid, 1 unit apart.
static func default_layout() -> HazardLayout:
	if _default == null:
		_default = HazardLayout.new()
	return _default


## Number of spots.
func capacity() -> int:
	return spots().size()


## All spots in fill order, as (x, z).
func spots() -> Array[Vector2]:
	if _spots.is_empty():
		_spots = _make_spots()
	return _spots


## How far through the room (0..1) an adventurer is when they pass a spot.
static func pass_progress(spot: Vector2) -> float:
	return clampf((spot.x + HALF_ROOM) / (2.0 * HALF_ROOM), 0.0, 1.0)


## Indices of the first `count` hazards an adventurer passes between two points of progress
## through the room (from, to].
func hazards_passed(count: int, from: float, to: float) -> PackedInt32Array:
	var cached: Array = _pass_points(count)
	var points: PackedFloat64Array = cached[0]
	var indices: PackedInt32Array = cached[1]
	var start := points.bsearch(from, false)
	var end := points.bsearch(to, false)
	return indices.slice(start, end)


func _pass_points(count: int) -> Array:
	if not _pass_cache.has(count):
		var all := spots()
		var order: Array[int] = []
		for i: int in mini(count, all.size()):
			order.append(i)
		order.sort_custom(func(a: int, b: int) -> bool:
			return pass_progress(all[a]) < pass_progress(all[b]))
		var points := PackedFloat64Array()
		var indices := PackedInt32Array()
		for i: int in order:
			points.append(pass_progress(all[i]))
			indices.append(i)
		_pass_cache[count] = [points, indices]
	return _pass_cache[count]


func _make_spots() -> Array[Vector2]:
	var cells: Array[Vector2i] = []
	for x: int in range(-extent.x, extent.x + 1):
		for z: int in range(-extent.y, extent.y + 1):
			if keep_path_clear and z == 0:
				continue
			cells.append(Vector2i(x, z))
	var bias := path_bias
	# Ties break by angle so the order is the same every run.
	cells.sort_custom(func(a: Vector2i, b: Vector2i) -> bool:
		var da := Vector2(a.x, a.y * bias).length()
		var db := Vector2(b.x, b.y * bias).length()
		if not is_equal_approx(da, db):
			return da < db
		return Vector2(a).angle() < Vector2(b).angle())
	var rng := RandomNumberGenerator.new()
	var out: Array[Vector2] = []
	for cell: Vector2i in cells:
		rng.seed = hash(cell)
		var offset := Vector2(rng.randf_range(-jitter, jitter), rng.randf_range(-jitter, jitter))
		out.append((Vector2(cell) + offset) * spacing)
	return out
