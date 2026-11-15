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
## Seconds since this room's last pulse (rooms with pulse_damage).
var pulse_timer: float = 0.0


func _init(p_id: int, p_def: RoomDef, p_coord: Vector2i, p_parent_id: int) -> void:
	id = p_id
	def = p_def
	coord = p_coord
	parent_id = p_parent_id


func dps() -> float:
	return def.dps * level


## Hazards standing in the room: one per level, up to what the layout fits. 0 if it has none.
func hazard_count() -> int:
	if def.hazard_damage <= 0.0:
		return 0
	return mini(level, def.layout().capacity())


## Damage of one hazard hit. Past the layout's capacity, hits get stronger so that every level
## still adds hazard_damage per crossing.
func hazard_hit_damage() -> float:
	var count := hazard_count()
	if count == 0:
		return 0.0
	return def.hazard_damage * level / count


## Total damage an adventurer takes from hazards in one full crossing.
func hazard_damage_per_crossing() -> float:
	return def.hazard_damage * level if hazard_count() > 0 else 0.0


func poison_damage() -> float:
	return def.poison_damage * level


func pulse_damage() -> float:
	return def.pulse_damage * level
