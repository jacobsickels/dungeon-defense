class_name Adventurer
extends RefCounted
## Runtime state for one adventurer in the dungeon.
##
## Adventurers move room to room. `progress` runs from 0 to 1 while they cross
## `room_id`, entering from the `prev_room_id` side and leaving toward `next_room_id`.
## Dungeon.NO_ROOM for either of those means the outside world. They can't die: they
## bleed blood for every point of damage, then drop through the Treasure room's trapdoor.
##
## Stats are the def's, times the lure multipliers when they arrived.

var id: int
var def: AdventurerDef
## Multiplier on how fast they cross rooms.
var speed: float
## Blood the dungeon gets per point of damage dealt to them.
var bleed: float
## Total blood taken from them so far.
var blood_drained: float = 0.0
var room_id: int = Dungeon.NO_ROOM
var prev_room_id: int = Dungeon.NO_ROOM
var next_room_id: int = Dungeon.NO_ROOM
var progress: float = 0.0


func _init(p_id: int, p_def: AdventurerDef, speed_mult: float = 1.0, blood_mult: float = 1.0) -> void:
	id = p_id
	def = p_def
	speed = def.speed * speed_mult
	bleed = def.bleed * blood_mult
