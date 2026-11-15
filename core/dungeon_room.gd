class_name DungeonRoom
extends RefCounted
## One built room in the dungeon. This is runtime state; the type is in `def`.

var id: int
var def: RoomDef
var coord: Vector2i
## Room this one was built from. Dungeon.NO_ROOM for the Entrance.
var parent_id: int
var child_ids: Array[int] = []
var level: int = 1


func _init(p_id: int, p_def: RoomDef, p_coord: Vector2i, p_parent_id: int) -> void:
	id = p_id
	def = p_def
	coord = p_coord
	parent_id = p_parent_id


func dps() -> float:
	return def.dps * level


## Hazards in the room: one per level, up to what HazardLayout fits. 0 if the room has none.
func hazard_count() -> int:
	if def.hazard_damage <= 0.0:
		return 0
	return mini(level, HazardLayout.capacity())


## Total damage an adventurer takes from hazards in one full crossing.
func hazard_damage_per_crossing() -> float:
	return def.hazard_damage * hazard_count()
