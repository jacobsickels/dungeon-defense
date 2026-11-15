class_name HazardLayout
extends RefCounted
## Where a room's hazards (spikes, ...) stand, in room-local units (the room is 12×12, centered).
## Shared by the simulation, which hits adventurers as they pass each hazard, and the view,
## which draws them, so the two always agree.
##
## Hazard i is the i-th spot of an 11×11 grid, nearest the center first and stretched so spots
## along the walking path (the X axis) come before spots to the side. Each spot has a small
## fixed jitter so the rows don't look machine-placed.

const SPACING: float = 1.0
## Spots run -EXTENT..EXTENT on each axis.
const EXTENT: int = 5
## > 1 fills along the path (X) before spreading sideways (Z).
const PATH_BIAS: float = 2.5
## Random offset per spot, as a fraction of SPACING.
const JITTER: float = 0.15
## Rooms are crossed from x = -HALF_ROOM to x = +HALF_ROOM.
const HALF_ROOM: float = 6.0

static var _spots: Array[Vector2] = []


## Number of spots. Hazards beyond this don't fit and are ignored.
static func capacity() -> int:
	return spots().size()


## All spots in fill order, as (x, z).
static func spots() -> Array[Vector2]:
	if _spots.is_empty():
		_spots = _make_spots()
	return _spots


## How far through the room (0..1) an adventurer is when they pass the hazard at this spot.
static func pass_progress(spot: Vector2) -> float:
	return clampf((spot.x + HALF_ROOM) / (2.0 * HALF_ROOM), 0.0, 1.0)


static func _make_spots() -> Array[Vector2]:
	var cells: Array[Vector2i] = []
	for x: int in range(-EXTENT, EXTENT + 1):
		for z: int in range(-EXTENT, EXTENT + 1):
			cells.append(Vector2i(x, z))
	# Ties break by angle so the order is the same every run.
	cells.sort_custom(func(a: Vector2i, b: Vector2i) -> bool:
		var da := Vector2(a.x, a.y * PATH_BIAS).length()
		var db := Vector2(b.x, b.y * PATH_BIAS).length()
		if not is_equal_approx(da, db):
			return da < db
		return Vector2(a).angle() < Vector2(b).angle())
	var rng := RandomNumberGenerator.new()
	var out: Array[Vector2] = []
	for cell: Vector2i in cells:
		rng.seed = hash(cell)
		var jitter := Vector2(rng.randf_range(-JITTER, JITTER), rng.randf_range(-JITTER, JITTER))
		out.append((Vector2(cell) + jitter) * SPACING)
	return out
