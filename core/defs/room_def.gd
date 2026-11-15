class_name RoomDef
extends Resource
## Static definition of a room type. Saved as .tres files in res://data/rooms/.
##
## A room hurts adventurers in any mix of these ways, all scaling with its level:
## - hazards (`hazard_damage`): one hazard per level, each hitting once as an adventurer passes it
## - damage over time (`dps`): the whole time an adventurer is inside
## - poison (`poison_damage`): picked up on entering, then dealt over POISON_DURATION wherever they go
## - pulses (`pulse_damage`): every `pulse_interval` seconds, hits everyone inside at once
## A room can also boost the whole dungeon (`global_blood_bonus`, `global_hit_damage`). Nothing
## depends on where a room sits in the line.

@export var id: StringName
@export var display_name: String
@export_multiline var description: String

@export_group("Economy")
## Cost to build the room (level 1).
@export var base_cost: float = 10.0
## Each level owned multiplies the next level's cost by this.
@export var cost_growth: float = 1.15
## Whether the player can buy this room. Entrance and Treasure are placed by the game.
@export var buildable: bool = true
## Where the room sits in the line: rooms are ordered from the Entrance by this, lowest first.
## The Treasure Pit is always last.
@export var line_order: int = 0

@export_group("Damage")
## Seconds an adventurer at speed 1.0 takes to cross the room.
@export var traverse_time: float = 2.0
## Damage per second to each adventurer inside, per level.
@export var dps: float = 0.0
## Damage per hit from each hazard. One hazard per level, placed by `hazard_layout`. Once the
## layout is full, more levels make each hit stronger instead (total damage stays level × this).
@export var hazard_damage: float = 0.0
## Where hazards stand. Empty means HazardLayout.default_layout() (spike spacing).
@export var hazard_layout: HazardLayout
## Poison picked up on entering, per level. Dealt over Balance.POISON_DURATION seconds wherever
## the adventurer is. If they fall into the pit first, the rest lands at once.
@export var poison_damage: float = 0.0
## Damage to everyone inside each pulse, per level.
@export var pulse_damage: float = 0.0
## Seconds between pulses.
@export var pulse_interval: float = 3.0

@export_group("Global")
## All blood everywhere is multiplied by 1 + this × level (summed over rooms).
@export var global_blood_bonus: float = 0.0
## Every hit anywhere (hazards, pulses, clicks) deals this much extra damage per level.
@export var global_hit_damage: float = 0.0

@export_group("Role")
@export var is_entrance: bool = false
@export var is_treasure: bool = false

@export_group("Presentation")
## Placeholder color, used where there's no art yet.
@export var color: Color = Color.GRAY
## Floor and props for this room, centered on the room (12×12 units). The walls are
## added by the view. If empty, the room gets a plain floor.
@export var interior: PackedScene


func layout() -> HazardLayout:
	return hazard_layout if hazard_layout != null else HazardLayout.default_layout()
